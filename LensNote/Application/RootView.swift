//
//  RootView.swift
//  LensNote
//
//  Created by 박태영 on 1/4/26.
//

import SwiftUI

/// 앱 최상위 탭 컨테이너.
/// 홈을 허브로 두고 Camera / Map Gallery로 이동하는 3탭 구조를 사용한다.
struct RootView: View {
    private enum AppTab: Hashable {
        case home
        case camera
        case map
    }

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
