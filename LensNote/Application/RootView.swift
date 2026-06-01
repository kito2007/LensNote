//
//  RootView.swift
//  LensNote
//
//  Created by 박태영 on 1/4/26.
//

import SwiftUI

/// 앱 최상위 컨테이너.
/// TabView는 콘텐츠 전환만 담당하고, FloatingDockBar가 탭 내비게이션을 처리한다.
struct RootView: View {
    let cameraVM: CameraViewModel
    let container: DIContainer
    @StateObject private var mapVM: MapViewModel
    @State private var selectedTab: AppTab = .home

    init(cameraVM: CameraViewModel, container: DIContainer) {
        self.cameraVM = cameraVM
        self.container = container
        _mapVM = StateObject(wrappedValue: container.makeMapViewModel())
    }

    /// dock을 숨겨야 하면 true.
    /// - Req 12: 카메라 탭은 풀스크린 라이브 뷰라 항상 dock을 숨긴다(복귀는 라이브 뷰의 홈 버튼).
    /// - 다른 탭(Home/Map/Profile)이 활성일 때는 항상 false(dock 표시).
    private var shouldHideDock: Bool {
        selectedTab == .camera
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // 콘텐츠 — dock 뒤까지 확장
            TabView(selection: $selectedTab) {
                HomeView(
                    onUploadReference: { selectedTab = .camera },
                    onOpenCamera:      { selectedTab = .camera },
                    onOpenMapGallery:  { selectedTab = .map }
                )
                .tag(AppTab.home)

                CameraView(
                    viewModel: cameraVM,
                    onExit: { selectedTab = .home },
                    onNavigateToMap: { photoID in
                        // Req 2.2 — 결과 카드 "지도에서 보기": 지도 탭으로 이동 + 해당 핀 선택.
                        mapVM.requestSelection(id: photoID)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = .map
                        }
                    },
                    onOpenMap: {
                        // Req 3.1 — 라이브 뷰 사이드 지도 버튼: 지도 탭으로 전환(핀 선택 없음).
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = .map
                        }
                    }
                )
                    .tag(AppTab.camera)

                MapView(viewModel: mapVM, onCameraTabTap: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = .camera
                    }
                })
                    .tag(AppTab.map)

                ProfileView()
                    .tag(AppTab.profile)
            }
            .ignoresSafeArea(edges: .bottom)
            // FloatingDockBar는 ZStack overlay로 그려지므로 system safe area에 반영되지 않는다.
            // dock이 보이는 상태에서는 dockTotalClearance 만큼 하단 inset을 추가해
            // 자식 뷰의 CTA 등이 dock 뒤에 가려지지 않도록 한다.
            // 카메라 탭에서 selection 이외의 sub-step(cameraHidesDock = true)이거나
            // 다른 탭이 아닌 상태에서도 hideDock이 true면 inset 제거.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !shouldHideDock {
                    Color.clear
                        .frame(height: LensNoteTheme.Spacing.dockTotalClearance)
                }
            }

            // 플로팅 dock 오버레이 — dock 숨김 조건과 동기화
            if !shouldHideDock {
                FloatingDockBar(selectedTab: $selectedTab)
                    .padding(.horizontal, LensNoteTheme.Spacing.lg)
                    .padding(.bottom, LensNoteTheme.Spacing.lg)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            Task {
                // 앱 진입 직후 지도를 빠르게 표시하기 위해 초기 핀 로드를 선실행.
                try? await Task.sleep(nanoseconds: 300_000_000)
                await mapVM.loadPhotoPinsIfNeeded()
            }
        }
    }
}
