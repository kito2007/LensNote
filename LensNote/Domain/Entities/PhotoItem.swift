//
//  PhotoItem.swift
//  LensNote
//
//  Created by 박태영 on 12/23/25.
//

import Foundation
import CoreLocation

struct GeoCoordinate: Codable, Equatable, Hashable {
    let latitude: Double
    let longitude: Double
}

struct PhotoItem: Codable, Equatable, Identifiable {
    let id: UUID
    let createdAt: Date
    let imagePath: String
    let coordinate: GeoCoordinate?

}
