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
}
