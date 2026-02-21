//
//  RootView.swift
//  LensNote
//
//  Created by 박태영 on 1/4/26.
//

import SwiftUI

struct RootView: View {
    let cameraVM: CameraViewModel
    let galleryVM: GalleryViewModel
    @StateObject private var mapVM = MapViewModel()

    var body: some View {
        TabView {
            CameraView(viewModel: cameraVM)
                .tabItem { Label("Camera", systemImage: "camera") }

            GalleryView(viewModel: galleryVM)
                .tabItem { Label("Gallery", systemImage: "photo.on.rectangle") }

            MapView(viewModel: mapVM)
                .tabItem { Label("Map", systemImage: "map") }
        }
        .onAppear {
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                await mapVM.loadPhotoPinsIfNeeded()
            }
        }
    }
}
