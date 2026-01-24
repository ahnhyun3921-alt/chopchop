//
//  KakaoLocalService.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//

import Foundation
import CoreLocation

class KakaoLocalService {
    static let shared = KakaoLocalService()

    private let apiKey = Config.kakaoRestAPIKey
    private let baseURL = "https://dapi.kakao.com/v2/local/search"

    private init() {}

    /// 카카오 로컬 API로 키워드 검색
    /// - Parameters:
    ///   - query: 검색어 (예: "맛집", "이탈리안 레스토랑")
    ///   - location: 중심 좌표 (선택사항)
    ///   - radius: 검색 반경 (미터, 최대 20000)
    ///   - page: 페이지 번호 (1~45)
    ///   - size: 한 페이지에 보여질 문서 개수 (1~15)
    func searchKeyword(
        query: String,
        location: CLLocationCoordinate2D? = nil,
        radius: Int = 1000,
        page: Int = 1,
        size: Int = 15
    ) async throws -> KakaoSearchResponse {
        var components = URLComponents(string: "\(baseURL)/keyword.json")!

        var queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "size", value: "\(size)"),
            URLQueryItem(name: "category_group_code", value: "FD6") // 음식점 카테고리
        ]

        if let location = location {
            queryItems.append(URLQueryItem(name: "x", value: "\(location.longitude)"))
            queryItems.append(URLQueryItem(name: "y", value: "\(location.latitude)"))
            queryItems.append(URLQueryItem(name: "radius", value: "\(radius)"))
            queryItems.append(URLQueryItem(name: "sort", value: "distance")) // 거리순 정렬
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw KakaoLocalError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("KakaoAK \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw KakaoLocalError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw KakaoLocalError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let searchResponse = try decoder.decode(KakaoSearchResponse.self, from: data)

        return searchResponse
    }

    /// 카테고리로 검색
    func searchByCategory(
        categoryCode: String = "FD6", // FD6: 음식점
        location: CLLocationCoordinate2D,
        radius: Int = 1000,
        page: Int = 1,
        size: Int = 15
    ) async throws -> KakaoSearchResponse {
        var components = URLComponents(string: "\(baseURL)/category.json")!

        let queryItems = [
            URLQueryItem(name: "category_group_code", value: categoryCode),
            URLQueryItem(name: "x", value: "\(location.longitude)"),
            URLQueryItem(name: "y", value: "\(location.latitude)"),
            URLQueryItem(name: "radius", value: "\(radius)"),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "size", value: "\(size)"),
            URLQueryItem(name: "sort", value: "distance")
        ]

        components.queryItems = queryItems

        guard let url = components.url else {
            throw KakaoLocalError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("KakaoAK \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw KakaoLocalError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw KakaoLocalError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let searchResponse = try decoder.decode(KakaoSearchResponse.self, from: data)

        return searchResponse
    }
}

// MARK: - Models

struct KakaoSearchResponse: Codable {
    let meta: KakaoMeta
    let documents: [KakaoPlace]
}

struct KakaoMeta: Codable {
    let totalCount: Int
    let pageableCount: Int
    let isEnd: Bool
}

struct KakaoPlace: Codable, Identifiable {
    let id: String
    let placeName: String
    let categoryName: String
    let categoryGroupCode: String
    let categoryGroupName: String
    let phone: String
    let addressName: String
    let roadAddressName: String
    let x: String  // 경도 (longitude)
    let y: String  // 위도 (latitude)
    let placeUrl: String
    let distance: String

    var coordinate: CLLocationCoordinate2D? {
        guard let longitude = Double(x),
              let latitude = Double(y) else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// 메인 카테고리 추출 (예: "음식점 > 한식 > 육류" → "한식")
    var mainCategory: String {
        let categories = categoryName.split(separator: ">").map { $0.trimmingCharacters(in: .whitespaces) }
        return categories.count >= 2 ? categories[1] : "음식점"
    }

    /// Restaurant 모델로 변환
    func toRestaurant() -> Restaurant {
        return Restaurant(
            id: id,
            name: placeName,
            category: mainCategory,
            rating: 0.0,  // 카카오 API는 평점 제공 안 함
            distance: distance.isEmpty ? "" : "\(distance)m",
            address: roadAddressName.isEmpty ? addressName : roadAddressName,
            operatingStatus: "영업 중",  // TODO: 실제 영업 상태는 별도 API 필요
            operatingHours: [],  // TODO: 영업시간 정보는 Kakao Place Detail API 필요
            totalMenuCount: 0,
            imageUrl: nil  // TODO: 이미지는 별도 API 또는 크롤링 필요
        )
    }
}

enum KakaoLocalError: LocalizedError {
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
