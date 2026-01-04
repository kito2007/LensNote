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

    var body: some View {
        TabView {
            CameraView(viewModel: cameraVM)
                .tabItem { Label("Camera", systemImage: "camera") }

            GalleryView(viewModel: galleryVM)
                .tabItem { Label("Gallery", systemImage: "photo.on.rectangle") }
        }
    }
}
