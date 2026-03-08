//
//  MapView.swift
//  LensNote
//
//  Created by 박태영 on 1/30/26.
//

/// 지도 위에 사진 위치를 표시하고, 클러스터링/권한/썸네일/역지오코딩을 처리하는 화면입니다.
/// 주요 구성:
/// - PhotoPin: 지도에 표시할 사진 핀 데이터 모델
/// - MapViewModel: 사진/권한/지오코딩 로직 관리
/// - MapView: SwiftUI 지도 + 리스트/카드 UI

import SwiftUI
import MapKit
import Combine
import Photos
import CoreLocation

/// 한 장의 사진을 지도에 표시하기 위한 최소 정보(좌표/제목/썸네일 등)
struct PhotoPin: Identifiable, Equatable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let title: String
    let createdAt: Date
    let assetLocalIdentifier: String?
    let thumbnail: UIImage?

    /// MKMapKit에서 사용하는 좌표 타입으로 변환한 값
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// 클러스터링 결과를 표현하는 아이템(단일 핀 또는 여러 핀이 모인 클러스터)
struct ClusterItem: Identifiable {
    enum Kind { case single(PhotoPin); case cluster(center: CLLocationCoordinate2D, pins: [PhotoPin]) }
    let id: UUID
    let kind: Kind
    var coordinate: CLLocationCoordinate2D {
        switch kind {
        case .single(let pin): return pin.coordinate
        case .cluster(let center, _): return center
        }
    }
}

/// 클러스터 동등성 비교: 단일은 내부 핀 비교, 클러스터는 중심과 포함된 핀 배열 비교
extension ClusterItem.Kind: Equatable {
    static func == (lhs: ClusterItem.Kind, rhs: ClusterItem.Kind) -> Bool {
        switch (lhs, rhs) {
        case let (.single(a), .single(b)):
            return a == b
        case let (.cluster(centerA, pinsA), .cluster(centerB, pinsB)):
            return centerA.latitude == centerB.latitude &&
                   centerA.longitude == centerB.longitude &&
                   pinsA == pinsB
        default:
            return false
        }
    }
}

/// 아이템 동등성 비교는 고유 id 기준
extension ClusterItem: Equatable {
    static func == (lhs: ClusterItem, rhs: ClusterItem) -> Bool {
        lhs.id == rhs.id
    }
}

/// 사진 권한 요청/자산 로딩/썸네일 캐시/역지오코딩(지명) 처리 등 비즈니스 로직을 담당하는 뷰모델
@MainActor
final class MapViewModel: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    /// 사진 권한 상태를 UI에서 표현하기 위한 열거형
    enum PermissionState: Equatable {
        case unknown
        case allowed
        case limited
        case denied
        case restricted
        case missingUsageDescription
    }

    // UI 바인딩 상태: 지도 핀, 선택된 핀, 권한 상태, 로딩 상태
    @Published var pins: [PhotoPin] = []
    @Published var selectedPin: PhotoPin?
    @Published var permissionState: PermissionState = .unknown
    @Published var isLoading: Bool = false

    // 내부 상태/도구들:
    // - geocoder: 좌표 -> 지명 역지오코딩
    // - fetchResult/loadTask: 포토 라이브러리 페치와 비동기 배치 로딩
    // - geocodeCache/Queue: 지명 캐시와 큐(중복 방지용 키 포함)
    // - hasLoadedPhotos: 중복 로딩 방지 플래그
    private let geocoder = CLGeocoder()
    private var fetchResult: PHFetchResult<PHAsset>?
    private var loadTask: Task<Void, Never>?
    private var loadedAssetIndex = 0
    private let initialBatchSize = 50
    private let batchSize = 200
    private var isObserverRegistered = false
    private var geocodeCache: [String: String] = [:]
    private var geocodeQueue: [PhotoPin] = []
    private var geocodeQueueKeys: Set<String> = []
    private var geocodeTask: Task<Void, Never>?
    private let geocodeCacheKey = "MapViewModel.GeocodeCache.v1"
    private var hasLoadedPhotos = false

    /// 시작 시 지명 캐시를 불러오고, 권한 없을 때를 대비한 목업 핀을 로드
    override init() {
        super.init()
        loadGeocodeCache()
        loadMockPins()
    }

    /// 옵저버/태스크 정리
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
        loadTask?.cancel()
        geocodeTask?.cancel()
    }

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
                thumbnail: UIImage(systemName: "photo")
            ),
            PhotoPin(
                id: UUID(),
                latitude: 37.5700,
                longitude: 126.9769,
                title: "Gyeongbokgung",
                createdAt: Date().addingTimeInterval(-7200),
                assetLocalIdentifier: nil,
                thumbnail: UIImage(systemName: "photo.fill")
            ),
            PhotoPin(
                id: UUID(),
                latitude: 37.5512,
                longitude: 126.9882,
                title: "Namsan Tower",
                createdAt: Date().addingTimeInterval(-14400),
                assetLocalIdentifier: nil,
                thumbnail: UIImage(systemName: "photo.on.rectangle")
            )
        ]
    }

    /// 최초 1회 사진 권한을 요청하고, 허용 시 포토 라이브러리에서 사진을 배치로 로드
    func loadPhotoPinsIfNeeded() async {
        guard !hasLoadedPhotos else { return }
        guard !isLoading else { return }
        isLoading = true

        guard hasPhotoUsageDescription() else {
            permissionState = .missingUsageDescription
            loadMockPins()
            isLoading = false
            return
        }

        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        updatePermissionState(with: status)

        guard status == .authorized || status == .limited else {
            loadMockPins()
            isLoading = false
            return
        }

        if !isObserverRegistered {
            PHPhotoLibrary.shared().register(self)
            isObserverRegistered = true
        }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: .image, options: options)
        await startLoading(from: result)
        hasLoadedPhotos = true
        isLoading = false
    }

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

    /// Info.plist에 NSPhotoLibraryUsageDescription 키 존재 여부 확인
    private func hasPhotoUsageDescription() -> Bool {
        Bundle.main.object(forInfoDictionaryKey: "NSPhotoLibraryUsageDescription") != nil
    }

    /// PHAuthorizationStatus를 앱 내부 PermissionState로 변환
    private func updatePermissionState(with status: PHAuthorizationStatus) {
        switch status {
        case .authorized:
            permissionState = .allowed
        case .limited:
            permissionState = .limited
        case .denied:
            permissionState = .denied
        case .restricted:
            permissionState = .restricted
        case .notDetermined:
            permissionState = .unknown
        @unknown default:
            permissionState = .unknown
        }
    }

    /// 주어진 FetchResult로부터 핀/썸네일 캐시 초기화 및 첫 배치 로드 시작
    private func startLoading(from result: PHFetchResult<PHAsset>) async {
        loadTask?.cancel()
        fetchResult = result
        loadedAssetIndex = 0
        pins = []
        await loadNextBatch(from: result, size: initialBatchSize)

        if loadedAssetIndex < result.count {
            loadTask = Task { [weak self] in
                guard let self else { return }
                await self.loadRemainingBatches(from: result)
            }
        }
    }

    /// 초기 배치 이후 남은 자산을 여러 배치로 이어서 로드
    private func loadRemainingBatches(from result: PHFetchResult<PHAsset>) async {
        while !Task.isCancelled && loadedAssetIndex < result.count {
            await loadNextBatch(from: result, size: batchSize)
            await Task.yield()
        }
    }

    /// 지정한 크기만큼 다음 사진들을 읽어 핀과 썸네일 캐시를 준비
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
                    thumbnail: nil
                )
            )
        }

        pins.append(contentsOf: batchPins)
    }

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

    /// 화면에 보이는 핀들에 대해 지명 캐시를 확인하고, 없는 경우 역지오코딩 큐에 등록
    func updatePlaceNamesIfNeeded(for visiblePins: [PhotoPin]) {
        guard !visiblePins.isEmpty else { return }

        for pin in visiblePins {
            let key = geocodeKey(for: pin.coordinate)
            if let cached = geocodeCache[key] {
                updateTitleIfNeeded(pinID: pin.id, placeName: cached)
                continue
            }
            if geocodeQueueKeys.contains(key) {
                continue
            }

            geocodeQueueKeys.insert(key)
            geocodeQueue.append(pin)
        }

        startGeocodeQueueIfNeeded()
    }

    /// 역지오코딩 작업 큐를 시작/실행하여 순차적으로 지명을 가져오고 캐시/타이틀 갱신
    private func startGeocodeQueueIfNeeded() {
        guard geocodeTask == nil else { return }
        geocodeTask = Task { [weak self] in
            guard let self else { return }
            await self.runGeocodeQueue()
        }
    }

    private func runGeocodeQueue() async {
        while !Task.isCancelled, !geocodeQueue.isEmpty {
            let pin = geocodeQueue.removeFirst()
            let key = geocodeKey(for: pin.coordinate)
            let location = CLLocation(latitude: pin.latitude, longitude: pin.longitude)

            let place = await reverseGeocode(location: location)
            if let place {
                geocodeCache[key] = place
                updateTitleIfNeeded(pinID: pin.id, placeName: place)
                saveGeocodeCache()
            }
            geocodeQueueKeys.remove(key)
        }

        geocodeTask = nil
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
                thumbnail: pin.thumbnail
            )
        }
    }

    /// CLGeocoder를 사용해 좌표를 지명(가능하면 name, 아니면 locality/행정구역/국가)으로 변환
    private func reverseGeocode(location: CLLocation) async -> String? {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }

            if let name = placemark.name {
                return name
            }
            if let locality = placemark.locality {
                return locality
            }
            if let administrativeArea = placemark.administrativeArea {
                return administrativeArea
            }
            return placemark.country
        } catch {
            return nil
        }
    }

    /// 좌표를 0.001도 단위로 라운딩한 키(근처 좌표는 동일 키로 취급)
    private func geocodeKey(for coordinate: CLLocationCoordinate2D) -> String {
        let lat = (coordinate.latitude * 1000).rounded() / 1000
        let lon = (coordinate.longitude * 1000).rounded() / 1000
        return "\(lat)_\(lon)"
    }

    /// 지명 캐시(UserDefaults) 로드/저장
    private func loadGeocodeCache() {
        guard let data = UserDefaults.standard.data(forKey: geocodeCacheKey) else { return }
        if let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            geocodeCache = decoded
        }
    }

    private func saveGeocodeCache() {
        guard let data = try? JSONEncoder().encode(geocodeCache) else { return }
        UserDefaults.standard.set(data, forKey: geocodeCacheKey)
    }

    /// 사진 라이브러리 변경 시 최신 결과로 다시 로드
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            guard let currentResult = fetchResult,
                  let details = changeInstance.changeDetails(for: currentResult) else {
                return
            }

            let updatedResult = details.fetchResultAfterChanges
            await startLoading(from: updatedResult)
        }
    }
}

struct MapView: View {
    @ObservedObject var viewModel: MapViewModel

    // 지도 카메라/선택/현재 영역/클러스터 상태
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780),
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
    )
    @State private var selection: UUID?
    @State private var currentRegion: MKCoordinateRegion?
    @State private var clusteredItems: [ClusterItem] = []
    @State private var clusterRebuildTask: Task<Void, Never>?

    /// onChange 관찰을 위한 비교 가능 키(문자열)로 현재 영역의 중심/스팬을 반올림하여 구성
    private var regionSignature: String? {
        guard let r = currentRegion else { return nil }
        // 소수점 5자리 반올림으로 노이즈를 줄여 과도한 업데이트 방지
        func round5(_ v: Double) -> Double { (v * 1e5).rounded() / 1e5 }
        let lat = round5(r.center.latitude)
        let lon = round5(r.center.longitude)
        let dlat = round5(r.span.latitudeDelta)
        let dlon = round5(r.span.longitudeDelta)
        return "\(lat)_\(lon)_\(dlat)_\(dlon)"
    }

    var body: some View {
        // 반응형 레이아웃: 폭 600 미만이면 컴팩트로 간주하여 하단 시트, 아니면 우측 패널
        GeometryReader { geo in
            let isCompact = geo.size.width < 600
            ZStack {
                // Map content
                Map(position: $position, selection: $selection) {
                    ForEach(clusteredItems) { item in
                        switch item.kind {
                        case .single(let pin):
                            Annotation(pin.title, coordinate: pin.coordinate) {
                                PinAnnotationView(selected: selection == pin.id)
                                    .onTapGesture { selection = pin.id }
                            }
                            .tag(pin.id)
                        case .cluster(let center, let pins):
                            Annotation("cluster", coordinate: center) {
                                Button {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        // Zoom in towards the cluster center
                                        position = .region(
                                            MKCoordinateRegion(
                                                center: center,
                                                span: MKCoordinateSpan(latitudeDelta: max((currentRegion?.span.latitudeDelta ?? 0.1) / 2, 0.002),
                                                                        longitudeDelta: max((currentRegion?.span.longitudeDelta ?? 0.1) / 2, 0.002))
                                            )
                                        )
                                    }
                                } label: {
                                    ClusterBadgeView(count: pins.count)
                                }
                            }
                        }
                    }
                }
                .mapStyle(.standard)
                // 초기 로드: 약간의 지연 후 사진 로드 및 첫 클러스터 계산
                .task {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    await viewModel.loadPhotoPinsIfNeeded()
                    scheduleClusterRebuild(immediate: true)
                }
                // 카메라 변경 시 현재 영역 업데이트
                .onMapCameraChange { context in
                    currentRegion = context.region
                }
                // 영역 시그니처 변경 시 클러스터 재계산
                .onChange(of: regionSignature) { _ in
                    scheduleClusterRebuild()
                }
                // 보이는 핀 변경 시 지명 업데이트 및 클러스터 재계산
                .onChange(of: visiblePins.map(\.id)) { _ in
                    viewModel.updatePlaceNamesIfNeeded(for: visiblePins)
                    scheduleClusterRebuild()
                }
                // 선택 변경 시 포커스/줌 애니메이션 + 카드 열기/닫기
                .onChange(of: selection) { newValue in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        if let id = newValue,
                           let pin = viewModel.pins.first(where: { $0.id == id }) {
                            viewModel.select(pin: pin)
                            // Step 1: quick focus
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                position = .region(
                                    MKCoordinateRegion(
                                        center: pin.coordinate,
                                        span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
                                    )
                                )
                            }
                            // Step 2: ease-in closer zoom
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                    position = .region(
                                        MKCoordinateRegion(
                                            center: pin.coordinate,
                                            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                                        )
                                    )
                                }
                            }
                        } else {
                            viewModel.closeCard()
                        }
                    }
                }
                .onDisappear {
                    clusterRebuildTask?.cancel()
                    clusterRebuildTask = nil
                }
                .onChange(of: viewModel.selectedPin?.id) { newValue in
                    if selection != newValue {
                        selection = newValue
                    }
                }
                // 권한 배너/로딩 배너 표시
                .safeAreaInset(edge: .top) {
                    if viewModel.permissionState == .denied
                        || viewModel.permissionState == .restricted
                        || viewModel.permissionState == .missingUsageDescription {
                        PermissionBannerView(
                            state: viewModel.permissionState,
                            onOpenSettings: viewModel.openAppSettings
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    } else if viewModel.isLoading {
                        LoadingBannerView()
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }

                // 보이는 핀이 있을 때만 패널 표시(컴팩트: 하단 시트, 레귤러: 우측 패널)
                if !visiblePins.isEmpty {
                    if isCompact {
                        // Bottom sheet style on compact width
                        VStack { Spacer() ; SidePanelList(pins: visiblePins, selection: $selection) }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.bottom, 8)
                    } else {
                        // Right side panel on regular width
                        HStack { Spacer() ; SidePanelList(pins: visiblePins, selection: $selection) }
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                            .padding(.trailing, 8)
                    }
                }
            }
        }
        // 핀 선택 시 하단 카드 표시
        .safeAreaInset(edge: .bottom) {
            if let pin = viewModel.selectedPin {
                PinCardView(pin: pin) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        viewModel.closeCard()
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }

    /// 현재 맵 영역에 보이는 핀만 필터링하고, 많을 경우 다운샘플링
    private var visiblePins: [PhotoPin] {
        guard let region = currentRegion else { return viewModel.pins }
        let filtered = viewModel.pins.filter { isCoordinate($0.coordinate, in: region) }
        return downsamplePins(filtered, in: region)
    }

    /// 좌표가 주어진 영역 박스 안에 포함되는지 판정
    private func isCoordinate(_ coordinate: CLLocationCoordinate2D, in region: MKCoordinateRegion) -> Bool {
        let halfLat = region.span.latitudeDelta / 2
        let halfLon = region.span.longitudeDelta / 2
        let latMin = region.center.latitude - halfLat
        let latMax = region.center.latitude + halfLat
        let lonMin = region.center.longitude - halfLon
        let lonMax = region.center.longitude + halfLon
        return coordinate.latitude >= latMin
            && coordinate.latitude <= latMax
            && coordinate.longitude >= lonMin
            && coordinate.longitude <= lonMax
    }

    /// 핀이 너무 많을 때 격자 버킷으로 대표 핀만 남겨 UI 부하 감소
    private func downsamplePins(_ pins: [PhotoPin], in region: MKCoordinateRegion) -> [PhotoPin] {
        guard pins.count > 250 else { return pins }

        let latStep = max(region.span.latitudeDelta / 25, 0.001)
        let lonStep = max(region.span.longitudeDelta / 25, 0.001)
        var buckets: [String: PhotoPin] = [:]

        for pin in pins {
            let latBucket = Int((pin.latitude / latStep).rounded(.down))
            let lonBucket = Int((pin.longitude / lonStep).rounded(.down))
            let key = "\(latBucket)_\(lonBucket)"
            if buckets[key] == nil {
                buckets[key] = pin
            }
        }

        return Array(buckets.values)
    }

    /// 영역 스케일에 따라 적응형 격자 크기를 계산하여 클러스터링(단일/클러스터 아이템 생성)
    private func buildClusters(from pins: [PhotoPin], in region: MKCoordinateRegion?) -> [ClusterItem] {
        guard let region else { return pins.map { ClusterItem(id: $0.id, kind: .single($0)) } }
        // Determine grid size based on zoom level
        let grid = max(Int(ceil(25.0 * (0.08 / max(region.span.latitudeDelta, 0.0005)))), 8)
        let latStep = max(region.span.latitudeDelta / Double(grid), 0.0005)
        let lonStep = max(region.span.longitudeDelta / Double(grid), 0.0005)

        var buckets: [String: [PhotoPin]] = [:]
        for pin in pins {
            let latBucket = Int(floor((pin.latitude - (region.center.latitude - region.span.latitudeDelta/2)) / latStep))
            let lonBucket = Int(floor((pin.longitude - (region.center.longitude - region.span.longitudeDelta/2)) / lonStep))
            let key = "\(latBucket)_\(lonBucket)"
            buckets[key, default: []].append(pin)
        }

        var items: [ClusterItem] = []
        for (_, group) in buckets {
            if group.count == 1, let pin = group.first {
                items.append(ClusterItem(id: pin.id, kind: .single(pin)))
            } else {
                // Compute centroid
                let avgLat = group.map { $0.latitude }.reduce(0, +) / Double(group.count)
                let avgLon = group.map { $0.longitude }.reduce(0, +) / Double(group.count)
                let center = CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
                items.append(ClusterItem(id: UUID(), kind: .cluster(center: center, pins: group)))
            }
        }
        return items
    }

    /// 지도 이동/줌 중 과도한 클러스터 재계산을 줄이기 위한 디바운스 스케줄러.
    /// immediate가 true면 즉시 계산, false면 짧게 지연 후 마지막 상태만 반영한다.
    private func scheduleClusterRebuild(immediate: Bool = false) {
        clusterRebuildTask?.cancel()

        let pinsSnapshot = visiblePins
        let regionSnapshot = currentRegion

        if immediate {
            clusteredItems = buildClusters(from: pinsSnapshot, in: regionSnapshot)
            return
        }

        clusterRebuildTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 130_000_000)
            guard !Task.isCancelled else { return }
            clusteredItems = buildClusters(from: pinsSnapshot, in: regionSnapshot)
        }
    }
}

/// 지도 핀 아이콘 뷰(선택 시 하이라이트)
private struct PinAnnotationView: View {
    let selected: Bool
    var body: some View {
        ZStack {
            if selected {
                Circle().fill(Color.accentColor.opacity(0.25))
                    .frame(width: 44, height: 44)
                    .transition(.scale)
            }
            Image(systemName: selected ? "mappin.circle.fill" : "mappin.circle")
                .font(.title3)
                .foregroundStyle(selected ? Color.accentColor : Color.primary)
        }
    }
}

/// 클러스터 개수 배지
private struct ClusterBadgeView: View {
    let count: Int
    var body: some View {
        ZStack {
            Circle().fill(.ultraThinMaterial).frame(width: 40, height: 40)
            Circle().strokeBorder(.secondary.opacity(0.4), lineWidth: 1).frame(width: 40, height: 40)
            Text("\(count)").font(.subheadline).bold()
        }
        .shadow(radius: 3, y: 2)
    }
}

/// 사이드/바텀 패널 목록(썸네일+제목)
private struct SidePanelList: View {
    let pins: [PhotoPin]
    @Binding var selection: UUID?
    private var displayedPins: [PhotoPin] { Array(pins.prefix(60)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("이 지역의 사진")
                    .font(.headline)
                Spacer()
                Text("\(pins.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(displayedPins) { pin in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                selection = pin.id
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Group {
                                    PinThumbnailView(pin: pin, size: 48)
                                }
                                .frame(width: 48, height: 48)
                                .background(Color(.systemGray5))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pin.title)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    Text(pin.createdAt.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(10)
                            .background(selection == pin.id ? .thinMaterial : .ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(radius: 4, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
        }
        .frame(maxWidth: 380)
        .background(.bar)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(radius: 10, y: 6)
    }
}

/// 하단 상세 카드(썸네일/제목/시간)
private struct PinCardView: View {
    let pin: PhotoPin
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(pin.title)
                    .font(.headline)

                Text(pin.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("닫기")
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(radius: 8, y: 4)
    }

    private var thumbnail: some View {
        PinThumbnailView(pin: pin, size: 44)
        .frame(width: 44, height: 44)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// 권한 안내 배너
private struct PermissionBannerView: View {
    let state: MapViewModel.PermissionState
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .bold()
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if state != .missingUsageDescription {
                Button("설정") {
                    onOpenSettings()
                }
                .font(.subheadline)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(radius: 6, y: 3)
    }

    private var title: String {
        switch state {
        case .denied:
            return "사진 접근 권한이 필요해요"
        case .restricted:
            return "사진 접근이 제한되어 있어요"
        case .missingUsageDescription:
            return "권한 설명 키가 필요해요"
        default:
            return "사진 접근 상태 확인"
        }
    }

    private var message: String {
        switch state {
        case .denied:
            return "설정에서 사진 접근을 허용해주세요."
        case .restricted:
            return "기기 제한으로 사진 접근이 불가합니다."
        case .missingUsageDescription:
            return "Info.plist에 사진 권한 설명을 추가해주세요."
        default:
            return "권한 상태를 확인할 수 없습니다."
        }
    }
}

/// 로딩 상태 배너
private struct LoadingBannerView: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("사진을 불러오는 중...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(radius: 6, y: 3)
    }
}

private struct PinThumbnailView: View {
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
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: pin.assetLocalIdentifier) {
            guard loadedImage == nil,
                  let identifier = pin.assetLocalIdentifier else { return }
            loadedImage = await MapThumbnailLoader.shared.load(localIdentifier: identifier, targetSize: CGSize(width: size * 2, height: size * 2))
        }
    }
}

private final class MapThumbnailLoader {
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

#Preview {
    MapView(viewModel: MapViewModel())
}
