//
//  FullscreenPosterView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 1/4/26.
//

import Kingfisher
import Photos
import SwiftUI

struct FullscreenPosterView: View {
  let posterPath: String
  @Environment(\.dismiss) private var dismiss
  @State private var image: UIImage?
  @State private var isLoading = true
  @State private var showingSaveAlert = false
  @State private var saveAlertMessage = ""
  @State private var scale: CGFloat = 1.0
  @State private var lastScale: CGFloat = 1.0

  private var imageURL: URL? {
    URL(string: "\(SIMKL_CDN_URL)/posters/\(posterPath)_m.jpg")
  }

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      if isLoading {
        ProgressView()
          .tint(.white)
          .scaleEffect(1.5)
      } else if let image = image {
        Image(uiImage: image)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .scaleEffect(scale)
          .gesture(
            MagnificationGesture()
              .onChanged { value in
                scale = lastScale * value
              }
              .onEnded { _ in
                lastScale = scale
                if scale < 1.0 {
                  withAnimation {
                    scale = 1.0
                    lastScale = 1.0
                  }
                }
              }
          )
          .onTapGesture(count: 2) {
            withAnimation {
              if scale > 1.0 {
                scale = 1.0
                lastScale = 1.0
              } else {
                scale = 2.0
                lastScale = 2.0
              }
            }
          }
      }
    }
    .overlay(alignment: .topTrailing) {
      HStack(spacing: 16) {
        if image != nil {
          Button {
            saveImageToPhotos()
          } label: {
            Image(systemName: "square.and.arrow.down")
              .font(.title2)
              .foregroundColor(.white)
              .padding(12)
              .background(Circle().fill(Color.black.opacity(0.5)))
          }
        }

        Button {
          dismiss()
        } label: {
          Image(systemName: "xmark")
            .font(.title2)
            .foregroundColor(.white)
            .padding(12)
            .background(Circle().fill(Color.black.opacity(0.5)))
        }
      }
      .padding()
    }
    .onAppear {
      loadImage()
    }
    .alert("Save Image", isPresented: $showingSaveAlert) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(saveAlertMessage)
    }
    .statusBarHidden()
  }

  private func loadImage() {
    guard let url = imageURL else {
      isLoading = false
      return
    }

    KingfisherManager.shared.retrieveImage(with: url) { result in
      DispatchQueue.main.async {
        switch result {
        case .success(let imageResult):
          self.image = imageResult.image
        case .failure:
          self.image = nil
        }
        self.isLoading = false
      }
    }
  }

  private func saveImageToPhotos() {
    guard let image = image else { return }

    PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
      DispatchQueue.main.async {
        switch status {
        case .authorized, .limited:
          UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
          saveAlertMessage = "Image saved to Photos"
          showingSaveAlert = true
        case .denied, .restricted:
          saveAlertMessage = "Please allow photo access in Settings to save images"
          showingSaveAlert = true
        case .notDetermined:
          saveAlertMessage = "Unable to save image"
          showingSaveAlert = true
        @unknown default:
          saveAlertMessage = "Unable to save image"
          showingSaveAlert = true
        }
      }
    }
  }
}
