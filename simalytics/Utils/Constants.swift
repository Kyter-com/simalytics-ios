//
//  Constants.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/13/25.
//

import Foundation

let SIMKL_CDN_URL = "https://wsrv.nl/?url=https://simkl.in"
let SIMKL_APP_NAME = "simalytics-ios"

var SIMKL_APP_VERSION: String {
  Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
}

var SIMKL_USER_AGENT: String {
  "\(SIMKL_APP_NAME)/\(SIMKL_APP_VERSION)"
}
