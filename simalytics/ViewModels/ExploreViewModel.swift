//
//  ExploreViewModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/13/25.
//

import Foundation
import Sentry

func getTrendingMovies() async -> [TrendingMovieModel] {
  do {
    var urlComponents = URLComponents(string: "https://api.simkl.com/movies/trending/today")!
    urlComponents.queryItems = [
      URLQueryItem(name: "extended", value: "overview,theater,metadata,tmdb,genres"),
      URLQueryItem(name: "client_id", value: SIMKL_CLIENT_ID),
    ]
    print(urlComponents.url!)

    var request = URLRequest(url: urlComponents.url!)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let (data, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
      return []
    }

    return try JSONDecoder().decode([TrendingMovieModel].self, from: data)
  } catch {
    SentrySDK.capture(error: error)
    return []
  }
}

func getTrendingAnimes() async -> [TrendingAnimeModel] {
  do {
    var urlComponents = URLComponents(string: "https://api.simkl.com/anime/trending/today")!
    urlComponents.queryItems = [
      URLQueryItem(name: "extended", value: "overview,metadata,tmdb,genres"),
      URLQueryItem(name: "client_id", value: SIMKL_CLIENT_ID),
    ]
    print(urlComponents.url!)

    var request = URLRequest(url: urlComponents.url!)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let (data, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
      return []
    }

    return try JSONDecoder().decode([TrendingAnimeModel].self, from: data)
  } catch {
    SentrySDK.capture(error: error)
    return []
  }
}

func getTrendingShows() async -> [TrendingShowModel] {
  do {
    var urlComponents = URLComponents(string: "https://api.simkl.com/tv/trending/today")!
    urlComponents.queryItems = [
      URLQueryItem(name: "extended", value: "overview,metadata,tmdb,genres"),
      URLQueryItem(name: "client_id", value: SIMKL_CLIENT_ID),
    ]
    print(urlComponents.url!)

    var request = URLRequest(url: urlComponents.url!)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let (data, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
      return []
    }

    return try JSONDecoder().decode([TrendingShowModel].self, from: data)
  } catch {
    SentrySDK.capture(error: error)
    return []
  }
}
