import Foundation

/// SIMKL timestamps arrive with and without fractional seconds. Formatters are
/// expensive to create, so Up Next rows and episode lists share these instead
/// of building new ones for every row on every render.
enum SimklDateParser {
  nonisolated(unsafe) private static let standard = ISO8601DateFormatter()
  nonisolated(unsafe) private static let fractional: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions.insert(.withFractionalSeconds)
    return formatter
  }()

  static func date(from string: String) -> Date? {
    standard.date(from: string) ?? fractional.date(from: string)
  }
}
