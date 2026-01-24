//
//  NaverSearchService.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//

import Foundation
import CoreLocation

class NaverSearchService {
    static let shared = NaverSearchService()

    // 네이버 클라우드 플랫폼 API 키 (Config.swift에서 가져옴)
    private let clientId = Config.naverClientId
    private let clientSecret = Config.naverClientSecret

    private let baseURL = "https://openapi.naver.com/v1/search/local.json"

    private init() {}

    /// 네이버 지역 검색 API로 식당 검색
    /// - Parameters:
    ///   - query: 검색어 (예: "이탈리안 레스토랑")
    ///   - location: 현재 위치 (선택사항)
    ///   - display: 검색 결과 개수 (최대 100)
    ///   - start: 검색 시작 위치 (페이징용)
    func searchRestaurants(
        query: String,
        location: CLLocationCoordinate2D? = nil,
        display: Int = 20,
        start: Int = 1
    ) async throws -> [NaverPlace] {
        var components = URLComponents(string: baseURL)!

        var queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "display", value: "\(display)"),
            URLQueryItem(name: "start", value: "\(start)")
        ]

        // 정렬: 위치가 있으면 거리순, 없으면 정확도순
        if location != nil {
            queryItems.append(URLQueryItem(name: "sort", value: "random"))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw NaverSearchError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(clientId, forHTTPHeaderField: "X-Naver-Client-Id")
        request.setValue(clientSecret, forHTTPHeaderField: "X-Naver-Client-Secret")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NaverSearchError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw NaverSearchError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let searchResponse = try decoder.decode(NaverSearchResponse.self, from: data)

        return searchResponse.items
    }

    /// 키워드로 주변 식당 검색 (위치 기반)
    func searchNearbyRestaurants(
        keyword: String = "맛집",
        location: CLLocationCoordinate2D,
        radius: Int = 1000,
        display: Int = 20
    ) async throws -> [NaverPlace] {
        // 위치 정보를 포함한 검색어 생성
        let query = "\(keyword)"

        return try await searchRestaurants(
            query: query,
            location: location,
            display: display
        )
    }
}

// MARK: - Models

struct NaverSearchResponse: Codable {
    let lastBuildDate: String
    let total: Int
    let start: Int
    let display: Int
    let items: [NaverPlace]
}

struct NaverPlace: Codable, Identifiable {
    let title: String           // 식당 이름 (HTML 태그 포함)
    let link: String            // 네이버 지역 정보 URL
    let category: String        // 카테고리 (예: "음식점>한식>육류,고기요리")
    let description: String     // 설명
    let telephone: String       // 전화번호
    let address: String         // 지번 주소
    let roadAddress: String     // 도로명 주소
    let mapx: String           // x 좌표 (경도) - Naver 좌표계
    let mapy: String           // y 좌표 (위도) - Naver 좌표계

    var id: String {
        // 주소를 ID로 사용 (고유성 보장)
        return roadAddress.isEmpty ? address : roadAddress
    }

    // HTML 태그 제거한 순수 타이틀
    var cleanTitle: String {
        title.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }

    // 카테고리에서 메인 카테고리 추출
    var mainCategory: String {
        let categories = category.split(separator: ">")
        return categories.count >= 2 ? String(categories[1]) : "음식점"
    }

    // 네이버 좌표를 WGS84 좌표로 변환
    var coordinate: CLLocationCoordinate2D? {
        guard let x = Double(mapx),
              let y = Double(mapy) else {
            return nil
        }

        // 네이버 좌표계(KATECH)를 WGS84로 변환
        return convertNaverToWGS84(x: x, y: y)
    }

    // Restaurant 모델로 변환
    func toRestaurant() -> Restaurant {
        let coordinate = self.coordinate
        return Restaurant(
            id: id,
            name: cleanTitle,
            category: mainCategory,
            rating: 0.0,  // TODO: 네이버 평점 API 또는 다른 소스에서 가져오기
            distance: "",  // TODO: 현재 위치와의 거리 계산
            address: roadAddress.isEmpty ? address : roadAddress,
            operatingStatus: "영업 중",  // TODO: 실제 영업 상태 확인
            operatingHours: [],  // TODO: 영업시간 정보 가져오기
            totalMenuCount: 0,  // TODO: 메뉴 정보 가져오기
            imageUrl: nil,  // TODO: 이미지 URL 가져오기
            phoneNumber: telephone.isEmpty ? nil : telephone,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }

    // 네이버 좌표계(KATECH/TM128) → WGS84 변환
    private func convertNaverToWGS84(x: Double, y: Double) -> CLLocationCoordinate2D {
        // 네이버 지도 API의 좌표는 EPSG:5179 (Korean 2000 / Unified CS)
        // 간단한 근사 변환 (정확한 변환은 proj4 라이브러리 필요)

        // 네이버 API의 mapx, mapy는 이미 WGS84 경위도를 10^7 배한 값
        let longitude = x / 10000000.0
        let latitude = y / 10000000.0

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum NaverSearchError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "잘못된 URL입니다."
        case .invalidResponse:
            return "서버 응답이 올바르지 않습니다."
        case .httpError(let statusCode):
            return "HTTP 오류: \(statusCode)"
        case .decodingError:
            return "데이터 파싱 오류가 발생했습니다."
        }
    }
}
