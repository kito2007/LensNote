//
//  StyleProfileServiceProtocol.swift
//  LensNote
//
//  Created by 박태영 on 12/23/25.
//

import Foundation

/// 이미지에서 스타일 프로필을 추론하는 서비스 추상화.
/// 현재는 프로토콜만 두고, 구현은 추후 CoreML/서버 방식으로 분기할 수 있다.
public protocol StyleProfileServiceProtocol: Sendable {
    func generateStyleProfile(from imageData: Data) async throws -> StyleProfile
}
