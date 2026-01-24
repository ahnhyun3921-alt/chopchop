//
//  KakaoMapView.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//

import SwiftUI
import CoreLocation
// KakaoMapsSDK는 SPM 설치 후 활성화
// import KakaoMapsSDK

/// 카카오 지도를 SwiftUI에서 사용하기 위한 Representable
struct KakaoMapView: UIViewRepresentable {
    @Binding var restaurants: [Restaurant]
    @Binding var selectedRestaurant: Restaurant?
    var currentLocation: CLLocationCoordinate2D?

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .systemBackground

        // TODO: KakaoMapsSDK 설치 후 활성화
        // SPM으로 https://github.com/kakao-mapsSDK/KakaoMapsSDK-SPM 추가 후
        // 아래 코드를 활성화하세요

        /*
        // KMViewContainer 생성
        let container = KMViewContainer(frame: containerView.bounds)
        container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        containerView.addSubview(container)

        // KMController 생성 및 설정
        context.coordinator.mapController = KMController(viewContainer: container)
        context.coordinator.mapController?.delegate = context.coordinator
        context.coordinator.mapController?.initEngine()

        // 현재 위치로 카메라 이동
        if let location = currentLocation {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let mapView = context.coordinator.mapController?.getView("mapview") as? KakaoMap {
                    let cameraUpdate = CameraUpdate.make(
                        target: MapPoint(longitude: location.longitude, latitude: location.latitude),
                        zoomLevel: 15,
                        mapView: mapView
                    )
                    mapView.moveCamera(cameraUpdate)
                }
            }
        }
        */

        // 임시: SDK 설치 전 안내 메시지
        let label = UILabel(frame: containerView.bounds)
        label.text = "카카오 지도\n\n1. Xcode에서 Package Dependencies에\n   https://github.com/kakao-mapsSDK/KakaoMapsSDK-SPM 추가\n2. KakaoMapView.swift의 주석 해제"
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        containerView.addSubview(label)

        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // TODO: KakaoMapsSDK 설치 후 활성화

        /*
        guard let mapView = context.coordinator.mapController?.getView("mapview") as? KakaoMap else {
            return
        }

        // 기존 POI 제거
        context.coordinator.removePois()

        // 식당 마커 추가
        if let labelManager = mapView.getLabelManager() {
            let layer = labelManager.addLabelLayer(option: LabelLayerOptions(
                layerID: "restaurants",
                competitionType: .none,
                competitionUnit: .symbolFirst,
                orderType: .rank,
                zOrder: 0
            ))

            for restaurant in restaurants {
                guard let location = restaurant.coordinate else { continue }

                let position = MapPoint(longitude: location.longitude, latitude: location.latitude)

                // POI 스타일 생성
                let poiStyle = PoiStyle(styleID: "restaurant_poi")
                poiStyle.iconStyle = PoiIconStyle(
                    symbol: UIImage(systemName: "fork.knife.circle.fill"),
                    anchorPoint: CGPoint(x: 0.5, y: 1.0)
                )

                // POI 옵션 생성
                let poiOption = PoiOptions(
                    styleID: "restaurant_poi",
                    poiID: restaurant.id
                )
                poiOption.rank = 0
                poiOption.clickable = true

                // POI 생성 및 추가
                let poi = layer?.addPoi(option: poiOption, at: position, callback: { poi in
                    // POI 클릭 이벤트
                    context.coordinator.handlePoiTap(poiId: restaurant.id)
                })

                context.coordinator.pois.append(poi)
            }
        }

        // 선택된 식당이 있으면 카메라 이동
        if let selected = selectedRestaurant,
           let location = selected.coordinate {
            let cameraUpdate = CameraUpdate.make(
                target: MapPoint(longitude: location.longitude, latitude: location.latitude),
                zoomLevel: 16,
                mapView: mapView,
                animation: CameraAnimation(type: .easeIn, duration: 0.3)
            )
            mapView.moveCamera(cameraUpdate)
        }
        */
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: KakaoMapView
        var mapController: Any? // KMController 타입 (SDK 설치 후 활성화)
        var pois: [Any] = [] // Poi 배열 (SDK 설치 후 활성화)

        init(_ parent: KakaoMapView) {
            self.parent = parent
        }

        func removePois() {
            // TODO: KakaoMapsSDK 설치 후 POI 제거 로직 구현
            pois.removeAll()
        }

        func handlePoiTap(poiId: String) {
            // 선택된 식당 업데이트
            if let restaurant = parent.restaurants.first(where: { $0.id == poiId }) {
                parent.selectedRestaurant = restaurant
            }
        }
    }
}

// MARK: - MapControllerDelegate (SDK 설치 후 활성화)
/*
extension KakaoMapView.Coordinator: MapControllerDelegate {
    func addViews() {
        // 맵뷰 생성
        let defaultPosition = MapPoint(
            longitude: parent.currentLocation?.longitude ?? 127.0587,
            latitude: parent.currentLocation?.latitude ?? 37.5836
        )

        let mapviewInfo = MapviewInfo(
            viewName: "mapview",
            viewInfoName: "map",
            defaultPosition: defaultPosition,
            defaultLevel: 15
        )

        if let mapController = mapController as? KMController,
           mapController.addView(mapviewInfo) {
            print("카카오 맵뷰 생성 성공")
        }
    }

    func containerDidResized(_ size: CGSize) {
        // 컨테이너 크기 변경 시 처리
    }

    func authentication(didSucceed: Bool) {
        if didSucceed {
            print("카카오 지도 인증 성공")
            // 맵뷰 추가
            addViews()
        } else {
            print("카카오 지도 인증 실패")
        }
    }
}
*/
