//
//  GoogleSearchService.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//

import Foundation
import UIKit

class GoogleSearchService {
    static let shared = GoogleSearchService()

    // TODO: Google Cloud Console에서 발급받은 API 키와 CX(Custom Search Engine ID) 입력
    // https://developers.google.com/custom-search/v1/overview
    private let apiKey = "YOUR_GOOGLE_API_KEY"  // Google Cloud Console에서 발급
    private let cx = "YOUR_CUSTOM_SEARCH_ENGINE_ID"  // Programmable Search Engine에서 생성

    private init() {}

    /// 구글 이미지 검색으로 메뉴판 이미지 URL 찾기
    func searchMenuImages(restaurantName: String, location: String = "평촌") async throws -> [String] {
        // 검색 쿼리: "식당명 메뉴판 평촌"
        let query = "\(restaurantName) 메뉴판 \(location)"
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        // Google Custom Search API 엔드포인트
        let urlString = "https://www.googleapis.com/customsearch/v1?key=\(apiKey)&cx=\(cx)&q=\(encodedQuery)&searchType=image&num=5"

        guard let url = URL(string: urlString) else {
            throw GoogleSearchError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleSearchError.invalidResponse
        }

        // API 할당량 초과 체크
        if httpResponse.statusCode == 429 {
            throw GoogleSearchError.quotaExceeded
        }

        guard httpResponse.statusCode == 200 else {
            throw GoogleSearchError.httpError(httpResponse.statusCode)
        }

        let searchResult = try JSONDecoder().decode(GoogleSearchResponse.self, from: data)

        // 이미지 URL 추출
        let imageUrls = searchResult.items?.compactMap { $0.link } ?? []
        return imageUrls
    }

    /// URL에서 이미지 다운로드
    func downloadImage(from urlString: String) async throws -> UIImage {
        guard let url = URL(string: urlString) else {
            throw GoogleSearchError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        guard let image = UIImage(data: data) else {
            throw GoogleSearchError.imageLoadFailed
        }

        return image
    }

    /// 식당의 메뉴판 이미지를 찾아서 OCR로 메뉴 추출 (완전 자동화)
    func autoExtractMenus(from restaurant: Restaurant) async throws -> [Menu] {
        // 1. 구글 이미지 검색으로 메뉴판 이미지 URL 찾기
        let imageUrls = try await searchMenuImages(restaurantName: restaurant.name)

        guard !imageUrls.isEmpty else {
            throw GoogleSearchError.noResults
        }

        var allMenus: [Menu] = []

        // 2. 각 이미지를 다운로드하고 OCR 처리 (최대 3개까지)
        for (index, imageUrl) in imageUrls.prefix(3).enumerated() {
            do {
                // 이미지 다운로드
                let image = try await downloadImage(from: imageUrl)

                // OCR로 텍스트 추출
                let text = try await OCRService.shared.extractText(from: image)

                // 메뉴 파싱
                let menus = OCRService.shared.parseMenus(from: text, restaurantId: restaurant.id)

                print("[\(index + 1)/\(imageUrls.count)] \(restaurant.name) - 메뉴 \(menus.count)개 추출")

                allMenus.append(contentsOf: menus)

                // 이미지는 즉시 메모리에서 제거 (저작권 보호)
                // Swift의 ARC가 자동으로 처리하지만 명시적으로 표시
            } catch {
                print("이미지 처리 실패: \(imageUrl) - \(error.localizedDescription)")
                continue
            }
        }

        // 3. 중복 제거 (같은 메뉴명이 여러 이미지에서 추출된 경우)
        let uniqueMenus = removeDuplicateMenus(allMenus)

        return uniqueMenus
    }

    /// 중복 메뉴 제거 (메뉴명 기준)
    private func removeDuplicateMenus(_ menus: [Menu]) -> [Menu] {
        var uniqueMenuNames = Set<String>()
        var uniqueMenus: [Menu] = []

        for menu in menus {
            let normalizedName = menu.name.lowercased().trimmingCharacters(in: .whitespaces)
            if !uniqueMenuNames.contains(normalizedName) {
                uniqueMenuNames.insert(normalizedName)
                uniqueMenus.append(menu)
            }
        }

        return uniqueMenus
    }
}

// MARK: - Models

struct GoogleSearchResponse: Codable {
    let items: [GoogleSearchItem]?
}

struct GoogleSearchItem: Codable {
    let title: String
    let link: String  // 이미지 URL
    let displayLink: String?
}

enum GoogleSearchError: Error {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case quotaExceeded
    case noResults
    case imageLoadFailed

    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "잘못된 URL입니다"
        case .invalidResponse:
            return "서버 응답이 올바르지 않습니다"
        case .httpError(let code):
            return "HTTP 오류: \(code)"
        case .quotaExceeded:
            return "일일 할당량(100회)을 초과했습니다. 내일 다시 시도하세요."
        case .noResults:
            return "검색 결과가 없습니다"
        case .imageLoadFailed:
            return "이미지를 불러올 수 없습니다"
        }
    }
}
