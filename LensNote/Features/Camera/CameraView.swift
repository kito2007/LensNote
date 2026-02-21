//
//  CameraViewModel.swift
//  LensNote
//
//  Created by 박태영 on 12/29/25.
//

import SwiftUI
import AVFoundation

struct CameraView: View {

    @StateObject private var viewModel: CameraViewModel

    init(viewModel: CameraViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            CameraPreview(session: viewModel.session)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                conceptPanel
                Spacer()
                guidancePanel
                bottomPanel
            }
            .padding(16)
        }
        .task {
            await viewModel.startSessionIfNeeded()
        }
        .onDisappear {
            viewModel.stopSession()
        }
        .alert("카메라 권한 필요", isPresented: .constant(viewModel.isCameraAuthorized == false)) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("설정에서 카메라 접근을 허용해주세요.")
        }
    }

    private var conceptPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("원하는 컨셉을 입력하세요", text: $viewModel.conceptText)
                    .textFieldStyle(.roundedBorder)

                Button("적용") {
                    viewModel.applyConcept()
                }
                .buttonStyle(.borderedProminent)
            }

            if let preset = viewModel.preset {
                PresetSummaryView(preset: preset)
            } else {
                Text("컨셉을 입력하면 필터 프리셋이 적용돼요.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var guidancePanel: some View {
        Text(viewModel.guidanceMessage)
            .font(.headline)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(.thinMaterial)
            .clipShape(Capsule())
    }

    private var bottomPanel: some View {
        VStack(spacing: 8) {
            Button("Mock Capture & Save") {
                viewModel.mockCaptureAndSave()
            }
            .buttonStyle(.bordered)

            if let saved = viewModel.lastSaved {
                Text("Saved: \(saved.id.uuidString)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let err = viewModel.errorMessage {
                Text("Error: \(err)")
                    .foregroundStyle(.red)
                    .font(.footnote)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

private struct PresetSummaryView: View {
    let preset: FilterPreset

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Preset: \(preset.name)")
                .font(.subheadline)
                .bold()
            Text("Exposure \(preset.exposure), Contrast \(preset.contrast), Saturation \(preset.saturation)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Temperature \(preset.temperature), Vignette \(preset.vignette)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

