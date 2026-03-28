//
//  RootView.swift
//  LensNote
//
//  Created by 박태영 on 1/4/26.
//

import SwiftUI

/// 앱 최상위 탭 컨테이너.
/// 현재 정보 구조는 Camera + Map Gallery 2개 탭으로 고정한다.
struct RootView: View {
    let cameraVM: CameraViewModel
    @StateObject private var mapVM = MapViewModel()

    var body: some View {
        TabView {
            CameraView(viewModel: cameraVM)
                .tabItem { Label("Camera", systemImage: "camera") }

            MapView(viewModel: mapVM)
                .tabItem { Label("Map Gallery", systemImage: "map") }
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
