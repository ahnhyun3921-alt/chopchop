//
//  FirestoreService.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//

import Foundation
// Firebase는 나중에 설치 후 활성화
// import FirebaseFirestore
// import FirebaseFirestoreSwift

class FirestoreService {
    static let shared = FirestoreService()
    // private let db = Firestore.firestore()

    private init() {}

    // MARK: - Favorites (Firebase 설치 후 활성화)

    /// 즐겨찾기 추가
    func addFavorite(userId: String, restaurantId: String) async throws {
        // Firebase 설치 전 임시 구현 - UserDefaults 사용
        var favorites = UserDefaults.standard.stringArray(forKey: "favorites_\(userId)") ?? []
        if !favorites.contains(restaurantId) {
            favorites.append(restaurantId)
            UserDefaults.standard.set(favorites, forKey: "favorites_\(userId)")
        }
    }

    /// 즐겨찾기 제거
    func removeFavorite(userId: String, restaurantId: String) async throws {
        // Firebase 설치 전 임시 구현 - UserDefaults 사용
        var favorites = UserDefaults.standard.stringArray(forKey: "favorites_\(userId)") ?? []
        favorites.removeAll { $0 == restaurantId }
        UserDefaults.standard.set(favorites, forKey: "favorites_\(userId)")
    }

    /// 즐겨찾기 상태 확인
    func isFavorite(userId: String, restaurantId: String) async throws -> Bool {
        // Firebase 설치 전 임시 구현 - UserDefaults 사용
        let favorites = UserDefaults.standard.stringArray(forKey: "favorites_\(userId)") ?? []
        return favorites.contains(restaurantId)
    }

    /// 모든 즐겨찾기 가져오기
    func getFavorites(userId: String) async throws -> [String] {
        // Firebase 설치 전 임시 구현 - UserDefaults 사용
        return UserDefaults.standard.stringArray(forKey: "favorites_\(userId)") ?? []
    }

    // MARK: - User Persons (제한 식품 관리) - Firebase 설치 후 활성화

    /// 사용자의 인물 추가
    func addPerson(userId: String, person: Person) async throws {
        // Firebase 설치 전 임시 구현 - UserDefaults에 JSON으로 저장
        var persons = try await getPersons(userId: userId)
        persons.append(person)

        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(persons) {
            UserDefaults.standard.set(encoded, forKey: "persons_\(userId)")
        }
        // TODO: Firebase 설치 후 Firestore에 저장하도록 변경
    }

    /// 사용자의 인물 목록 가져오기
    func getPersons(userId: String) async throws -> [Person] {
        // Firebase 설치 전 임시 구현 - UserDefaults에서 JSON 디코딩
        if let data = UserDefaults.standard.data(forKey: "persons_\(userId)") {
            let decoder = JSONDecoder()
            if let persons = try? decoder.decode([Person].self, from: data) {
                return persons
            }
        }
        // TODO: Firebase 설치 후 Firestore에서 가져오도록 변경
        return []
    }

    /// 사용자의 인물 삭제
    func deletePerson(userId: String, personId: String) async throws {
        // Firebase 설치 전 임시 구현 - UserDefaults에서 삭제
        var persons = try await getPersons(userId: userId)
        persons.removeAll { $0.id == personId }

        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(persons) {
            UserDefaults.standard.set(encoded, forKey: "persons_\(userId)")
        }
        // TODO: Firebase 설치 후 Firestore에서 삭제하도록 변경
    }

    /// 사용자의 인물 업데이트
    func updatePerson(userId: String, person: Person) async throws {
        // Firebase 설치 전 임시 구현 - UserDefaults에서 업데이트
        var persons = try await getPersons(userId: userId)
        if let index = persons.firstIndex(where: { $0.id == person.id }) {
            persons[index] = person
        }

        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(persons) {
            UserDefaults.standard.set(encoded, forKey: "persons_\(userId)")
        }
        // TODO: Firebase 설치 후 Firestore에 저장하도록 변경
    }

    // MARK: - Restaurant Cache (네이버 검색 결과 캐싱) - Firebase 설치 후 활성화

    /// 식당 정보 캐시에 저장
    func cacheRestaurant(_ restaurant: Restaurant) async throws {
        // Firebase 설치 전 임시 구현 - UserDefaults에 JSON으로 저장
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(restaurant) {
            UserDefaults.standard.set(encoded, forKey: "restaurant_\(restaurant.id)")
        }
        // TODO: Firebase 설치 후 Firestore에 저장하도록 변경
    }

    /// 캐시된 식당 정보 가져오기
    func getCachedRestaurant(restaurantId: String) async throws -> Restaurant? {
        // Firebase 설치 전 임시 구현 - UserDefaults에서 JSON 디코딩
        if let data = UserDefaults.standard.data(forKey: "restaurant_\(restaurantId)") {
            let decoder = JSONDecoder()
            if let restaurant = try? decoder.decode(Restaurant.self, from: data) {
                return restaurant
            }
        }
        // TODO: Firebase 설치 후 Firestore에서 가져오도록 변경
        return nil
    }
}
