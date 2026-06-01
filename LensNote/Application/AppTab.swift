//
//  AppTab.swift
//  LensNote
//

import Foundation

enum AppTab: Hashable, CaseIterable {
    case home
    case camera
    case map
    case profile

    var title: String {
        switch self {
        case .home:    return "Home"
        case .camera:  return "Camera"
        case .map:     return "Map"
        case .profile: return "Profile"
        }
    }

    var systemImage: String {
        switch self {
        case .home:    return "house.fill"
        case .camera:  return "camera.fill"
        case .map:     return "map.fill"
        case .profile: return "person.fill"
        }
    }

    /// UI 자동화용 안정 식별자 키 (Req 4). dock 탭: "dock.tab.\(key)".
    var identifierKey: String {
        switch self {
        case .home:    return "home"
        case .camera:  return "camera"
        case .map:     return "map"
        case .profile: return "profile"
        }
    }
}
