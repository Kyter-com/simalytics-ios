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
    try context.delete(model: SDLastActivities.self)
    context.insert(
      SDLastActivities(
        all: result.all,
        settings_all: result.settings?.all,
        tv_shows_all: result.tv_shows?.all,
        tv_shows_rated_at: result.tv_shows?.rated_at,
        tv_shows_plantowatch: result.tv_shows?.plantowatch,
        tv_shows_watching: result.tv_shows?.watching,
        tv_shows_completed: result.tv_shows?.completed,
        tv_shows_hold: result.tv_shows?.hold,
        tv_shows_dropped: result.tv_shows?.dropped,
        tv_shows_removed_from_list: result.tv_shows?.removed_from_list
      )
    )
    try context.save()
  } catch {
    SentrySDK.capture(error: error)
  }
}
