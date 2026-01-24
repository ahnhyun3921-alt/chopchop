//
//  MenuAnalysisService.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//

import Foundation

/// 메뉴 분석 및 안전한 메뉴 필터링 서비스
class MenuAnalysisService {
    static let shared = MenuAnalysisService()

    private let claudeAPI = ClaudeAPIService.shared
    private let firestoreService = FirestoreService.shared

    // 메뉴 분석 캐시 (메모리)
    private var analysisCache: [String: MenuAnalysisResult] = [:]

    private init() {}

    // MARK: - 메뉴 분석

    /// 식당의 모든 메뉴를 분석하여 재료 정보 추가
    func analyzeRestaurantMenus(restaurant: Restaurant, menus: [String]) async throws -> [Menu] {
        // 캐시 확인
        var menusToAnalyze: [String] = []
        var cachedMenus: [String: MenuAnalysisResult] = [:]

        for menuName in menus {
            if let cached = analysisCache[menuName] {
                cachedMenus[menuName] = cached
            } else {
                menusToAnalyze.append(menuName)
            }
        }

        // 캐시에 없는 메뉴만 분석
        var analysisResults = cachedMenus

        if !menusToAnalyze.isEmpty {
            let newResults = try await claudeAPI.analyzeMenus(menuNames: menusToAnalyze)

            // 캐시에 저장
            for (menuName, result) in newResults {
                analysisCache[menuName] = result
                analysisResults[menuName] = result
            }
        }

        // Menu 객체 생성
        var menuObjects: [Menu] = []

        for (index, menuName) in menus.enumerated() {
            if let analysis = analysisResults[menuName] {
                menuObjects.append(Menu(
                    id: "\(restaurant.id)_menu_\(index)",
                    name: menuName,
                    price: Int.random(in: 8000...35000), // TODO: 실제 가격 정보
                    description: nil,
                    ingredients: analysis.ingredients,
                    imageUrl: nil,
                    probabilityTags: [] // 아직 확률 계산 전
                ))
            }
        }

        return menuObjects
    }

    // MARK: - 안전한 메뉴 필터링

    /// 특정 인물에게 안전한 메뉴 필터링 및 확률 계산
    func findSafeMenusForPerson(
        person: Person,
        menus: [Menu]
    ) async throws -> SafeMenuInfo {
        var safeMenus: [Menu] = []

        for menu in menus {
            // Claude API로 알러지 확률 계산
            let probabilityResult = try await claudeAPI.calculateAllergyProbability(
                menuName: menu.name,
                restrictedIngredients: person.restrictedIngredients
            )

            // 안전한 메뉴인 경우 (overall_safe가 true)
            if probabilityResult.overallSafe {
                // 확률 태그 추가
                var updatedMenu = menu
                updatedMenu = Menu(
                    id: menu.id,
                    name: menu.name,
                    price: menu.price,
                    description: menu.description,
                    ingredients: menu.ingredients,
                    imageUrl: menu.imageUrl,
                    probabilityTags: probabilityResult.tags
                )
                safeMenus.append(updatedMenu)
            }
        }

        return SafeMenuInfo(
            person: person,
            safeMenuCount: safeMenus.count,
            safeMenus: safeMenus
        )
    }

    /// 여러 인물에 대해 안전한 메뉴 필터링
    func findSafeMenusForPersons(
        persons: [Person],
        menus: [Menu]
    ) async throws -> [SafeMenuInfo] {
        var safeMenuInfos: [SafeMenuInfo] = []

        for person in persons {
            let safeMenuInfo = try await findSafeMenusForPerson(person: person, menus: menus)
            safeMenuInfos.append(safeMenuInfo)
        }

        return safeMenuInfos
    }

    // MARK: - 빠른 필터링 (로컬)

    /// Claude API 없이 로컬에서 빠르게 필터링 (재료 목록 기반)
    /// - 정확도는 낮지만 빠른 필터링
    func quickFilterSafeMenus(
        person: Person,
        menus: [Menu]
    ) -> [Menu] {
        return menus.filter { menu in
            // 메뉴의 재료 목록에 제한 성분이 없는지 확인
            let menuIngredients = Set(menu.ingredients.map { $0.lowercased() })
            let restrictions = Set(person.restrictedIngredients.map { $0.lowercased() })

            // 교집합이 없으면 안전한 메뉴
            return menuIngredients.intersection(restrictions).isEmpty
        }
    }

    // MARK: - 캐시 관리

    /// 메모리 캐시 초기화
    func clearCache() {
        analysisCache.removeAll()
    }

    /// 특정 메뉴 캐시 삭제
    func removeCachedAnalysis(for menuName: String) {
        analysisCache.removeValue(forKey: menuName)
    }
}

// MARK: - Menu Extension

extension Menu {
    /// 특정 제한 성분을 포함하는지 확인
    func contains(restrictedIngredient: String) -> Bool {
        let lowerIngredient = restrictedIngredient.lowercased()
        return ingredients.contains { $0.lowercased().contains(lowerIngredient) }
    }

    /// 여러 제한 성분 중 하나라도 포함하는지 확인
    func containsAny(restrictedIngredients: [String]) -> Bool {
        return restrictedIngredients.contains { contains(restrictedIngredient: $0) }
    }
}
