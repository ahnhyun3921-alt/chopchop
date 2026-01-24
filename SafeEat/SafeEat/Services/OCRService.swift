//
//  OCRService.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//

import Foundation
import Vision
import UIKit

class OCRService {
    static let shared = OCRService()

    private init() {}

    /// 이미지에서 텍스트 추출 (Apple Vision 사용 - 완전 무료!)
    func extractText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }

                // 모든 인식된 텍스트를 줄바꿈으로 연결
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                continuation.resume(returning: recognizedText)
            }

            // 한글 인식을 위한 설정
            request.recognitionLanguages = ["ko-KR", "en-US"]
            request.recognitionLevel = .accurate  // 정확도 우선
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// 추출된 텍스트에서 메뉴 정보 파싱 (간단한 규칙 기반)
    func parseMenus(from text: String, restaurantId: String) -> [Menu] {
        var menus: [Menu] = []
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var currentMenuName: String?
        var currentPrice: Int?

        for line in lines {
            // 가격 패턴 찾기 (예: 10,000원 또는 10000원)
            if let price = extractPrice(from: line) {
                currentPrice = price

                // 가격 앞에 있는 텍스트를 메뉴명으로 추정
                let menuName = line.replacingOccurrences(of: "원", with: "")
                    .replacingOccurrences(of: ",", with: "")
                    .replacingOccurrences(of: String(price), with: "")
                    .trimmingCharacters(in: .whitespaces)

                if !menuName.isEmpty {
                    currentMenuName = menuName
                }

                // 메뉴명과 가격이 모두 있으면 메뉴 생성
                if let name = currentMenuName, let price = currentPrice {
                    let menu = Menu(
                        restaurantId: restaurantId,
                        name: name,
                        price: price,
                        ingredients: extractIngredients(from: line)
                    )
                    menus.append(menu)

                    // 초기화
                    currentMenuName = nil
                    currentPrice = nil
                }
            } else if currentMenuName == nil && !line.isEmpty {
                // 가격이 없는 줄은 메뉴명 후보로 저장
                currentMenuName = line
            }
        }

        return menus
    }

    /// 텍스트에서 가격 추출 (예: "김치찌개 10,000원" -> 10000)
    private func extractPrice(from text: String) -> Int? {
        let pattern = #"([0-9,]+)\s*원"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }

        let priceRange = Range(match.range(at: 1), in: text)
        guard let priceString = priceRange.map({ String(text[$0]) }) else { return nil }

        let cleanedPrice = priceString.replacingOccurrences(of: ",", with: "")
        return Int(cleanedPrice)
    }

    /// 텍스트에서 재료 추출 (괄호 안 내용 등)
    private func extractIngredients(from text: String) -> [String] {
        var ingredients: [String] = []

        // 괄호 안 내용 추출 (예: "김치찌개 (돼지고기, 김치, 두부)")
        let pattern = #"\(([^)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return ingredients }

        let range = NSRange(text.startIndex..., in: text)
        regex.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match = match else { return }
            let ingredientRange = Range(match.range(at: 1), in: text)
            if let ingredientText = ingredientRange.map({ String(text[$0]) }) {
                // 쉼표로 분리
                let items = ingredientText.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                ingredients.append(contentsOf: items)
            }
        }

        return ingredients
    }
}

enum OCRError: Error {
    case invalidImage
    case recognitionFailed

    var localizedDescription: String {
        switch self {
        case .invalidImage:
            return "이미지를 처리할 수 없습니다"
        case .recognitionFailed:
            return "텍스트 인식에 실패했습니다"
        }
    }
}
