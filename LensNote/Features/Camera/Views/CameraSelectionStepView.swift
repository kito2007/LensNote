//
//  CameraSelectionStepView.swift
//  LensNote
//
//  Created by 박태영 on 3/21/26.
//

import SwiftUI

struct CameraSelectionStepView: View {
    
    let onSelectPhoto: () -> Void
    let onSelectText: () -> Void
    let onSelectManual: () -> Void
    let onSelectCamera: () -> Void
    
    var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 8) {
                    Text("LensNote Camera")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)

                    Text("촬영 전 입력 방식을 선택하고 AI 어시스트를 시작하세요.")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(.white.opacity(0.82))
                }

                VStack(spacing: 12) {
                    modeButton(
                        title: "레퍼런스 사진 분석",
                        subtitle: "사진 톤을 분석해 추천값을 생성",
                        tint: .blue,
                        action: onSelectPhoto
                    )

                    modeButton(
                        title: "텍스트 컨셉 입력",
                        subtitle: "원하는 스타일 키워드로 시작",
                        tint: .cyan,
                        action: onSelectText
                    )

                    modeButton(
                        title: "수동 설정",
                        subtitle: "필터 값을 직접 조정",
                        tint: .mint,
                        action: onSelectManual
                    )

                    modeButton(
                        title: "카메라 바로 시작",
                        subtitle: "기본값으로 즉시 촬영",
                        tint: .white,
                        action: onSelectCamera
                    )
                }
                .padding(.top, 8)

                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.09, green: 0.12, blue: 0.19),
                        Color(red: 0.05, green: 0.35, blue: 0.43)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    
    
    private func modeButton(
            title: String,
            subtitle: String,
            tint: Color,
            action: @escaping () -> Void
        ) -> some View {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))

                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .foregroundStyle(tint == .white ? .black : .white)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(tint == .white ? Color.white : tint.opacity(0.24))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
}
