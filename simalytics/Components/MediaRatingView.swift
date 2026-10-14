import SwiftData
import SwiftUI

struct MediaRatingView: View {
  let simklID: Int
  let type: RatingMediaType
  @Binding var rating: Double  // Always stored on Simkl's 10-point scale.
  @AppStorage("useFiveStarRating") private var useFiveStarRating = false
  @Environment(Auth.self) private var auth
  @Environment(\.modelContext) private var modelContext
  @State private var isSaving = false
  @State private var showError = false
  @State private var errorMessage = ""

  var body: some View {
    VStack(spacing: 4) {
      Text(
        rating > 0
          ? "Your rating: \((useFiveStarRating ? rating / 2 : rating).formatted()) out of \(useFiveStarRating ? 5 : 10)"
          : "Rate this title"
      )
      .font(.subheadline)
      .foregroundStyle(.secondary)
      RatingView(
        maxRating: useFiveStarRating ? 5 : 10,
        rating: useFiveStarRating ? rating / 2 : rating,
        starRounding: useFiveStarRating ? .roundToHalfStar : .roundToFullStar,
        size: useFiveStarRating ? 28 : 20
      ) { selected in
        saveRating(Int((useFiveStarRating ? selected * 2 : selected).rounded()))
      }
      .disabled(isSaving || auth.simklAccessToken.isEmpty)

      if isSaving {
        ProgressView("Saving rating…")
          .frame(minHeight: 44)
      } else if rating > 0 {
        Button(role: .destructive) {
          saveRating(0)
        } label: {
          Text("Remove Rating")
            .font(.footnote)
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .disabled(auth.simklAccessToken.isEmpty)
      }
    }
    .padding(.horizontal)
    .padding(.top, 8)
    .alert("Couldn't Update Rating", isPresented: $showError) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(errorMessage)
    }
  }

  private func saveRating(_ newRating: Int) {
    guard !isSaving, !auth.simklAccessToken.isEmpty else { return }
    let previous = rating
    let token = auth.simklAccessToken
    isSaving = true
    rating = Double(newRating)
    Task {
      defer { isSaving = false }
      let result: SimklMutationResult
      #if DEBUG
        if ScreenshotMode.isActive {
          result = .succeeded
        } else {
          result = await setSimklRating(
            simklID: simklID, type: type, rating: newRating, accessToken: token)
        }
      #else
        result = await setSimklRating(
          simklID: simklID, type: type, rating: newRating, accessToken: token)
      #endif
      // A response for a signed-out account must not repopulate its local data.
      guard auth.simklAccessToken == token else { return }
      switch result {
      case .succeeded:
        do {
          try storeConfirmedRating(newRating, simklID: simklID, type: type, context: modelContext)
        } catch {
          reportError(error)
        }
        await syncLatestActivities(token, modelContainer: modelContext.container)
      case .cancelled:
        rating = previous
      case .failed(let message):
        rating = previous
        errorMessage = message
        showError = true
      }
    }
  }
}
