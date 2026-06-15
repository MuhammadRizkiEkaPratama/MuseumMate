//
//  ScanThumbnail.swift
//  MuseumMate
//
//  Loads a scan's thumbnail (or full image) from disk, with a graceful
//  placeholder. Used by History rows and the Favorites grid.
//

import SwiftUI

struct ScanThumbnail: View {
    let result: ScanResult
    var cornerRadius: CGFloat = 12

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.appSurfaceUp)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo.artframe")
                    .font(.title3)
                    .foregroundStyle(Color.appTextMuted)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task {
            if image == nil {
                let name = result.thumbnailFileName ?? result.imageFileName
                image = ImageStore.loadImage(named: name)
            }
        }
    }
}
