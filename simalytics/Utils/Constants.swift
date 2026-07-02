//
//  Constants.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/13/25.
//

import Foundation

let SIMKL_CDN_URL = "https://wsrv.nl/?url=https://simkl.in"
let SIMKL_CLIENT_ID = "c387a1e6b5cf2151af039a466c49a6b77891a4134aed1bcb1630dd6b8f0939c9"
let SIMKL_APP_NAME = "simalytics-ios"

var SIMKL_APP_VERSION: String {
  Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
}

var SIMKL_USER_AGENT: String {
  "\(SIMKL_APP_NAME)/\(SIMKL_APP_VERSION)"
}
