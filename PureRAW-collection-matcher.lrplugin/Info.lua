-- Copyright 2022 ns130291.
-- SPDX-License-Identifier: LGPL-3.0-or-later

return {

	LrSdkVersion = 12.0,
	LrSdkMinimumVersion = 6.0,
	LrToolkitIdentifier = 'de.nsvb.purerawcollectionmatcher',

	LrPluginName = "PureRAW collection matcher",
	LrPluginInfoUrl = "https://github.com/ns130291/Lightroom-PureRAW-collection-matcher",

	LrLibraryMenuItems = {
		title = '&Match PureRAW export',
		file = 'MatchPureRAWexport.lua',
		enabledWhen = 'photosAvailable',
	},

	VERSION = { major=1, minor=1, revision=0 },

}
