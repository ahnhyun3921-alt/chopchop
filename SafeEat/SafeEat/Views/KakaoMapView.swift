//
//  KakaoMapView.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//

import SwiftUI
import KakaoMapsSDK_SPM
import CoreLocation

/// 카카오 지도를 SwiftUI에서 사용하기 위한 Representable
struct KakaoMapView: UIViewRepresentable {
    @Binding var restaurants: [Restaurant]
    @Binding var selectedRestaurant: Restaurant?
    var currentLocation: CLLocationCoordinate2D?
    @Binding var mapCenter: CLLocationCoordinate2D?

    func makeUIView(context: Context) -> KMViewContainer {
        let container = KMViewContainer()
        container.sizeToFit()
        context.coordinator.createController(container)
        context.coordinator.container = container
        return container
    }

    func updateUIView(_ view: KMViewContainer, context: Context) {
        guard let controller = context.coordinator.controller else { return }

        // 지도가 준비되지 않았으면 대기
        if !context.coordinator.mapReady {
            return
        }

        // 식당 마커 업데이트
        context.coordinator.updateRestaurants(restaurants)

        // 지도 중심 이동
        if let center = mapCenter, context.coordinator.lastMapCenter != center {
            context.coordinator.moveCamera(to: center, withRestaurants: restaurants)
            context.coordinator.lastMapCenter = center
        }

        // 선택된 식당으로 줌인
        if let selected = selectedRestaurant, let coordinate = selected.coordinate {
            context.coordinator.moveCamera(to: coordinate, zoomLevel: 16)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    static func dismantleUIView(_ uiView: KMViewContainer, coordinator: Coordinator) {
        coordinator.controller?.pauseEngine()
        coordinator.controller = nil
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MapControllerDelegate {
        var parent: KakaoMapView
        var container: KMViewContainer?
        var controller: KMController?
        var mapReady = false
        var lastMapCenter: CLLocationCoordinate2D?
        private var poiManager: PoiManager?

        init(parent: KakaoMapView) {
            self.parent = parent
            super.init()
        }

        func createController(_ view: KMViewContainer) {
            let defaultPosition = parent.currentLocation ?? CLLocationCoordinate2D(
                latitude: 37.5836,  // 고려대 근처
                longitude: 127.0587
            )

            // 지도 생성 옵션
            let mapviewInfo = MapviewInfo(
                viewName: "SafeEatMapView",
                viewInfoName: "SafeEatMapViewInfo",
                defaultPosition: MapPoint(longitude: defaultPosition.longitude, latitude: defaultPosition.latitude),
                defaultLevel: 15
            )

            // KMController 생성
            if controller == nil {
                controller = KMController(viewContainer: view)
                controller?.delegate = self
            }

            controller?.initEngine()
        }

        // MARK: - MapControllerDelegate

        func addViews() {
            guard let controller = controller else { return }

            // 기본 MapView 생성
            let defaultPosition = parent.currentLocation ?? CLLocationCoordinate2D(
                latitude: 37.5836,
                longitude: 127.0587
            )

            let mapviewInfo = MapviewInfo(
                viewName: "mapview",
                viewInfoName: "map",
                defaultPosition: MapPoint(longitude: defaultPosition.longitude, latitude: defaultPosition.latitude),
                defaultLevel: 15
            )

            if controller.addView(mapviewInfo) == Result.OK {
                print("✅ 카카오 맵 뷰 추가 성공")
            }
        }

        func viewInit(viewName: String) {
            print("✅ 카카오 맵 초기화 완료: \(viewName)")
            mapReady = true

            // POI Manager 초기화
            if let view = controller?.getView(viewName) as? KakaoMap {
                let manager = view.getLabelManager()
                let layer = manager.addLabelLayer(option: LabelLayerOptions(layerID: "restaurantLayer", competitionType: .none, competitionUnit: .symbolFirst, orderType: .rank, zOrder: 0))
                poiManager = PoiManager(view: view, layerID: "restaurantLayer")

                // 초기 식당 마커 추가
                updateRestaurants(parent.restaurants)
            }
        }

        func containerDidResized(_ size: CGSize) {
            // 컨테이너 크기 변경 시
        }

        func updateRestaurants(_ restaurants: [Restaurant]) {
            guard let view = controller?.getView("mapview") as? KakaoMap else { return }
            guard let manager = poiManager else { return }

            // 기존 POI 제거
            manager.clearPois()

            // 새로운 POI 추가
            for restaurant in restaurants {
                guard let coordinate = restaurant.coordinate else { continue }

                let position = MapPoint(longitude: coordinate.longitude, latitude: coordinate.latitude)

                // POI 스타일
                let poiOption = PoiOptions(styleID: "restaurantStyle")
                poiOption.rank = 0

                let poi = manager.addPoi(
                    option: poiOption,
                    at: position,
                    callback: { [weak self] poi in
                        self?.parent.selectedRestaurant = restaurant
                    }
                )

                // 식당 이름 표시
                if let poi = poi {
                    let textStyle = PoiTextStyle(
                        fontSize: 12,
                        fontColor: UIColor.black,
                        strokeColor: UIColor.white,
                        strokeWidth: 1
                    )
                    poi.addText(
                        PoiText(text: restaurant.name, styleIndex: 0),
                        textStyle: textStyle
                    )
                }
            }
        }

        func moveCamera(to coordinate: CLLocationCoordinate2D, withRestaurants restaurants: [Restaurant] = [], zoomLevel: Int? = nil) {
            guard let view = controller?.getView("mapview") as? KakaoMap else { return }

            if let level = zoomLevel {
                // 특정 좌표로 줌인
                let position = MapPoint(longitude: coordinate.longitude, latitude: coordinate.latitude)
                let cameraUpdate = CameraUpdate.make(
                    target: position,
                    zoomLevel: level,
                    rotation: 0.0,
                    tilt: 0.0,
                    mapView: view
                )
                view.animateCamera(cameraUpdate: cameraUpdate, options: CameraAnimationOptions(autoElevation: false, consecutive: true, durationInMillis: 500))
            } else if !restaurants.isEmpty {
                // 모든 식당을 포함하는 범위로 카메라 이동
                var minLat = coordinate.latitude
                var maxLat = coordinate.latitude
                var minLon = coordinate.longitude
                var maxLon = coordinate.longitude

                for restaurant in restaurants {
                    guard let coord = restaurant.coordinate else { continue }
                    minLat = min(minLat, coord.latitude)
                    maxLat = max(maxLat, coord.latitude)
                    minLon = min(minLon, coord.longitude)
                    maxLon = max(maxLon, coord.longitude)
                }

                let centerLat = (minLat + maxLat) / 2
                let centerLon = (minLon + maxLon) / 2

                let position = MapPoint(longitude: centerLon, latitude: centerLat)
                let cameraUpdate = CameraUpdate.make(
                    target: position,
                    zoomLevel: 14,
                    rotation: 0.0,
                    tilt: 0.0,
                    mapView: view
                )
                view.animateCamera(cameraUpdate: cameraUpdate, options: CameraAnimationOptions(autoElevation: false, consecutive: true, durationInMillis: 500))
            } else {
                // 단순 이동
                let position = MapPoint(longitude: coordinate.longitude, latitude: coordinate.latitude)
                let cameraUpdate = CameraUpdate.make(
                    target: position,
                    zoomLevel: 15,
                    rotation: 0.0,
                    tilt: 0.0,
                    mapView: view
                )
                view.animateCamera(cameraUpdate: cameraUpdate, options: CameraAnimationOptions(autoElevation: false, consecutive: true, durationInMillis: 500))
            }
        }
    }
}

// MARK: - POI Manager Helper

class PoiManager {
    private weak var view: KakaoMap?
    private let layerID: String
    private var pois: [Poi] = []

    init(view: KakaoMap, layerID: String) {
        self.view = view
        self.layerID = layerID
    }

    func addPoi(option: PoiOptions, at position: MapPoint, callback: ((Poi) -> Void)? = nil) -> Poi? {
        guard let view = view else { return nil }
        guard let manager = view.getLabelManager() else { return nil }
        guard let layer = manager.getLabelLayer(layerID: layerID) else { return nil }

        let poi = layer.addPoi(option: option, at: position)
        if let poi = poi {
            pois.append(poi)

            // 클릭 이벤트 (임시로 간단하게 구현)
            // 실제로는 GuiEventDelegate를 사용해야 함
        }
        return poi
    }

    func clearPois() {
        guard let view = view else { return }
        guard let manager = view.getLabelManager() else { return }
        guard let layer = manager.getLabelLayer(layerID: layerID) else { return }

        layer.clearAllItems()
        pois.removeAll()
    }
}
