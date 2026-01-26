//
//  KakaoMapView.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//

import SwiftUI
import MapKit
import CoreLocation

/// 지도를 SwiftUI에서 사용하기 위한 Representable (Apple MapKit 사용)
struct KakaoMapView: UIViewRepresentable {
    @Binding var restaurants: [Restaurant]
    @Binding var selectedRestaurant: Restaurant?
    var currentLocation: CLLocationCoordinate2D?
    @Binding var mapCenter: CLLocationCoordinate2D?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true

        // 초기 위치 설정 (귀인로 258 근처)
        let initialCenter = currentLocation ?? CLLocationCoordinate2D(
            latitude: 37.3925,
            longitude: 126.9514
        )

        let region = MKCoordinateRegion(
            center: initialCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        mapView.setRegion(region, animated: false)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 기존 어노테이션 제거
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })

        // 식당 마커 추가
        var addedAnnotations: [RestaurantAnnotation] = []
        for restaurant in restaurants {
            guard let coordinate = restaurant.coordinate else { continue }

            let annotation = RestaurantAnnotation(
                coordinate: coordinate,
                restaurant: restaurant
            )
            mapView.addAnnotation(annotation)
            addedAnnotations.append(annotation)
        }

        // 선택된 식당이 있으면 해당 위치로 줌인
        if let selected = selectedRestaurant,
           let coordinate = selected.coordinate {
            let region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            )
            mapView.setRegion(region, animated: true)
            context.coordinator.lastMapCenter = coordinate
        }
        // mapCenter가 변경되었고 마커가 있으면 해당 위치로 이동하되, 모든 마커를 볼 수 있도록 범위 조정
        else if let center = mapCenter,
                !addedAnnotations.isEmpty,
                context.coordinator.lastMapCenter != center {
            // 모든 마커를 포함하는 영역 계산
            var minLat = center.latitude
            var maxLat = center.latitude
            var minLon = center.longitude
            var maxLon = center.longitude

            for annotation in addedAnnotations {
                let coord = annotation.coordinate
                minLat = min(minLat, coord.latitude)
                maxLat = max(maxLat, coord.latitude)
                minLon = min(minLon, coord.longitude)
                maxLon = max(maxLon, coord.longitude)
            }

            // 여유 공간 추가 (20%)
            let latDelta = (maxLat - minLat) * 1.4
            let lonDelta = (maxLon - minLon) * 1.4

            let newCenter = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )

            let region = MKCoordinateRegion(
                center: newCenter,
                span: MKCoordinateSpan(
                    latitudeDelta: max(latDelta, 0.01),  // 최소 범위 설정
                    longitudeDelta: max(lonDelta, 0.01)
                )
            )
            mapView.setRegion(region, animated: true)
            context.coordinator.lastMapCenter = center
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: KakaoMapView
        var lastMapCenter: CLLocationCoordinate2D?

        init(_ parent: KakaoMapView) {
            self.parent = parent
        }

        // 커스텀 핀 뷰
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation is RestaurantAnnotation else {
                return nil
            }

            let identifier = "RestaurantPin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }

            // 핀 색상 (SafeEat 프라이머리 컬러)
            annotationView?.markerTintColor = UIColor(red: 0.977, green: 0.427, blue: 0.355, alpha: 1.0)
            annotationView?.glyphImage = UIImage(systemName: "fork.knife")

            return annotationView
        }

        // 핀 선택 시
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let annotation = view.annotation as? RestaurantAnnotation else {
                return
            }
            parent.selectedRestaurant = annotation.restaurant
        }
    }
}

// MARK: - Restaurant Annotation

class RestaurantAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let restaurant: Restaurant

    var title: String? {
        restaurant.name
    }

    var subtitle: String? {
        restaurant.category
    }

    init(coordinate: CLLocationCoordinate2D, restaurant: Restaurant) {
        self.coordinate = coordinate
        self.restaurant = restaurant
        super.init()
    }
}
