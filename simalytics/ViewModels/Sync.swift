//
//  FetchLatestActivities.swift
//  simalytics
//
//  Created by Nick Reisenauer on 4/4/25.
//

import Foundation
import Sentry
import SwiftData

func fetchAndStoreLatestActivities(_ accessToken: String) async {
  do {
    let urlComponents = URLComponents(string: "https://api.simkl.com/sync/activities")!

    var request = URLRequest(url: urlComponents.url!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.data(for: request)
    let result = try JSONDecoder().decode(LastActivitiesModel.self, from: data)

    let context = try ModelContext(.init(for: SDLastActivities.self))
    let existing = try context.fetch(FetchDescriptor<SDLastActivities>())
    try context.delete(model: SDLastActivities.self)
    context.insert(SDLastActivities(all: result.all))
    try context.save()
  } catch {
    SentrySDK.capture(error: error)
  }
}
