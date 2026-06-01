//
//  MapRegionFilterTests.swift
//  LensNoteTests
//
//  Req 6.7 — Property 5: 공간(영역) 필터링 정확성.
//

import Testing
import MapKit
@testable import LensNote

struct MapRegionFilterTests {

    /// 랜덤(결정론적) 좌표 + 영역 100회 — contains가 영역 박스 포함 여부와 정확히 일치.
    @Test("Property 5: 영역 포함 판정 정확성")
    func containsCorrectness() {
        for i in 0..<100 {
            // 영역 중심/스팬을 i 기반으로 변화.
            let centerLat = Double((i * 13) % 170) - 85          // -85 ~ 84
            let centerLon = Double((i * 29) % 360) - 180         // -180 ~ 179
            let spanLat = Double((i % 9) + 1) * 0.5              // 0.5 ~ 4.5
            let spanLon = Double((i % 7) + 1) * 0.5
            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
            )

            // 좌표를 중심 부근에서 다양하게 — 안/밖 모두 발생하도록.
            let dLat = Double((i * 7) % 11 - 5) * 0.4            // -2.0 ~ 2.0
            let dLon = Double((i * 5) % 11 - 5) * 0.4
            let coord = CLLocationCoordinate2D(latitude: centerLat + dLat, longitude: centerLon + dLon)

            let result = MapRegionFilter.contains(coord, in: region)
            let expected = abs(dLat) <= spanLat / 2 && abs(dLon) <= spanLon / 2
            #expect(result == expected,
                    "i=\(i) dLat=\(dLat) dLon=\(dLon) span=(\(spanLat),\(spanLon))")
        }
    }

    @Test("경계/중심 포함, 영역 밖 제외")
    func boundaryCases() {
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.5, longitude: 127.0),
            span: MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)
        )
        #expect(MapRegionFilter.contains(.init(latitude: 37.5, longitude: 127.0), in: region))   // 중심
        #expect(MapRegionFilter.contains(.init(latitude: 38.5, longitude: 128.0), in: region))   // 모서리 경계
        #expect(!MapRegionFilter.contains(.init(latitude: 38.6, longitude: 127.0), in: region))  // 위로 벗어남
        #expect(!MapRegionFilter.contains(.init(latitude: 37.5, longitude: 128.1), in: region))  // 옆으로 벗어남
    }
}
