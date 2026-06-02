//
//  MapClusteringHelperTests.swift
//  LensNoteTests
//
//  Req 7 — 추출된 클러스터링/다운샘플 순수 로직 회귀 보호.
//

import Testing
import MapKit
@testable import LensNote

struct MapClusteringHelperTests {

    private func pin(_ lat: Double, _ lon: Double) -> PhotoPin {
        PhotoPin(
            id: UUID(), latitude: lat, longitude: lon, title: "t",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            assetLocalIdentifier: nil, thumbnail: nil, source: .lensNote
        )
    }

    @Test("region nil이면 모두 단일 핀")
    func nilRegionAllSingle() {
        let pins = [pin(37.5, 127.0), pin(37.6, 127.1)]
        let items = MapClusteringHelper.buildClusters(from: pins, in: nil)
        #expect(items.count == 2)
        #expect(items.allSatisfy {
            if case .single = $0.kind { return true } else { return false }
        })
    }

    @Test("가까운 핀은 클러스터, 먼 핀은 단일")
    func nearbyClusterFarSingle() {
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.5, longitude: 127.0),
            span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
        )
        // 거의 같은 좌표 3개(클러스터) + 멀리 떨어진 1개(단일).
        let pins = [pin(37.50, 127.00), pin(37.5001, 127.0001), pin(37.5002, 127.0002),
                    pin(37.95, 127.45)]
        let items = MapClusteringHelper.buildClusters(from: pins, in: region)

        let clusters = items.filter { if case .cluster = $0.kind { return true } else { return false } }
        let singles = items.filter { if case .single = $0.kind { return true } else { return false } }
        #expect(clusters.count == 1)
        #expect(singles.count == 1)
        if case .cluster(_, let grouped) = clusters.first?.kind {
            #expect(grouped.count == 3)
        } else {
            Issue.record("클러스터가 생성되지 않음")
        }
    }

    @Test("250개 이하면 다운샘플 없음")
    func noDownsampleUnderThreshold() {
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
        )
        let pins = (0..<250).map { pin(Double($0) * 0.001, 0) }
        #expect(MapClusteringHelper.downsample(pins, in: region).count == 250)
    }
}
