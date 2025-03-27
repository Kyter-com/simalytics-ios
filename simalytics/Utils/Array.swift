//
//  Array.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/27/25.
//

import Foundation

extension Array where Element: Hashable {
  func unique() -> [Element] {
    Array(Set(self))
  }
}
