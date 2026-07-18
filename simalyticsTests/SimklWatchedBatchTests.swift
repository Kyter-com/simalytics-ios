import Foundation
import Testing

@testable import Simalytics

@Suite(
  "Simkl watched response decoding",
  .bug("https://kyter.sentry.io/issues/7599289548/", "Malformed watched response")
)
struct SimklWatchedBatchTests {
  @Test("Show item uses its top-level Simkl ID")
  func showUsesTopLevelID() throws {
    let response = try decode(
      ShowWatchlistModel.self,
      json: """
        [{"simkl":42,"ids":{"simkl":99},"result":true,"list":"watching","episodes_watched":3,"seasons":[]}]
        """
    )

    let item = try #require(response.items.first)
    #expect(item.simkl == 42)
    #expect(item.list == "watching")
    #expect(item.episodes_watched == 3)
    #expect(response.malformedItemCount == 0)
  }

  @Test("Show item falls back to nested Simkl ID")
  func showUsesNestedID() throws {
    let response = try decode(
      ShowWatchlistModel.self,
      json: """
        [{"ids":{"simkl":77},"result":true,"type":"show","list":"completed","seasons":[]}]
        """
    )

    #expect(response.items.map(\.simkl) == [77])
    #expect(response.items.first?.list == "completed")
    #expect(response.terminalRejectionCount == 0)
  }

  @Test("Terminal not-found item is represented but not decoded as watched data")
  func notFoundIsTerminalRejection() throws {
    let response = try decode(
      ShowWatchlistModel.self,
      json: """
        [{"ids":{"simkl":77},"result":"not_found","type":"show"}]
        """
    )

    #expect(response.items.isEmpty)
    #expect(response.terminalRejectionCount == 1)
    #expect(response.malformedItemCount == 0)
  }

  @Test("Malformed sibling cannot discard valid data")
  func mixedArrayPreservesValidSibling() throws {
    let response = try decode(
      ShowWatchlistModel.self,
      json: """
        [
          {"simkl":11,"result":true,"list":"watching","seasons":[]},
          {"result":true,"type":"show","list":"watching"},
          {"ids":{"simkl":12},"result":"not_found","type":"show"}
        ]
        """
    )

    #expect(response.items.map(\.simkl) == [11])
    #expect(response.malformedItemCount == 1)
    #expect(response.terminalRejectionCount == 1)
  }

  @Test("Normal anime response still decodes")
  func animeResponseDecodesNormally() throws {
    let response = try decode(
      AnimeWatchlistModel.self,
      json: """
        [{"simkl":101,"result":true,"list":"watching","episodes_watched":8,"episodes_aired":12,"seasons":[]}]
        """
    )

    let item = try #require(response.items.first)
    #expect(item.simkl == 101)
    #expect(item.episodes_watched == 8)
    #expect(item.episodes_aired == 12)
    #expect(item.seasons?.isEmpty == true)
  }

  private func decode<T: Decodable & Sendable>(
    _ type: T.Type,
    json: String
  ) throws -> SimklWatchedDecodedResponse<T> {
    try decodeSimklWatchedResponse(type, from: Data(json.utf8))
  }
}
