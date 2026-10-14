enum RatingMediaType: CaseIterable, Sendable {
  case movie, show, anime

  // Anime is accepted under shows on both the add and remove endpoints.
  var payloadKey: String { self == .movie ? "movies" : "shows" }
}
