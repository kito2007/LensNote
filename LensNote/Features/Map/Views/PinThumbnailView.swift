//
//  PinThumbnailView.swift
//  LensNote
//

import SwiftUI
import Photos

struct PinThumbnailView: View {
    let pin: PhotoPin
    let size: CGFloat

    @State private var loadedImage: UIImage?

    var body: some View {
        Group {
            if let loadedImage {
                Image(uiImage: loadedImage)
                    .resizable()
                    .scaledToFill()
            } else if let fallback = pin.thumbnail {
                Image(uiImage: fallback)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.2)
                    .foregroundStyle(LensNoteTheme.Colors.textTertiary)
            }
        }
        .task(id: pin.assetLocalIdentifier) {
            guard loadedImage == nil,
                  let identifier = pin.assetLocalIdentifier else { return }
            loadedImage = await MapThumbnailLoader.shared.load(localIdentifier: identifier, targetSize: CGSize(width: size * 2, height: size * 2))
        }
    }
}

final class MapThumbnailLoader {
    static let shared = MapThumbnailLoader()

    private let imageManager = PHCachingImageManager()
    private let cache = NSCache<NSString, UIImage>()

    private init() {}

    func load(localIdentifier: String, targetSize: CGSize) async -> UIImage? {
        let key = "\(localIdentifier)_\(Int(targetSize.width))x\(Int(targetSize.height))" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = fetchResult.firstObject else { return nil }

        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isSynchronous = false
        options.isNetworkAccessAllowed = false

        let image = await withCheckedContinuation { continuation in
            var didResume = false
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                if didResume { return }
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if isDegraded { return }
                didResume = true
                continuation.resume(returning: image)
            }
        }

        if let image {
            cache.setObject(image, forKey: key)
        }
        return image
    }
}
