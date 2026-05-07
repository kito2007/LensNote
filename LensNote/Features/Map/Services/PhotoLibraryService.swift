//
//  PhotoLibraryService.swift
//  LensNote
//

import SwiftUI
import Photos
import CoreLocation

/// PHPhotoLibrary 권한 요청, 사진 자산 페치, 배치 로드, 라이브러리 변경 감시를 담당하는 서비스.
/// 핀이 준비될 때마다 `onPinsLoaded` 콜백으로 배치를 전달하고,
/// 라이브러리 변경이 감지되면 `onLibraryChanged` 콜백을 호출한다.
@MainActor
final class PhotoLibraryService: NSObject, PHPhotoLibraryChangeObserver {

    // MARK: - Callbacks

    /// 배치 로드가 완료될 때마다 호출 (라이브러리 핀 배열)
    var onPinsLoaded: (([PhotoPin]) -> Void)?
    /// 라이브러리 변경이 감지될 때 호출
    var onLibraryChanged: (() -> Void)?

    // MARK: - Private state

    private var fetchResult: PHFetchResult<PHAsset>?
    private var loadTask: Task<Void, Never>?
    private var loadedAssetIndex = 0
    private let initialBatchSize = 50
    private let batchSize = 200
    private var isObserverRegistered = false

    // MARK: - Public API

    /// Info.plist에 NSPhotoLibraryUsageDescription 키가 존재하는지 확인
    func hasPhotoUsageDescription() -> Bool {
        Bundle.main.object(forInfoDictionaryKey: "NSPhotoLibraryUsageDescription") != nil
    }

    /// 사진 권한을 요청하고 PermissionState를 반환한다.
    func requestAccess() async -> MapViewModel.PermissionState {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return permissionState(from: status)
    }

    /// 권한이 허용된 상태에서 자산을 페치하고 배치 로드를 시작한다.
    /// 배치가 준비될 때마다 `onPinsLoaded` 가 호출된다.
    func startLoadingPins() async {
        if !isObserverRegistered {
            PHPhotoLibrary.shared().register(self)
            isObserverRegistered = true
        }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: .image, options: options)
        await startLoading(from: result)
    }

    // MARK: - PHPhotoLibraryChangeObserver

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            guard let currentResult = self.fetchResult,
                  let details = changeInstance.changeDetails(for: currentResult) else {
                return
            }
            let updatedResult = details.fetchResultAfterChanges
            await self.startLoading(from: updatedResult)
            self.onLibraryChanged?()
        }
    }

    // MARK: - Deinit

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
        loadTask?.cancel()
    }

    // MARK: - Private loading

    private func startLoading(from result: PHFetchResult<PHAsset>) async {
        loadTask?.cancel()
        fetchResult = result
        loadedAssetIndex = 0
        await loadNextBatch(from: result, size: initialBatchSize)

        if loadedAssetIndex < result.count {
            loadTask = Task { [weak self] in
                guard let self else { return }
                await self.loadRemainingBatches(from: result)
            }
        }
    }

    private func loadRemainingBatches(from result: PHFetchResult<PHAsset>) async {
        while !Task.isCancelled && loadedAssetIndex < result.count {
            await loadNextBatch(from: result, size: batchSize)
            await Task.yield()
        }
    }

    private func loadNextBatch(from result: PHFetchResult<PHAsset>, size: Int) async {
        let endIndex = min(loadedAssetIndex + size, result.count)
        guard loadedAssetIndex < endIndex else { return }

        var batchPins: [PhotoPin] = []

        while loadedAssetIndex < endIndex {
            let asset = result.object(at: loadedAssetIndex)
            loadedAssetIndex += 1

            guard let location = asset.location else { continue }

            batchPins.append(
                PhotoPin(
                    id: UUID(),
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    title: title(for: asset, at: location, placeName: nil),
                    createdAt: asset.creationDate ?? Date(),
                    assetLocalIdentifier: asset.localIdentifier,
                    thumbnail: nil,
                    source: .library
                )
            )
        }

        if !batchPins.isEmpty {
            onPinsLoaded?(batchPins)
        }
    }

    // MARK: - Helpers

    /// 사진의 표시 제목: 날짜 + (지명 또는 좌표)
    private func title(for asset: PHAsset, at location: CLLocation, placeName: String?) -> String {
        let dateTitle = asset.creationDate?
            .formatted(date: .abbreviated, time: .omitted) ?? "Photo"
        if let placeName {
            return "\(dateTitle) · \(placeName)"
        } else {
            let coordinateTitle = String(
                format: "%.3f, %.3f",
                location.coordinate.latitude,
                location.coordinate.longitude
            )
            return "\(dateTitle) · \(coordinateTitle)"
        }
    }

    /// PHAuthorizationStatus → MapViewModel.PermissionState 변환
    private func permissionState(from status: PHAuthorizationStatus) -> MapViewModel.PermissionState {
        switch status {
        case .authorized:   return .allowed
        case .limited:      return .limited
        case .denied:       return .denied
        case .restricted:   return .restricted
        case .notDetermined: return .unknown
        @unknown default:   return .unknown
        }
    }
}
