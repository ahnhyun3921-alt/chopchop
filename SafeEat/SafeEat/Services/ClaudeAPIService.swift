//
//  ClaudeAPIService.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//

import Foundation

class ClaudeAPIService {
    static let shared = ClaudeAPIService()

    // TODO: 실제 API 키로 교체 필요 (.env 파일에서 읽어오기)
    private let apiKey = "YOUR_CLAUDE_API_KEY"
    private let apiURL = "https://api.anthropic.com/v1/messages"
    private let model = "claude-3-5-haiku-20241022"
    private let apiVersion = "2023-06-01"

    private init() {}

    // MARK: - 메뉴 분석

    /// 메뉴 이름을 분석하여 재료 및 알러지 유발 물질 추출
    func analyzeMenu(menuName: String) async throws -> MenuAnalysisResult {
        let prompt = """
        다음 음식 메뉴의 재료와 알러지 유발 물질을 분석해주세요.

        메뉴: \(menuName)

        다음 형식의 JSON으로 응답해주세요:
        {
          "ingredients": ["재료1", "재료2", ...],
          "allergens": ["알러지 물질1", "알러지 물질2", ...]
        }

        알러지 유발 물질은 다음 중에서만 선택해주세요:
        우유, 쇠고기, 돼지고기, 닭고기, 새우, 갑각류, 조개, 달걀, 땅콩, 밀, 대두, 고등어, 게, 복숭아, 토마토, 아황산류, 호두, 잣, 메밀

        JSON만 출력하고 다른 설명은 하지 마세요.
        """

        let response = try await callClaudeAPI(prompt: prompt)
        return try parseMenuAnalysis(response)
    }

    /// 여러 메뉴를 한 번에 분석 (배치 처리)
    func analyzeMenus(menuNames: [String]) async throws -> [String: MenuAnalysisResult] {
        let menuList = menuNames.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")

        let prompt = """
        다음 음식 메뉴들의 재료와 알러지 유발 물질을 분석해주세요.

        메뉴 목록:
        \(menuList)

        각 메뉴에 대해 다음 형식의 JSON으로 응답해주세요:
        {
          "메뉴1": {
            "ingredients": ["재료1", "재료2", ...],
            "allergens": ["알러지 물질1", "알러지 물질2", ...]
          },
          "메뉴2": {
            "ingredients": ["재료1", "재료2", ...],
            "allergens": ["알러지 물질1", "알러지 물질2", ...]
          }
        }

        알러지 유발 물질은 다음 중에서만 선택해주세요:
        우유, 쇠고기, 돼지고기, 닭고기, 새우, 갑각류, 조개, 달걀, 땅콩, 밀, 대두, 고등어, 게, 복숭아, 토마토, 아황산류, 호두, 잣, 메밀

        JSON만 출력하고 다른 설명은 하지 마세요.
        """

        let response = try await callClaudeAPI(prompt: prompt)
        return try parseBatchMenuAnalysis(response, menuNames: menuNames)
    }

    // MARK: - 알러지 확률 계산

    /// 특정 메뉴가 제한 성분을 포함할 확률 계산
    func calculateAllergyProbability(
        menuName: String,
        restrictedIngredients: [String]
    ) async throws -> AllergyProbabilityResult {
        let ingredientsList = restrictedIngredients.joined(separator: ", ")

        let prompt = """
        다음 음식 메뉴가 제한 성분을 포함할 확률을 분석해주세요.

        메뉴: \(menuName)
        제한 성분: \(ingredientsList)

        각 제한 성분에 대해 다음을 분석해주세요:
        1. 포함 가능성 (0-100% 확률)
        2. 포함 이유 또는 미포함 이유

        다음 형식의 JSON으로 응답해주세요:
        {
          "results": [
            {
              "ingredient": "우유",
              "probability": 95,
              "reason": "파마산 치즈는 필수 재료로 우유가 포함됩니다",
              "safe": false
            }
          ],
          "overall_safe": false,
          "tags": ["우유 포함 가능성 95%"]
        }

        확률 기준:
        - 90-100%: 거의 확실히 포함
        - 70-89%: 높은 확률로 포함
        - 30-69%: 불확실 (주의 필요)
        - 10-29%: 낮은 확률로 포함
        - 0-9%: 거의 확실히 미포함

        overall_safe는 모든 제한 성분이 10% 미만일 때만 true로 설정하세요.
        tags는 확률이 높은 것부터 최대 3개까지 생성하세요.

        JSON만 출력하고 다른 설명은 하지 마세요.
        """

        let response = try await callClaudeAPI(prompt: prompt)
        return try parseAllergyProbability(response)
    }

    // MARK: - Claude API 호출

    private func callClaudeAPI(prompt: String, maxTokens: Int = 2048) async throws -> String {
        guard let url = URL(string: apiURL) else {
            throw ClaudeAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClaudeAPIError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw ClaudeAPIError.invalidResponseFormat
        }

        return text
    }

    // MARK: - 응답 파싱

    private func parseMenuAnalysis(_ response: String) throws -> MenuAnalysisResult {
        // JSON 추출 (마크다운 코드 블록 제거)
        let jsonString = extractJSON(from: response)

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ingredients = json["ingredients"] as? [String],
              let allergens = json["allergens"] as? [String] else {
            throw ClaudeAPIError.parsingError
        }

        return MenuAnalysisResult(ingredients: ingredients, allergens: allergens)
    }

    private func parseBatchMenuAnalysis(_ response: String, menuNames: [String]) throws -> [String: MenuAnalysisResult] {
        let jsonString = extractJSON(from: response)

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeAPIError.parsingError
        }

        var results: [String: MenuAnalysisResult] = [:]

        for menuName in menuNames {
            if let menuData = json[menuName] as? [String: Any],
               let ingredients = menuData["ingredients"] as? [String],
               let allergens = menuData["allergens"] as? [String] {
                results[menuName] = MenuAnalysisResult(ingredients: ingredients, allergens: allergens)
            }
        }

        return results
    }

    private func parseAllergyProbability(_ response: String) throws -> AllergyProbabilityResult {
        let jsonString = extractJSON(from: response)

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let resultsArray = json["results"] as? [[String: Any]],
              let overallSafe = json["overall_safe"] as? Bool,
              let tags = json["tags"] as? [String] else {
            throw ClaudeAPIError.parsingError
        }

        let results = resultsArray.compactMap { item -> IngredientProbability? in
            guard let ingredient = item["ingredient"] as? String,
                  let probability = item["probability"] as? Int,
                  let reason = item["reason"] as? String,
                  let safe = item["safe"] as? Bool else {
                return nil
            }
            return IngredientProbability(
                ingredient: ingredient,
                probability: probability,
                reason: reason,
                safe: safe
            )
        }

        return AllergyProbabilityResult(
            results: results,
            overallSafe: overallSafe,
            tags: tags
        )
    }

    private func extractJSON(from text: String) -> String {
        // 마크다운 코드 블록 제거
        if text.contains("```json") {
            let parts = text.components(separatedBy: "```json")
            if parts.count > 1 {
                let jsonPart = parts[1].components(separatedBy: "```")[0]
                return jsonPart.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } else if text.contains("```") {
            let parts = text.components(separatedBy: "```")
            if parts.count > 1 {
                return parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Models

struct MenuAnalysisResult {
    let ingredients: [String]
    let allergens: [String]
}

struct AllergyProbabilityResult {
    let results: [IngredientProbability]
    let overallSafe: Bool
    let tags: [String]
}

struct IngredientProbability {
    let ingredient: String
    let probability: Int  // 0-100
    let reason: String
    let safe: Bool
}

enum ClaudeAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case invalidResponseFormat
    case parsingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "잘못된 API URL입니다."
        case .invalidResponse:
            return "서버 응답이 올바르지 않습니다."
        case .httpError(let statusCode, let message):
            return "HTTP 오류 \(statusCode): \(message)"
        case .invalidResponseFormat:
            return "응답 형식이 올바르지 않습니다."
        case .parsingError:
            return "응답 파싱 중 오류가 발생했습니다."
        }
    }
}
