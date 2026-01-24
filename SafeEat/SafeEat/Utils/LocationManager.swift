//
//  LocationManager.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//

import Foundation
import CoreLocation
import Combine

// CLLocationCoordinate2D를 Equatable로 확장
extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()

    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 50 // 50미터마다 업데이트

        // 즉시 권한 요청
        let authStatus = locationManager.authorizationStatus
        print("📍 초기 위치 권한 상태: \(authStatus.rawValue)")

        if authStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }

    func requestLocation() {
        print("📍 위치 요청 시작")
        let authStatus = locationManager.authorizationStatus

        if authStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        } else {
            print("⚠️ 위치 권한이 거부됨: \(authStatus.rawValue)")
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            print("⚠️ 위치 업데이트 실패: 위치 정보 없음")
            return
        }

        print("✅ 위치 업데이트 성공: \(location.coordinate.latitude), \(location.coordinate.longitude)")

        DispatchQueue.main.async {
            self.currentLocation = location.coordinate
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ 위치 정보 가져오기 실패: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        print("📍 권한 상태 변경: \(manager.authorizationStatus.rawValue)")

        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus

            if manager.authorizationStatus == .authorizedWhenInUse ||
               manager.authorizationStatus == .authorizedAlways {
                print("✅ 위치 권한 승인됨, 위치 업데이트 시작")
                manager.startUpdatingLocation()
            } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
                print("⚠️ 위치 권한 거부됨 또는 제한됨")
            }
        }
    }
}
