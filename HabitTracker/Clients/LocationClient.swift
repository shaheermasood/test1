import Foundation
import CoreLocation
import Dependencies

// MARK: - Location Client

public struct LocationClient: Sendable {
    public var requestAuthorization: @Sendable () async throws -> Bool
    public var getCurrentLocation: @Sendable () async throws -> CLLocationCoordinate2D?

    public init(
        requestAuthorization: @escaping @Sendable () async throws -> Bool,
        getCurrentLocation: @escaping @Sendable () async throws -> CLLocationCoordinate2D?
    ) {
        self.requestAuthorization = requestAuthorization
        self.getCurrentLocation = getCurrentLocation
    }
}

// MARK: - Dependency

extension LocationClient: DependencyKey {
    public static let liveValue: LocationClient = {
        let manager = LocationManager()

        return LocationClient(
            requestAuthorization: {
                return await manager.requestAuthorization()
            },
            getCurrentLocation: {
                return await manager.getCurrentLocation()
            }
        )
    }()

    public static let testValue = LocationClient(
        requestAuthorization: { true },
        getCurrentLocation: {
            // San Francisco coordinates for testing
            return CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        }
    )
}

extension DependencyValues {
    public var locationClient: LocationClient {
        get { self[LocationClient.self] }
        set { self[LocationClient.self] = newValue }
    }
}

// MARK: - Location Manager

@MainActor
private class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var authContinuation: CheckedContinuation<Bool, Never>?
    private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D?, Error>?

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in
            self.authContinuation = continuation

            let status = manager.authorizationStatus
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                continuation.resume(returning: true)
                self.authContinuation = nil
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .denied, .restricted:
                continuation.resume(returning: false)
                self.authContinuation = nil
            @unknown default:
                continuation.resume(returning: false)
                self.authContinuation = nil
            }
        }
    }

    func getCurrentLocation() async throws -> CLLocationCoordinate2D? {
        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation

            let status = manager.authorizationStatus
            guard status == .authorizedWhenInUse || status == .authorizedAlways else {
                continuation.resume(returning: nil)
                self.locationContinuation = nil
                return
            }

            manager.requestLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            if let continuation = self.authContinuation {
                switch status {
                case .authorizedWhenInUse, .authorizedAlways:
                    continuation.resume(returning: true)
                case .denied, .restricted:
                    continuation.resume(returning: false)
                case .notDetermined:
                    break // Wait for user decision
                @unknown default:
                    continuation.resume(returning: false)
                }
                self.authContinuation = nil
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            if let continuation = self.locationContinuation {
                let coordinate = locations.first?.coordinate
                continuation.resume(returning: coordinate)
                self.locationContinuation = nil
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            if let continuation = self.locationContinuation {
                continuation.resume(throwing: error)
                self.locationContinuation = nil
            }
        }
    }
}
