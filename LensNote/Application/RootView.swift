//
//  RootView.swift
//  LensNote
//
//  Created by 박태영 on 1/4/26.
//

import SwiftUI

/// 앱 최상위 탭 컨테이너.
struct RootView: View {
    let cameraVM: CameraViewModel
    @StateObject private var mapVM = MapViewModel()
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(
                onUploadReference: { selectedTab = .camera },
                onOpenCamera: { selectedTab = .camera },
                onOpenMapGallery: { selectedTab = .map }
            )
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(AppTab.home)

            CameraView(viewModel: cameraVM)
                .tabItem { Label("Camera", systemImage: "camera") }
                .tag(AppTab.camera)

            MapView(viewModel: mapVM)
                .tabItem { Label("Map Gallery", systemImage: "map") }
                .tag(AppTab.map)
        }
        .onAppear {
            Task {
                // 앱 진입 직후 지도를 빠르게 표시하기 위해 초기 핀 로드를 선실행.
                try? await Task.sleep(nanoseconds: 300_000_000)
                await mapVM.loadPhotoPinsIfNeeded()
            }
        }
        .tint(LensNoteTheme.Colors.primary)
    }
}
