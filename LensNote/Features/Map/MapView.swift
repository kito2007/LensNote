//
//  MapView.swift
//  LensNote
//
//  Created by 박태영 on 1/30/26.
//

import SwiftUI
import MapKit

struct MapView: View {
    @ObservedObject var viewModel: MapViewModel
    var onCameraTabTap: (() -> Void)?

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
                                PinAnnotationView(selected: selection == pin.id, source: pin.source)
                                    .onTapGesture { selection = pin.id }
                                    .accessibilityIdentifier("map.pin.\(pin.id)")
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
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
                // 초기 로드: 약간의 지연 후 사진 로드 및 첫 클러스터 계산
                .task {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    await viewModel.loadPhotoPinsIfNeeded()
                    scheduleClusterRebuild(immediate: true)
                    // Req 2.2 — onChange 부착 전에 설정된 포커스 요청(콜드스타트)도 적용.
                    if let coord = viewModel.focusCoordinate { focusCamera(on: coord) }
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
                // Req 2.2 — 카메라 결과 카드에서 요청한 핀으로 카메라 이동.
                .onChange(of: viewModel.focusCoordinate) { _, coord in
                    if let coord { focusCamera(on: coord) }
                }
                // 로딩 배너 표시
                .safeAreaInset(edge: .top) {
                    if viewModel.isLoading {
                        LoadingBannerView()
                            .padding(.horizontal, LensNoteTheme.Spacing.sm)
                            .padding(.top, LensNoteTheme.Spacing.xxs)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }

                // 하단 전환용 그라데이션 — FloatingDockBar와 맵 타일 경계 완화
                VStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .fill(LensNoteTheme.Gradients.mapOverlayBottom)
                        .frame(height: LensNoteTheme.Spacing.dockTotalClearance + 40)
                }
                .allowsHitTesting(false)

                // 권한 거부 시 중앙 안내 오버레이
                if viewModel.permissionState == .denied
                    || viewModel.permissionState == .restricted
                    || viewModel.permissionState == .missingUsageDescription {
                    PermissionOverlayView(
                        state: viewModel.permissionState,
                        onOpenSettings: viewModel.openAppSettings
                    )
                    .transition(.opacity)
                }

                // 빈 상태 오버레이
                if viewModel.pins.isEmpty
                    && !viewModel.isLoading
                    && viewModel.permissionState != .denied
                    && viewModel.permissionState != .restricted
                    && viewModel.permissionState != .missingUsageDescription {
                    MapEmptyStateView(onCameraTabTap: onCameraTabTap)
                        .transition(.opacity)
                }

                // 보이는 핀이 있고 카드가 열려있지 않을 때만 패널 표시
                if !visiblePins.isEmpty && viewModel.selectedPin == nil {
                    if isCompact {
                        VStack { Spacer() ; SidePanelList(pins: visiblePins, selection: $selection) }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.bottom, LensNoteTheme.Spacing.dockTotalClearance)
                    } else {
                        HStack { Spacer() ; SidePanelList(pins: visiblePins, selection: $selection) }
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                            .padding(.trailing, 8)
                    }
                }

                // 핀 선택 시 하단 카드 표시
                if let pin = viewModel.selectedPin {
                    VStack {
                        Spacer()
                        PinCardView(pin: pin) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                viewModel.closeCard()
                            }
                        }
                        .padding(.horizontal, LensNoteTheme.Spacing.sm)
                        .padding(.bottom, LensNoteTheme.Spacing.dockTotalClearance)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
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
    /// 지정 좌표로 지도 카메라를 이동하고 포커스 요청을 소비한다 (Req 2.2).
    private func focusCamera(on coord: GeoCoordinate) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            position = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: coord.latitude, longitude: coord.longitude),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            )
        }
        viewModel.clearFocus()
    }

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

#Preview {
    MapView(viewModel: MapViewModel())
}
