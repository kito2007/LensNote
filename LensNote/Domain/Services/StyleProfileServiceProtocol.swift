//
//  StyleProfileServiceProtocol.swift
//  LensNote
//
//  Created by 박태영 on 12/23/25.
//

import Foundation

public protocol StyleProfileServiceProtocol: Sendable {
    func generateStyleProfile(from imageData: Data) async throws -> StyleProfile
}
