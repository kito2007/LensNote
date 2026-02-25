//
//  RootView.swift
//  LensNote
//
//  Created by 박태영 on 1/4/26.
//

import SwiftUI

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
                try? await Task.sleep(nanoseconds: 300_000_000)
                await mapVM.loadPhotoPinsIfNeeded()
            }
        }
    }
}
