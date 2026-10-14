import Kingfisher
import Photos
import SwiftUI

struct FullscreenPosterView: View {
  let posterPath: String
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dismiss) private var dismiss
  @State private var image: UIImage?
  @State private var isLoading = true
  @State private var isSaving = false
  @State private var loadAttempt = 0
  @State private var showingSaveAlert = false
  @State private var saveAlertMessage = ""
  @State private var scale: CGFloat = 1
  @State private var offset: CGSize = .zero
  @GestureState private var magnification: CGFloat = 1
  @GestureState private var translation: CGSize = .zero

  private var imageURL: URL? {
    URL(string: "\(SIMKL_CDN_URL)/posters/\(posterPath)_m.jpg")
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        Color.black.ignoresSafeArea()
        if isLoading {
          ProgressView("Loading poster…")
            .tint(.white)
        } else if let image {
          let displayedScale = PosterViewport.boundedScale(scale * magnification)
          let displayedOffset = PosterViewport.clampedOffset(
            CGSize(
              width: offset.width + translation.width, height: offset.height + translation.height),
            scale: displayedScale, imageSize: image.size, viewport: geometry.size)
          Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: geometry.size.width, height: geometry.size.height)
            .scaleEffect(displayedScale)
            .offset(displayedOffset)
            .contentShape(.rect)
            .gesture(
              MagnifyGesture()
                .updating($magnification) { value, state, _ in state = value.magnification }
                .onEnded { value in
                  scale = PosterViewport.boundedScale(scale * value.magnification)
                  offset = PosterViewport.clampedOffset(
                    offset, scale: scale, imageSize: image.size, viewport: geometry.size)
                }
            )
            .simultaneousGesture(
              DragGesture()
                .updating($translation) { value, state, _ in state = value.translation }
                .onEnded { value in
                  offset = PosterViewport.clampedOffset(
                    CGSize(
                      width: offset.width + value.translation.width,
                      height: offset.height + value.translation.height),
                    scale: scale, imageSize: image.size, viewport: geometry.size)
                }
            )
            .onTapGesture(count: 2) { toggleZoom() }
            .accessibilityLabel("Poster")
            .accessibilityAction(named: scale > 1 ? "Reset zoom" : "Zoom in") { toggleZoom() }
            .onChange(of: geometry.size) { _, newSize in
              offset = PosterViewport.clampedOffset(
                offset, scale: scale, imageSize: image.size, viewport: newSize)
            }
        } else {
          ContentUnavailableView {
            Label("Couldn't Load Poster", systemImage: "photo.badge.exclamationmark")
          } description: {
            Text("Check your connection and try again.")
          } actions: {
            Button("Try Again") { loadAttempt += 1 }
              .buttonStyle(.bordered)
          }
        }
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
      .clipped()
    }
    .overlay(alignment: .topTrailing) {
      HStack(spacing: 16) {
        if image != nil {
          Button {
            saveImageToPhotos()
          } label: {
            controlLabel(
              isSaving ? "Saving poster" : "Save poster", symbol: "square.and.arrow.down")
          }
          .disabled(isSaving)
          .overlay { if isSaving { ProgressView().tint(.white) } }
        }
        Button {
          dismiss()
        } label: {
          controlLabel("Close poster", symbol: "xmark")
        }
      }
      .padding()
    }
    .preferredColorScheme(.dark)
    .task(id: loadAttempt) { await loadImage() }
    .alert("Save Image", isPresented: $showingSaveAlert) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(saveAlertMessage)
    }
    .statusBarHidden()
  }

  @ViewBuilder
  private func controlLabel(_ title: String, symbol: String) -> some View {
    let label = Label(title, systemImage: symbol)
      .labelStyle(.iconOnly)
      .font(.title2)
      .foregroundStyle(.white)
      .frame(width: 48, height: 48)
    if #available(iOS 26, *) {
      label.glassEffect(.regular.interactive(), in: .circle)
    } else {
      label.background(.black.opacity(0.5), in: .circle)
    }
  }

  private func loadImage() async {
    isLoading = true
    guard let url = imageURL else { isLoading = false; return }
    do {
      let result = try await KingfisherManager.shared.retrieveImage(with: url)
      try Task.checkCancellation()
      image = result.image
    } catch {
      guard !Task.isCancelled else { return }
      image = nil
    }
    isLoading = false
  }

  private func toggleZoom() {
    let update = {
      scale = scale > 1 ? 1 : 2
      offset = .zero
    }
    if reduceMotion { update() } else { withAnimation(.snappy, update) }
  }

  private func saveImageToPhotos() {
    guard let image, !isSaving else { return }
    isSaving = true
    Task {
      defer { isSaving = false }
      let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
      switch status {
      case .authorized, .limited:
        do {
          // Photos invokes this block on its transaction queue. Explicit
          // Sendable prevents inheriting this view's MainActor isolation.
          try await PHPhotoLibrary.shared().performChanges { @Sendable in
            PHAssetChangeRequest.creationRequestForAsset(from: image)
          }
          saveAlertMessage = "Image saved to Photos"
        } catch {
          saveAlertMessage = "Couldn't save this image to Photos. Please try again."
        }
      case .denied, .restricted:
        saveAlertMessage = "Please allow photo access in Settings to save images"
      default:
        saveAlertMessage = "Unable to save image"
      }
      showingSaveAlert = true
    }
  }
}
