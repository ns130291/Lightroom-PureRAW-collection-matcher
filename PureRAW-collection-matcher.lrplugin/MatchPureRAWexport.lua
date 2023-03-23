-- Copyright 2022 ns130291.
-- SPDX-License-Identifier: LGPL-3.0-or-later

local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrLogger = import 'LrLogger'
local LrProgressScope = import 'LrProgressScope'

local logger = LrLogger('PureRAW_collection_matcher')
logger:enable("logfile")
-- logger:enable("print")
local log = logger:quickf('info')

function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

function size(table)
	local count = 0
	for _ in pairs(table) do count = count + 1 end
	return count
end

local metadataKeys = {
	"rating",
	"label",
	"title",
	"caption",
	"copyName",
	"creator",
	"creatorJobTitle",
	"creatorAddress",
	"creatorCity",
	"creatorStateProvince",
	"creatorPostalCode",
	"creatorCountry",
	"creatorPhone",
	"creatorEmail",
	"creatorUrl",
	"headline",
	"iptcSubjectCode",
	"descriptionWriter",
	"iptcCategory",
	"iptcOtherCategories",
	"dateCreated",
	"intellectualGenre",
	"scene",
	"location",
	"city",
	"stateProvince",
	"country",
	"isoCountryCode",
	"jobIdentifier",
	"instructions",
	"provider",
	"source",
	"copyright",
	"copyrightState",
	"rightsUsageTerms",
	"copyrightInfoUrl",
	"colorNameForLabel",
	"personShown",
	"locationCreated",
	"locationShown",
	"nameOfOrgShown",
	"codeOfOrgShown",
	"event",
	"artworksShown",
	"additionalModelInfo",
	"modelAge",
	"minorModelAge",
	"modelReleaseStatus",
	"modelReleaseID",
	"imageSupplier",
	"imageSupplierImageId",
	"registryId",
	"maxAvailWidth",
	"maxAvailHeight",
	"sourceType",
	"imageCreator",
	"copyrightOwner",
	"licensor",
	"propertyReleaseID",
	"propertyReleaseStatus",
	"gps",
	"gpsAltitude",
	"pickStatus",
	"gpsImgDirection"
}

local developSettings = {
	"Sharpness",
	"SharpenRadius",
	"SharpenEdgeMasking",
	"SharpenDetail",
	"LuminanceNoiseReductionContrast",
	"LuminanceNoiseReductionDetail",
	"LuminanceSmoothing",
	"ColorNoiseReductionDetail",
	"ColorNoiseReductionSmoothness",
	"ColorNoiseReduction",

	"AutoLateralCA",
	"LensProfileEnable",
	"LensProfileSetup",
	"LensProfileFilename",
	"LensProfileName",
	"LensProfileIsEmbedded",
	"LensProfileDigest",
	"LensProfileVignettingScale",
	"LensProfileDistortionScale",
	"LensManualDistortionAmount",
	"CropConstrainToWarp",
	"DefringeGreenAmount",
	"Defringe",
	"DefringeGreenHueHi",
	"DefringeGreenHueLo",
	"DefringePurpleAmount",
	"DefringePurpleHueHi",
	"DefringePurpleHueLo",
	"VignetteMidpoint",
	"VignetteAmount",
}

PureRawMatcher = {}

function PureRawMatcher.allowedMetadataKey(key)
	for _, k in ipairs(metadataKeys) do
		if k == key then
			return true
		end
	end
	return false
end

function PureRawMatcher.removeDevelopSettings(settings)
	for _, k in ipairs(developSettings) do
		settings[k] = nil
	end
	-- settings["EnableLensCorrections"] = false
end

function PureRawMatcher.sortImages()
	local catalog = LrApplication.activeCatalog()

	local sources = catalog:getActiveSources()
	local count = 0
	for _ in pairs(sources) do count = count + 1 end

	if count == 1 then
		local activeSource = sources[1]
		if (type(activeSource) ~= "table") or (activeSource:type() ~= "LrCollection") then
			LrDialogs.message( "PureRAW collection match failed", "Only collections are supported", "warning" )
			return
		end
		if activeSource:isSmartCollection() then
			LrDialogs.message( "PureRAW collection match failed", "Smart collections are not supported", "warning" )
			return
		end
	else
		LrDialogs.message( "PureRAW collection match failed", "Select only one collection", "warning" )
		return
	end

	local sourceCollection = sources[1]
	local collectionSet = nil
	catalog:withWriteAccessDo("Create collection set", function()
		collectionSet = catalog:createCollectionSet("PureRAW matched", nil, true)
	end)

	local collection = nil
	catalog:withWriteAccessDo("Create new collection", function()
		collection = catalog:createCollection(sourceCollection:getName(), collectionSet, true)
	end)

	local progressScope = LrProgressScope({title = "Matching PureRAW photos"})
	progressScope:setCancelable(true)

	catalog:withWriteAccessDo("Match PureRAW", function()
		local photos = sourceCollection:getPhotos()
		for i, photo in ipairs( photos ) do
			if progressScope:isCanceled() then
				break
			end

			local skippedMetadata = "";

			local sourceFile = photo:getRawMetadata("path")
			local path = LrPathUtils.parent(sourceFile)
			local targetFile = LrPathUtils.child(LrPathUtils.child(path, "DxO"), LrPathUtils.removeExtension(LrPathUtils.leafName(sourceFile)) .. "-" .. LrPathUtils.extension(sourceFile) .. "_DxO_DeepPRIME.dng")
			log("target file: %q", targetFile)

			if LrFileUtils.exists(targetFile) then
				local newPhoto = catalog:findPhotoByPath(targetFile, false)
				if not newPhoto then
					newPhoto = catalog:addPhoto(targetFile)
				end

				-- copy metadata
				-- log("metadata: %q", dump(photo:getRawMetadata()))
				for metaKey, metaValue in pairs(photo:getRawMetadata()) do
					-- workaround for grey value returned, see also here: https://community.adobe.com/t5/lightroom-classic-discussions/getrawmetadata-colornameforlabel-returns-grey/td-p/6732085
					if metaKey == "colorNameForLabel" and metaValue == "grey" then
						newPhoto:setRawMetadata(metaKey, "")
					elseif metaKey == "keywords" then
						for _, keyword in ipairs(catalog:getKeywordsByLocalId(metaValue)) do
							newPhoto:addKeyword(keyword)
						end
					elseif PureRawMatcher.allowedMetadataKey(metaKey) then
						newPhoto:setRawMetadata(metaKey, metaValue)
					else
						skippedMetadata = skippedMetadata .. " " .. metaKey
					end
				end
				-- log("metadata not allowed: %q", skippedMetadata)

				-- copy develop settings
				local developSettings = photo:getDevelopSettings()
				-- log("developSettings: %q", dump(developSettings))
				-- log("developSettings: %q", size(developSettings))
				PureRawMatcher.removeDevelopSettings(developSettings)
				-- log("developSettings: %q", dump(developSettings))
				-- log("developSettings: %q", size(developSettings))
				newPhoto:applyDevelopSettings(developSettings, "PureRAW matching")

				collection:addPhotos({newPhoto})
			else
				-- add current photo to collection
				collection:addPhotos({photo})
			end

			progressScope:setPortionComplete(i, #photos)
		end
	end)

	progressScope:done()
	LrDialogs.message( "PureRAW collection matcher", "Matching finished", "info" )
end

import 'LrTasks'.startAsyncTask(PureRawMatcher.sortImages)
