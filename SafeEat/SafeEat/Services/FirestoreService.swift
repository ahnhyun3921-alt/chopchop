//
//  FirestoreService.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//  임시로 로컬 저장소 사용 (Firebase 대신)
//

import Foundation

class FirestoreService {
    static let shared = FirestoreService()
    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Favorites

    /// 즐겨찾기 추가
    func addFavorite(userId: String, restaurantId: String) async throws {
        var favorites = getFavoritesSync(userId: userId)
        if !favorites.contains(restaurantId) {
            favorites.append(restaurantId)
            defaults.set(favorites, forKey: "favorites_\(userId)")
        }
    }

    /// 즐겨찾기 제거
    func removeFavorite(userId: String, restaurantId: String) async throws {
        var favorites = getFavoritesSync(userId: userId)
        favorites.removeAll { $0 == restaurantId }
        defaults.set(favorites, forKey: "favorites_\(userId)")
    }

    /// 즐겨찾기 상태 확인
    func isFavorite(userId: String, restaurantId: String) async throws -> Bool {
        let favorites = getFavoritesSync(userId: userId)
        return favorites.contains(restaurantId)
    }

    /// 모든 즐겨찾기 가져오기
    func getFavorites(userId: String) async throws -> [String] {
        return getFavoritesSync(userId: userId)
    }

    private func getFavoritesSync(userId: String) -> [String] {
        return defaults.stringArray(forKey: "favorites_\(userId)") ?? []
    }

    // MARK: - User Persons (제한 식품 관리)

    /// 사용자의 인물 추가
    func addPerson(userId: String, person: Person) async throws {
        var persons = try await getPersons(userId: userId)
        persons.removeAll { $0.id == person.id }
        persons.append(person)
        savePersons(userId: userId, persons: persons)
    }

    /// 사용자의 인물 목록 가져오기
    func getPersons(userId: String) async throws -> [Person] {
        guard let data = defaults.data(forKey: "persons_\(userId)"),
              let persons = try? JSONDecoder().decode([Person].self, from: data) else {
            return Person.sample // 기본 샘플 데이터 반환
        }
        return persons
    }

    /// 사용자의 인물 삭제
    func deletePerson(userId: String, personId: String) async throws {
        var persons = try await getPersons(userId: userId)
        persons.removeAll { $0.id == personId }
        savePersons(userId: userId, persons: persons)
    }

    /// 사용자의 인물 업데이트
    func updatePerson(userId: String, person: Person) async throws {
        try await addPerson(userId: userId, person: person)
    }

    private func savePersons(userId: String, persons: [Person]) {
        if let data = try? JSONEncoder().encode(persons) {
            defaults.set(data, forKey: "persons_\(userId)")
        }
    }

    // MARK: - Restaurant Cache

    /// 식당 정보 캐시에 저장
    func cacheRestaurant(_ restaurant: Restaurant) async throws {
        if let data = try? JSONEncoder().encode(restaurant) {
            defaults.set(data, forKey: "restaurant_\(restaurant.id)")
        }
    }

    /// 캐시된 식당 정보 가져오기
    func getCachedRestaurant(restaurantId: String) async throws -> Restaurant? {
        guard let data = defaults.data(forKey: "restaurant_\(restaurantId)"),
              let restaurant = try? JSONDecoder().decode(Restaurant.self, from: data) else {
            return nil
        }
        return restaurant
    }

    // MARK: - Menus

    /// 메뉴 추가
    func addMenu(_ menu: Menu) async throws {
        var menus = try await getMenus(restaurantId: menu.restaurantId)
        menus.removeAll { $0.id == menu.id }
        menus.append(menu)
        saveMenus(restaurantId: menu.restaurantId, menus: menus)
    }

    /// 식당의 모든 메뉴 가져오기
    func getMenus(restaurantId: String) async throws -> [Menu] {
        guard let data = defaults.data(forKey: "menus_\(restaurantId)"),
              let menus = try? JSONDecoder().decode([Menu].self, from: data) else {
            return []
        }
        return menus
    }

    /// 메뉴 삭제
    func deleteMenu(restaurantId: String, menuId: String) async throws {
        var menus = try await getMenus(restaurantId: restaurantId)
        menus.removeAll { $0.id == menuId }
        saveMenus(restaurantId: restaurantId, menus: menus)
    }

    /// 메뉴 업데이트
    func updateMenu(_ menu: Menu) async throws {
        try await addMenu(menu)
    }

    private func saveMenus(restaurantId: String, menus: [Menu]) {
        if let data = try? JSONEncoder().encode(menus) {
            defaults.set(data, forKey: "menus_\(restaurantId)")
        }
    }
}
