//
//  FirestoreService.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Favorites

    /// 즐겨찾기 추가
    func addFavorite(userId: String, restaurantId: String) async throws {
        let docRef = db.collection("users").document(userId).collection("favorites").document(restaurantId)
        try await docRef.setData([
            "restaurantId": restaurantId,
            "createdAt": FieldValue.serverTimestamp()
        ])
    }

    /// 즐겨찾기 제거
    func removeFavorite(userId: String, restaurantId: String) async throws {
        let docRef = db.collection("users").document(userId).collection("favorites").document(restaurantId)
        try await docRef.delete()
    }

    /// 즐겨찾기 상태 확인
    func isFavorite(userId: String, restaurantId: String) async throws -> Bool {
        let docRef = db.collection("users").document(userId).collection("favorites").document(restaurantId)
        let snapshot = try await docRef.getDocument()
        return snapshot.exists
    }

    /// 모든 즐겨찾기 가져오기
    func getFavorites(userId: String) async throws -> [String] {
        let snapshot = try await db.collection("users").document(userId).collection("favorites").getDocuments()
        return snapshot.documents.map { $0.documentID }
    }

    // MARK: - User Persons (제한 식품 관리)

    /// 사용자의 인물 추가
    func addPerson(userId: String, person: Person) async throws {
        let docRef = db.collection("users").document(userId).collection("persons").document(person.id)
        try docRef.setData(from: person)
    }

    /// 사용자의 인물 목록 가져오기
    func getPersons(userId: String) async throws -> [Person] {
        let snapshot = try await db.collection("users").document(userId).collection("persons").getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Person.self) }
    }

    /// 사용자의 인물 삭제
    func deletePerson(userId: String, personId: String) async throws {
        let docRef = db.collection("users").document(userId).collection("persons").document(personId)
        try await docRef.delete()
    }

    /// 사용자의 인물 업데이트
    func updatePerson(userId: String, person: Person) async throws {
        let docRef = db.collection("users").document(userId).collection("persons").document(person.id)
        try docRef.setData(from: person, merge: true)
    }

    // MARK: - Restaurant Cache (카카오 검색 결과 캐싱)

    /// 식당 정보 캐시에 저장
    func cacheRestaurant(_ restaurant: Restaurant) async throws {
        let docRef = db.collection("restaurants").document(restaurant.id)
        try docRef.setData(from: restaurant, merge: true)
    }

    /// 캐시된 식당 정보 가져오기
    func getCachedRestaurant(restaurantId: String) async throws -> Restaurant? {
        let docRef = db.collection("restaurants").document(restaurantId)
        let snapshot = try await docRef.getDocument()
        return try? snapshot.data(as: Restaurant.self)
    }

    // MARK: - Menus (메뉴 데이터)

    /// 메뉴 추가
    func addMenu(_ menu: Menu) async throws {
        let docRef = db.collection("restaurants")
            .document(menu.restaurantId)
            .collection("menus")
            .document(menu.id)
        try docRef.setData(from: menu)
    }

    /// 식당의 모든 메뉴 가져오기
    func getMenus(restaurantId: String) async throws -> [Menu] {
        let snapshot = try await db.collection("restaurants")
            .document(restaurantId)
            .collection("menus")
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Menu.self) }
    }

    /// 메뉴 삭제
    func deleteMenu(restaurantId: String, menuId: String) async throws {
        let docRef = db.collection("restaurants")
            .document(restaurantId)
            .collection("menus")
            .document(menuId)
        try await docRef.delete()
    }

    /// 메뉴 업데이트
    func updateMenu(_ menu: Menu) async throws {
        let docRef = db.collection("restaurants")
            .document(menu.restaurantId)
            .collection("menus")
            .document(menu.id)
        try docRef.setData(from: menu, merge: true)
    }
}
