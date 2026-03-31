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
    @StateObject private var mapVM = MapViewModel()
    @State private var selectedTab: AppTab = .home

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

                CameraView(viewModel: cameraVM)
                    .tag(AppTab.camera)

                MapView(viewModel: mapVM)
                    .tag(AppTab.map)

                ProfileView()
                    .tag(AppTab.profile)
            }
            .ignoresSafeArea(edges: .bottom)

            // 플로팅 dock 오버레이
            FloatingDockBar(selectedTab: $selectedTab)
                .padding(.horizontal, LensNoteTheme.Spacing.lg)
                .padding(.bottom, LensNoteTheme.Spacing.lg)
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
