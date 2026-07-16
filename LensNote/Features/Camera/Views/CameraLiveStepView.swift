//
//  CameraLiveStepView.swift
//  LensNote
//
//  Created by 박태영 on 3/28/26.
//
//  미니멀 재현 UI — "레퍼런스와 같은 톤·구도로 찍기"에 직접 기여하는 요소만 남긴다.
//  남긴 것: 라이브 프리뷰(레퍼런스 톤 적용) · 🏠홈 · 레퍼런스(썸네일/교체) · 코칭 한 줄 · 셔터.
//  제거: AI 분석 칩, 그리드, 정렬 원/프레이밍 박스 오버레이, 매직 버튼, 사이드 버튼, 컨셉/수동.
//

import SwiftUI
import AVFoundation
import MetalKit

struct CameraLiveStepView: View {
    /// 라이브 프리뷰(MTKView)를 구동하는 렌더러. 활성 프리셋의 색보정을 실시간 적용한다(Path B).
    let previewRenderer: CameraPreviewRenderer
    let cameraStatusMessage: String?
    let isCapturingPhoto: Bool
    /// 화면에 실제로 노출할 구도 힌트 문구. nil이면 온보딩 힌트/없음으로 처리.
    var activeGuidanceHint: String? = nil
    /// 사용자가 고른 레퍼런스 이미지. nil이면 "레퍼런스 고르기" 상태.
    var referenceImage: UIImage? = nil

    /// 카메라 탭을 벗어나 홈으로 복귀(풀스크린 라이브 뷰에는 dock이 없으므로 별도 복귀 경로).
    let onExit: () -> Void
    let onCapture: () -> Void
    /// 레퍼런스 선택/교체 시트를 연다(이 앱의 출발점).
    var onTapReference: () -> Void = {}

    var body: some View {
        ZStack {
            // MARK: - Camera feed (레퍼런스 톤이 실시간 적용된 프리뷰)
            CameraPreview(renderer: previewRenderer)
                .ignoresSafeArea()

            // MARK: - (예정) 레퍼런스 누끼 고스트 오버레이 자리
            // 레퍼런스 인물 누끼를 반투명으로 여기 얹어 구도를 시각적으로 맞추게 할 예정.
            // 오버레이를 전부 비운 이유가 이 슬롯 하나만 쓰기 위해서다.

            // 하단 컨트롤/텍스트 가독성용 그라데이션
            LinearGradient(
                colors: [
                    Color.black.opacity(0.15),
                    Color.clear,
                    Color.black.opacity(0.45)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // MARK: - Camera status error
            if let cameraStatusMessage {
                cameraStatusBanner(cameraStatusMessage)
            }

            // MARK: - Top bar (홈 복귀만)
            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, LensNoteTheme.Spacing.sm)
                    .padding(.top, LensNoteTheme.Spacing.xxs)
                Spacer()
            }

            // MARK: - Bottom: 힌트 한 줄 + 캡처 바
            VStack(spacing: LensNoteTheme.Spacing.sm) {
                Spacer()
                bottomHint
                bottomCaptureBar
                    .padding(.horizontal, LensNoteTheme.Spacing.xl)
                    .padding(.bottom, LensNoteTheme.Spacing.md)
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.88), value: activeGuidanceHint)
            .animation(.easeInOut(duration: 0.25), value: referenceImage == nil)
        }
    }

    // MARK: - Bottom Hint (코칭 한 줄 또는 온보딩 안내)

    @ViewBuilder
    private var bottomHint: some View {
        if let activeGuidanceHint {
            hintBanner(text: activeGuidanceHint, icon: "sparkles", tappable: false)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: 8)),
                    removal: .opacity
                ))
        } else if referenceImage == nil {
            // 레퍼런스가 이 앱의 출발점 — 없으면 고르도록 안내(탭하면 선택 시트).
            hintBanner(text: "레퍼런스 사진을 고르면 같은 톤·구도로 안내해요", icon: "photo.on.rectangle", tappable: true)
        }
    }

    private func hintBanner(text: String, icon: String, tappable: Bool) -> some View {
        let banner = HStack(spacing: LensNoteTheme.Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(LensNoteTheme.Colors.accentCyan)
            Text(text)
                .font(LensNoteTheme.Typography.bodyStrong)
                .foregroundStyle(LensNoteTheme.Colors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, LensNoteTheme.Spacing.sm)
        .padding(.vertical, LensNoteTheme.Spacing.xs)
        .background(LensNoteTheme.Colors.surface.opacity(0.55))
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule().strokeBorder(LensNoteTheme.Colors.chipBorder, lineWidth: 1)
        )
        .shadow(color: LensNoteTheme.Shadow.elevated, radius: 16, y: 6)
        .padding(.horizontal, LensNoteTheme.Spacing.xl)
        .accessibilityLabel("구도 안내")
        .accessibilityValue(text)
        .accessibilityIdentifier("camera.guidance_banner")

        return Group {
            if tappable {
                Button(action: onTapReference) { banner }.buttonStyle(.plain)
            } else {
                banner
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button(action: onExit) {
                Image(systemName: "house.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(LensNoteTheme.Colors.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(LensNoteTheme.Colors.sideControlBg)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("홈으로")

            Spacer()
        }
    }

    // MARK: - Bottom Capture Bar

    private var bottomCaptureBar: some View {
        HStack(alignment: .center) {
            // 좌: 레퍼런스 (썸네일 또는 고르기 버튼)
            referenceControl

            Spacer()

            // 중앙: 셔터
            shutterButton

            Spacer()

            // 우: 좌측 레퍼런스와 균형을 맞추기 위한 빈 자리(셔터 중앙 정렬).
            Color.clear.frame(width: 64, height: 64)
        }
    }

    private var referenceControl: some View {
        Button(action: onTapReference) {
            ZStack(alignment: .topTrailing) {
                if let referenceImage {
                    Image(uiImage: referenceImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(LensNoteTheme.Colors.primary, lineWidth: 2))

                    Text("REF")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(LensNoteTheme.Colors.textPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(LensNoteTheme.Colors.primary)
                        .clipShape(Capsule())
                        .offset(x: 4, y: -4)
                } else {
                    Circle()
                        .strokeBorder(
                            LensNoteTheme.Colors.primary,
                            style: StrokeStyle(lineWidth: 2, dash: [5, 4])
                        )
                        .frame(width: 64, height: 64)
                        .overlay(
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 22))
                                .foregroundStyle(LensNoteTheme.Colors.primary)
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(referenceImage == nil ? "레퍼런스 고르기" : "레퍼런스 교체")
        .accessibilityIdentifier("camera.select_reference")
    }

    private var shutterButton: some View {
        ZStack {
            Circle()
                .fill(LensNoteTheme.Colors.shutterGlow)
                .frame(width: 96, height: 96)
                .blur(radius: 24)

            Button(action: onCapture) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 4)
                        .frame(width: 80, height: 80)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 68, height: 68)
                }
            }
            .buttonStyle(ShutterButtonStyle())
            .disabled(isCapturingPhoto)
            .opacity(isCapturingPhoto ? 0.6 : 1)
            .accessibilityLabel("촬영")
            .accessibilityIdentifier("camera.shutter")
        }
    }

    // MARK: - Camera Status Banner

    private func cameraStatusBanner(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(LensNoteTheme.Colors.warning)
            Text(message)
                .font(LensNoteTheme.Typography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(LensNoteTheme.Colors.textPrimary)
        }
        .padding(14)
        .background(LensNoteTheme.Colors.surface.opacity(0.75))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: LensNoteTheme.Radius.card, style: .continuous))
        .padding(.horizontal, LensNoteTheme.Spacing.sm)
    }
}

// MARK: - Shutter Button Style

private struct ShutterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Camera Preview (MTKView)

/// MTKView 기반 라이브 프리뷰. captureOutput 프레임에 활성 프리셋 색보정을 실시간 적용한다(Path B).
/// 렌더 로직은 `CameraPreviewRenderer`(MTKViewDelegate)가 담당.
private struct CameraPreview: UIViewRepresentable {
    let renderer: CameraPreviewRenderer

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: renderer.device)
        view.delegate = renderer
        view.framebufferOnly = false          // CIContext가 drawable 텍스처에 렌더하려면 필요.
        view.colorPixelFormat = .bgra8Unorm
        view.preferredFramesPerSecond = 30     // display ↔ capture 분리, R4 목표 fps.
        view.enableSetNeedsDisplay = false
        view.isPaused = false                  // 자체 타이머로 구동, 최신 프레임을 draw에서 소비.
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        view.contentMode = .scaleAspectFill
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {}
}

// MARK: - Previews

#Preview("레퍼런스 없음") {
    CameraLiveStepView(
        previewRenderer: CameraPreviewRenderer(),
        cameraStatusMessage: nil,
        isCapturingPhoto: false,
        activeGuidanceHint: nil,
        referenceImage: nil,
        onExit: {},
        onCapture: {}
    )
}

#Preview("코칭 중") {
    CameraLiveStepView(
        previewRenderer: CameraPreviewRenderer(),
        cameraStatusMessage: nil,
        isCapturingPhoto: false,
        activeGuidanceHint: "조금 더 가까이 가보세요",
        referenceImage: nil,
        onExit: {},
        onCapture: {}
    )
}
