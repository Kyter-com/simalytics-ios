import Foundation

enum StorageFailure: String, Error, Identifiable, Sendable {
  case insufficientSpace
  case unavailable

  var id: Self { self }

  var message: String {
    switch self {
    case .insufficientSpace:
      "Your device doesn't have enough space to save your library. Free some space, then try again."
    case .unavailable:
      "Your saved library couldn't be accessed. Try again, or restart the app if the problem continues."
    }
  }

  /// Core Data often wraps SQLite/POSIX failures. Inspect bounded underlying
  /// errors and numeric codes without retaining private file paths or messages.
  static func classify(_ error: Error) -> Self? {
    if let failure = error as? Self { return failure }
    var pending = [error as NSError]
    var seen = Set<ObjectIdentifier>()
    var result: Self?
    while let current = pending.popLast(), seen.count < 32 {
      guard seen.insert(ObjectIdentifier(current)).inserted else { continue }
      if (current.domain == NSCocoaErrorDomain && current.code == NSFileWriteOutOfSpaceError)
        || (current.domain == NSPOSIXErrorDomain && current.code == Int(ENOSPC))
      {
        return .insufficientSpace
      }
      let sqlite =
        current.domain == "NSSQLiteErrorDomain"
        ? current.code : (current.userInfo["NSSQLiteErrorDomain"] as? NSNumber)?.intValue
      if let sqlite {
        switch sqlite & 0xff {
        case 13: return .insufficientSpace
        case 10, 11, 14, 26: result = .unavailable
        default: break
        }
      }
      if let underlying = current.userInfo[NSUnderlyingErrorKey] as? NSError {
        pending.append(underlying)
      }
      for key in ["NSDetailedErrors", "NSMultipleUnderlyingErrors"] {
        pending += current.userInfo[key] as? [NSError] ?? []
      }
    }
    return result
  }
}
