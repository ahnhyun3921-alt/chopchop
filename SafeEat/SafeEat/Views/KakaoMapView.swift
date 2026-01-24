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

        // 초기 위치 설정 (고려대 근처)
        let initialCenter = currentLocation ?? CLLocationCoordinate2D(
            latitude: 37.5836,
            longitude: 127.0587
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
        for restaurant in restaurants {
            guard let coordinate = restaurant.coordinate else { continue }

            let annotation = RestaurantAnnotation(
                coordinate: coordinate,
                restaurant: restaurant
            )
            mapView.addAnnotation(annotation)
        }

        // mapCenter가 변경되면 지도 이동
        if let center = mapCenter {
            let region = MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            mapView.setRegion(region, animated: true)
        }

        // 선택된 식당이 있으면 해당 위치로 이동
        if let selected = selectedRestaurant,
           let coordinate = selected.coordinate {
            let region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            )
            mapView.setRegion(region, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: KakaoMapView

        init(_ parent: KakaoMapView) {
            self.parent = parent
        }

        // 커스텀 핀 뷰
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let restaurantAnnotation = annotation as? RestaurantAnnotation else {
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
