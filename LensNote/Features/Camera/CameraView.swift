//
//  CameraViewModel.swift
//  LensNote
//
//  Created by 박태영 on 12/29/25.
//

import SwiftUI

struct CameraView: View {

    @StateObject private var viewModel: CameraViewModel

    init(viewModel: CameraViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Camera (MVP)")
                .font(.title)

            Button("Mock Capture & Save") {
                viewModel.mockCaptureAndSave()
            }

            if let saved = viewModel.lastSaved {
                Text("Saved: \(saved.id.uuidString)")
                    .font(.footnote)
            }

            if let err = viewModel.errorMessage {
                Text("Error: \(err)")
                    .foregroundStyle(.red)
                    .font(.footnote)
            }
        }
        .padding()
    }
}

