//
//  MapViewModel.swift
//  LensNote
//

import SwiftUI
import MapKit
import Combine
import Photos
import CoreLocation

/// 지도 화면의 UI 상태와 기능 흐름을 조율하는 뷰모델.
/// 포토 라이브러리 접근은 PhotoLibraryService, 역지오코딩은 GeocodingService에 위임한다.
@MainActor
final class MapViewModel: NSObject, ObservableObject {

    // MARK: - PermissionState

    /// 사진 권한 상태를 UI에서 표현하기 위한 열거형
    enum PermissionState: Equatable {
        case unknown
        case allowed
        case limited
        case denied
        case restricted
        case missingUsageDescription
    }

    // MARK: - Published state

    @Published var pins: [PhotoPin] = []
    @Published var selectedPin: PhotoPin?
    @Published var permissionState: PermissionState = .unknown
    @Published var isLoading: Bool = false

    // MARK: - Private services & state

    private let photoLibraryService = PhotoLibraryService()
    private let geocodingService = GeocodingService()
    private var hasLoadedPhotos = false
    private let fetchPhotoPinsUseCase: FetchPhotoPinsUseCase?

    // MARK: - Init

    /// 프리뷰/테스트용 기본 이니셜라이저 — FetchPhotoPinsUseCase 없이 동작한다.
    override init() {
        self.fetchPhotoPinsUseCase = nil
        super.init()
        setupPhotoLibraryService()
        loadMockPins()
    }

    /// 프로덕션 이니셜라이저 — DI를 통해 FetchPhotoPinsUseCase를 주입한다.
    init(fetchPhotoPinsUseCase: FetchPhotoPinsUseCase) {
        self.fetchPhotoPinsUseCase = fetchPhotoPinsUseCase
        super.init()
        setupPhotoLibraryService()
        loadMockPins()
    }

    // MARK: - Service wiring

    private func setupPhotoLibraryService() {
        photoLibraryService.onPinsLoaded = { [weak self] batch in
            self?.pins.append(contentsOf: batch)
        }
        photoLibraryService.onLibraryChanged = { [weak self] in
            guard let self else { return }
            // 라이브러리 변경 시 library 핀을 초기화하고 다시 로드한다.
            self.pins = self.pins.filter { $0.source == .lensNote }
            Task { await self.photoLibraryService.startLoadingPins() }
        }
    }

    // MARK: - LensNote pins

    /// LensNote 저장 경로로 저장된 사진을 핀으로 변환하여 pins 배열 앞쪽에 병합한다.
    /// 좌표 없는 PhotoItem은 지도에 표시할 수 없으므로 스킵한다.
    func loadLensNotePins() {
        guard let useCase = fetchPhotoPinsUseCase else { return }
        let items = (try? useCase.execute()) ?? []
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        let newPins: [PhotoPin] = items.compactMap { item in
            guard let coord = item.coordinate else { return nil }
            return PhotoPin(
                id: item.id,
                latitude: coord.latitude,
                longitude: coord.longitude,
                title: dateFormatter.string(from: item.createdAt),
                createdAt: item.createdAt,
                assetLocalIdentifier: nil,
                thumbnail: nil,
                source: .lensNote
            )
        }

        // 기존 lensNote 핀을 교체하고 library 핀은 유지한다.
        let libraryPins = pins.filter { $0.source == .library }
        pins = newPins + libraryPins
    }

    // MARK: - Mock pins

    /// 권한 부재/거부 시에도 UI를 보여주기 위한 샘플 핀 데이터
    func loadMockPins() {
        pins = [
            PhotoPin(
                id: UUID(),
                latitude: 37.5665,
                longitude: 126.9780,
                title: "Seoul City Hall",
                createdAt: Date().addingTimeInterval(-3600),
                assetLocalIdentifier: nil,
                thumbnail: UIImage(systemName: "photo"),
                source: .library
            ),
            PhotoPin(
                id: UUID(),
                latitude: 37.5700,
                longitude: 126.9769,
                title: "Gyeongbokgung",
                createdAt: Date().addingTimeInterval(-7200),
                assetLocalIdentifier: nil,
                thumbnail: UIImage(systemName: "photo.fill"),
                source: .library
            ),
            PhotoPin(
                id: UUID(),
                latitude: 37.5512,
                longitude: 126.9882,
                title: "Namsan Tower",
                createdAt: Date().addingTimeInterval(-14400),
                assetLocalIdentifier: nil,
                thumbnail: UIImage(systemName: "photo.on.rectangle"),
                source: .library
            )
        ]
    }

    // MARK: - Main loading entry point

    /// 최초 1회 사진 권한을 요청하고, 허용 시 포토 라이브러리에서 사진을 배치로 로드
    func loadPhotoPinsIfNeeded() async {
        guard !hasLoadedPhotos else { return }
        guard !isLoading else { return }
        isLoading = true

        guard photoLibraryService.hasPhotoUsageDescription() else {
            permissionState = .missingUsageDescription
            loadMockPins()
            loadLensNotePins()
            isLoading = false
            return
        }

        let state = await photoLibraryService.requestAccess()
        permissionState = state

        guard state == .allowed || state == .limited else {
            loadMockPins()
            loadLensNotePins()
            isLoading = false
            return
        }

        pins = []
        await photoLibraryService.startLoadingPins()
        // PHPhotoLibrary 로드 후 LensNote 저장 경로 핀도 병합한다.
        loadLensNotePins()
        hasLoadedPhotos = true
        isLoading = false
    }

    // MARK: - Geocoding

    /// 화면에 보이는 핀들에 대해 지명 캐시를 확인하고, 없는 경우 역지오코딩 큐에 등록
    func updatePlaceNamesIfNeeded(for visiblePins: [PhotoPin]) {
        geocodingService.updatePlaceNamesIfNeeded(for: visiblePins) { [weak self] pinID, place in
            self?.updateTitleIfNeeded(pinID: pinID, placeName: place)
        }
    }

    /// 특정 핀의 제목을 지명 반영 형태로 업데이트(변경 시에만 교체)
    private func updateTitleIfNeeded(pinID: UUID, placeName: String) {
        guard let index = pins.firstIndex(where: { $0.id == pinID }) else { return }
        let pin = pins[index]
        let dateTitle = pin.createdAt.formatted(date: .abbreviated, time: .omitted)
        let newTitle = "\(dateTitle) · \(placeName)"
        if pin.title != newTitle {
            pins[index] = PhotoPin(
                id: pin.id,
                latitude: pin.latitude,
                longitude: pin.longitude,
                title: newTitle,
                createdAt: pin.createdAt,
                assetLocalIdentifier: pin.assetLocalIdentifier,
                thumbnail: pin.thumbnail,
                source: pin.source
            )
        }
    }

    // MARK: - UI actions

    /// 핀 선택/해제하여 하단 카드 표시 제어
    func select(pin: PhotoPin) {
        selectedPin = pin
    }

    func closeCard() {
        selectedPin = nil
    }

    /// 설정 앱으로 이동하여 권한을 변경할 수 있도록 함
    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
