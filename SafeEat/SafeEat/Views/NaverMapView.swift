//
//  NaverMapView.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//

import SwiftUI
import NMapsMap
import CoreLocation

/// 네이버 지도를 SwiftUI에서 사용하기 위한 Representable
struct NaverMapView: UIViewRepresentable {
    @Binding var restaurants: [Restaurant]
    @Binding var selectedRestaurant: Restaurant?
    var currentLocation: CLLocationCoordinate2D?

    func makeUIView(context: Context) -> NMFNaverMapView {
        let mapView = NMFNaverMapView()

        // 지도 기본 설정
        mapView.mapView.positionMode = .direction
        mapView.mapView.zoomLevel = 15

        // 현재 위치가 있으면 카메라 이동
        if let location = currentLocation {
            let cameraUpdate = NMFCameraUpdate(scrollTo: NMGLatLng(
                lat: location.latitude,
                lng: location.longitude
            ))
            mapView.mapView.moveCamera(cameraUpdate)
        }

        // 현재 위치 버튼 활성화
        mapView.showLocationButton = true

        // 줌 컨트롤 활성화
        mapView.showZoomControls = true

        // 마커 탭 리스너 설정
        mapView.mapView.touchDelegate = context.coordinator

        return mapView
    }

    func updateUIView(_ uiView: NMFNaverMapView, context: Context) {
        // 기존 마커 제거
        context.coordinator.markers.forEach { $0.mapView = nil }
        context.coordinator.markers.removeAll()

        // 식당 마커 추가
        for restaurant in restaurants {
            guard let location = getRestaurantLocation(restaurant) else { continue }

            let marker = NMFMarker()
            marker.position = NMGLatLng(lat: location.latitude, lng: location.longitude)
            marker.captionText = restaurant.name
            marker.iconTintColor = UIColor(Color.safeEatPrimary)
            marker.mapView = uiView.mapView

            // 마커에 식당 정보 저장
            marker.userInfo = ["restaurantId": restaurant.id]

            context.coordinator.markers.append(marker)
        }

        // 선택된 식당이 있으면 카메라 이동
        if let selected = selectedRestaurant,
           let location = getRestaurantLocation(selected) {
            let cameraUpdate = NMFCameraUpdate(scrollTo: NMGLatLng(
                lat: location.latitude,
                lng: location.longitude
            ))
            cameraUpdate.animation = .easeIn
            uiView.mapView.moveCamera(cameraUpdate)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // 식당 위치 정보 가져오기 (임시)
    private func getRestaurantLocation(_ restaurant: Restaurant) -> CLLocationCoordinate2D? {
        // TODO: 실제로는 Geocoding API를 사용하여 주소를 좌표로 변환해야 함
        // 임시로 서울 중심부 근처 랜덤 좌표 사용
        let baseLatitude = 37.5665
        let baseLongitude = 126.9780

        let randomOffset = 0.01
        let latitude = baseLatitude + Double.random(in: -randomOffset...randomOffset)
        let longitude = baseLongitude + Double.random(in: -randomOffset...randomOffset)

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    class Coordinator: NSObject, NMFMapViewTouchDelegate {
        var parent: NaverMapView
        var markers: [NMFMarker] = []

        init(_ parent: NaverMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: NMFMapView, didTapMap latlng: NMGLatLng, point: CGPoint) {
            // 지도 탭 시 선택 해제
            parent.selectedRestaurant = nil
        }

        func mapView(_ mapView: NMFMapView, didTap symbol: NMFSymbol) -> Bool {
            return false
        }
    }
}

// 위치 관리자
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()

    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            print("위치 권한이 거부되었습니다.")
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location.coordinate
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("위치 업데이트 실패: \(error.localizedDescription)")
    }
}
