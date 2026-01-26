//
//  RestaurantDetailViewModel.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//

import Foundation
import Combine

class RestaurantDetailViewModel: ObservableObject {
    @Published var restaurant: Restaurant
    @Published var selectedPersons: [Person]
    @Published var safeMenuInfos: [SafeMenuInfo]
    @Published var allMenus: [Menu] = []
    @Published var isLoading: Bool = false
    @Published var isOperatingHoursExpanded = false
    @Published var expandedPersonIds: Set<String> = []
    @Published var selectedMenuTab: MenuTab = .safe
    @Published var isFavorite: Bool = false

    var totalSafeMenuCount: Int {
        safeMenuInfos.reduce(0) { $0 + $1.safeMenuCount }
    }

    init(restaurant: Restaurant = .sample, selectedPersons: [Person] = Person.sample) {
        self.restaurant = restaurant
        self.selectedPersons = selectedPersons
        self.safeMenuInfos = []
        self.isFavorite = Self.loadFavoriteStatus(restaurantId: restaurant.id)
    }

    // Firebase에서 메뉴 불러오기
    func loadMenusFromFirebase() async {
        await MainActor.run { isLoading = true }

        do {
            // 먼저 식당 이름으로 검색 (카카오 ID와 Firebase ID가 다를 수 있음)
            let fetchedMenus = try await FirestoreService.shared.getMenusByRestaurantName(name: restaurant.name)

            // 이름 검색 실패시 ID로 시도
            let finalMenus: [Menu]
            if fetchedMenus.isEmpty {
                finalMenus = try await FirestoreService.shared.getMenus(restaurantId: restaurant.id)
            } else {
                finalMenus = fetchedMenus
            }

            await MainActor.run {
                self.allMenus = finalMenus
                self.isLoading = false
                print("메뉴 로드 성공: \(finalMenus.count)개")
            }

            // AI로 안전한 메뉴 계산 (백그라운드)
            await calculateSafeMenusWithAI(menus: finalMenus)

        } catch {
            print("메뉴 로드 실패: \(error.localizedDescription)")
            await MainActor.run {
                self.safeMenuInfos = []
                self.isLoading = false
            }
        }
    }

    // AI로 메뉴별 알레르기 확률 계산
    private func calculateSafeMenusWithAI(menus: [Menu]) async {
        var safeMenuInfosResult: [SafeMenuInfo] = []

        for person in selectedPersons {
            guard !person.restrictedIngredients.isEmpty else {
                // 제한 성분이 없으면 모든 메뉴가 안전
                safeMenuInfosResult.append(SafeMenuInfo(
                    person: person,
                    safeMenuCount: menus.count,
                    safeMenus: menus
                ))
                continue
            }

            var safeMenus: [Menu] = []

            for menu in menus {
                do {
                    // Claude AI로 확률 계산
                    let result = try await ClaudeAPIService.shared.calculateAllergyProbability(
                        menuName: menu.name,
                        restrictedIngredients: person.restrictedIngredients
                    )

                    // 안전한 메뉴인 경우 (overall_safe가 true)
                    if result.overallSafe {
                        let updatedMenu = Menu(
                            id: menu.id,
                            restaurantId: menu.restaurantId,
                            name: menu.name,
                            price: menu.price,
                            description: menu.description,
                            ingredients: menu.ingredients,
                            imageUrl: menu.imageUrl,
                            probabilityTags: result.tags
                        )
                        safeMenus.append(updatedMenu)
                    }
                } catch {
                    print("AI 분석 실패 (\(menu.name)): \(error.localizedDescription)")
                    // AI 실패 시 기본 필터링 사용
                    if !menu.containsAny(restrictedIngredients: person.restrictedIngredients) {
                        safeMenus.append(menu)
                    }
                }
            }

            safeMenuInfosResult.append(SafeMenuInfo(
                person: person,
                safeMenuCount: safeMenus.count,
                safeMenus: safeMenus
            ))
        }

        await MainActor.run {
            self.safeMenuInfos = safeMenuInfosResult
        }
    }

    // 하트 토글
    func toggleFavorite() {
        isFavorite.toggle()

        // Firebase에 즐겨찾기 저장 (비동기)
        Task {
            do {
                // TODO: 실제 userId를 AuthenticationService에서 가져와야 함
                let userId = "temp_user_id"

                if isFavorite {
                    // 즐겨찾기 추가 + 식당 정보 캐싱
                    try await FirestoreService.shared.addFavorite(userId: userId, restaurantId: restaurant.id)
                    try await FirestoreService.shared.cacheRestaurant(restaurant)
                } else {
                    try await FirestoreService.shared.removeFavorite(userId: userId, restaurantId: restaurant.id)
                }
            } catch {
                print("즐겨찾기 저장 실패: \(error.localizedDescription)")
                // 에러 발생 시 상태 되돌리기
                isFavorite.toggle()
            }
        }
    }

    // Firebase에서 즐겨찾기 상태 불러오기
    private static func loadFavoriteStatus(restaurantId: String) -> Bool {
        // 임시로 UserDefaults 사용 (Firebase 로그인 전)
        // TODO: Firebase에서 불러오도록 수정
        return UserDefaults.standard.bool(forKey: "favorite_\(restaurantId)")
    }

    // 즐겨찾기 상태 동기화 (Firebase에서)
    func loadFavoriteFromFirebase() async {
        do {
            // TODO: 실제 userId를 AuthenticationService에서 가져와야 함
            let userId = "temp_user_id"
            let isFav = try await FirestoreService.shared.isFavorite(userId: userId, restaurantId: restaurant.id)

            await MainActor.run {
                self.isFavorite = isFav
            }
        } catch {
            print("즐겨찾기 로드 실패: \(error.localizedDescription)")
        }
    }

    func toggleOperatingHours() {
        isOperatingHoursExpanded.toggle()
    }

    func togglePersonMenuExpansion(personId: String) {
        if expandedPersonIds.contains(personId) {
            expandedPersonIds.remove(personId)
        } else {
            expandedPersonIds.insert(personId)
        }
    }

    func isPersonMenuExpanded(personId: String) -> Bool {
        expandedPersonIds.contains(personId)
    }

    private static func calculateSafeMenus(for persons: [Person], restaurant: Restaurant) -> [SafeMenuInfo] {
        return persons.map { person in
            SafeMenuInfo(
                person: person,
                safeMenuCount: person.name == "철진" ? 2 : 3,
                safeMenus: sampleMenus(for: person)
            )
        }
    }

    private static func sampleMenus(for person: Person) -> [Menu] {
        if person.name == "철진" {
            return [
                Menu(
                    id: "1",
                    restaurantId: "sample",
                    name: "아보카도 셔핑 브레드",
                    price: 12500,
                    description: nil,
                    ingredients: ["아보카도", "빵", "토마토"],
                    imageUrl: nil,
                    probabilityTags: ["우유 미포함 가능성 95%", "쇠고기 미포함 가능성 98%", "돼지"]
                ),
                Menu(
                    id: "2",
                    restaurantId: "sample",
                    name: "그라브락스 연어 샐러드",
                    price: 25500,
                    description: nil,
                    ingredients: ["연어", "샐러드", "올리브"],
                    imageUrl: nil,
                    probabilityTags: ["우유 미포함 가능성 80%", "쇠고기 미포함 가능성 98%", "돼지"]
                )
            ]
        } else {
            return [
                Menu(
                    id: "3",
                    restaurantId: "sample",
                    name: "아보카도 셔핑 브레드",
                    price: 12500,
                    description: nil,
                    ingredients: ["아보카도", "빵", "토마토"],
                    imageUrl: nil,
                    probabilityTags: ["우유 미포함 가능성 95%", "쇠고기 미포함 가능성 98%", "돼지"]
                ),
                Menu(
                    id: "4",
                    restaurantId: "sample",
                    name: "그라브락스 연어 샐러드",
                    price: 25500,
                    description: nil,
                    ingredients: ["연어", "샐러드", "올리브"],
                    imageUrl: nil,
                    probabilityTags: ["우유 미포함 가능성 80%", "쇠고기 미포함 가능성 98%", "돼지"]
                ),
                Menu(
                    id: "5",
                    restaurantId: "sample",
                    name: "토마토 파스타",
                    price: 15000,
                    description: nil,
                    ingredients: ["파스타", "토마토", "바질"],
                    imageUrl: nil,
                    probabilityTags: ["우유 미포함 가능성 90%", "쇠고기 미포함 가능성 95%"]
                )
            ]
        }
    }
}
