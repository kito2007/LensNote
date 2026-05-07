//
//  GeocodingService.swift
//  LensNote
//

import CoreLocation

/// 좌표 → 지명 역지오코딩, 캐시, 큐 관리를 담당하는 서비스.
/// pins 배열은 직접 건드리지 않고 onUpdate 콜백으로 결과를 전달한다.
@MainActor
final class GeocodingService {

    // MARK: - Private state

    private let geocoder = CLGeocoder()
    private var geocodeCache: [String: String] = [:]
    private var geocodeQueue: [PhotoPin] = []
    private var geocodeQueueKeys: Set<String> = []
    private var geocodeTask: Task<Void, Never>?
    private let geocodeCacheKey = "MapViewModel.GeocodeCache.v1"

    // MARK: - Init

    init() {
        loadGeocodeCache()
    }

    // MARK: - Public API

    /// 화면에 보이는 핀들의 지명을 확인하고, 캐시 미스 시 역지오코딩 큐에 등록한다.
    /// 결과가 준비되면 `onUpdate(pinID, placeName)` 을 Main Actor 위에서 호출한다.
    func updatePlaceNamesIfNeeded(
        for visiblePins: [PhotoPin],
        onUpdate: @escaping (UUID, String) -> Void
    ) {
        guard !visiblePins.isEmpty else { return }

        for pin in visiblePins {
            let key = geocodeKey(for: pin.coordinate)
            if let cached = geocodeCache[key] {
                onUpdate(pin.id, cached)
                continue
            }
            if geocodeQueueKeys.contains(key) { continue }

            geocodeQueueKeys.insert(key)
            geocodeQueue.append(pin)
        }

        startGeocodeQueueIfNeeded(onUpdate: onUpdate)
    }

    // MARK: - Queue management

    private func startGeocodeQueueIfNeeded(onUpdate: @escaping (UUID, String) -> Void) {
        guard geocodeTask == nil else { return }
        geocodeTask = Task { [weak self] in
            guard let self else { return }
            await self.runGeocodeQueue(onUpdate: onUpdate)
        }
    }

    private func runGeocodeQueue(onUpdate: @escaping (UUID, String) -> Void) async {
        while !Task.isCancelled, !geocodeQueue.isEmpty {
            let pin = geocodeQueue.removeFirst()
            let key = geocodeKey(for: pin.coordinate)
            let location = CLLocation(latitude: pin.latitude, longitude: pin.longitude)

            if let place = await reverseGeocode(location: location) {
                geocodeCache[key] = place
                onUpdate(pin.id, place)
                saveGeocodeCache()
            }
            geocodeQueueKeys.remove(key)
        }

        geocodeTask = nil
    }

    // MARK: - Geocoding helpers

    private func reverseGeocode(location: CLLocation) async -> String? {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }

            if let name = placemark.name { return name }
            if let locality = placemark.locality { return locality }
            if let administrativeArea = placemark.administrativeArea { return administrativeArea }
            return placemark.country
        } catch {
            return nil
        }
    }

    /// 좌표를 0.001도 단위로 라운딩한 캐시 키 (근처 좌표는 동일 키로 취급)
    private func geocodeKey(for coordinate: CLLocationCoordinate2D) -> String {
        let lat = (coordinate.latitude  * 1000).rounded() / 1000
        let lon = (coordinate.longitude * 1000).rounded() / 1000
        return "\(lat)_\(lon)"
    }

    // MARK: - Cache persistence

    private func loadGeocodeCache() {
        guard let data = UserDefaults.standard.data(forKey: geocodeCacheKey) else { return }
        if let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            geocodeCache = decoded
        }
    }

    private func saveGeocodeCache() {
        guard let data = try? JSONEncoder().encode(geocodeCache) else { return }
        UserDefaults.standard.set(data, forKey: geocodeCacheKey)
    }
}
