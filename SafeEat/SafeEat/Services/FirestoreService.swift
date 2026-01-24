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
        let favoriteData: [String: Any] = [
            "restaurantId": restaurantId,
            "createdAt": Timestamp(date: Date())
        ]

        try await db.collection("users")
            .document(userId)
            .collection("favorites")
            .document(restaurantId)
            .setData(favoriteData)
    }

    /// 즐겨찾기 제거
    func removeFavorite(userId: String, restaurantId: String) async throws {
        try await db.collection("users")
            .document(userId)
            .collection("favorites")
            .document(restaurantId)
            .delete()
    }

    /// 즐겨찾기 상태 확인
    func isFavorite(userId: String, restaurantId: String) async throws -> Bool {
        let document = try await db.collection("users")
            .document(userId)
            .collection("favorites")
            .document(restaurantId)
            .getDocument()

        return document.exists
    }

    /// 모든 즐겨찾기 가져오기
    func getFavorites(userId: String) async throws -> [String] {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("favorites")
            .getDocuments()

        return snapshot.documents.map { $0.documentID }
    }

    // MARK: - User Persons (제한 식품 관리)

    /// 사용자의 인물 추가
    func addPerson(userId: String, person: Person) async throws {
        let personData: [String: Any] = [
            "name": person.name,
            "restrictedIngredients": person.restrictedIngredients,
            "createdAt": Timestamp(date: Date())
        ]

        try await db.collection("users")
            .document(userId)
            .collection("persons")
            .document(person.id)
            .setData(personData)
    }

    /// 사용자의 인물 목록 가져오기
    func getPersons(userId: String) async throws -> [Person] {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("persons")
            .getDocuments()

        return snapshot.documents.compactMap { document in
            guard let name = document.data()["name"] as? String,
                  let restrictedIngredients = document.data()["restrictedIngredients"] as? [String] else {
                return nil
            }
            return Person(
                id: document.documentID,
                name: name,
                restrictedIngredients: restrictedIngredients
            )
        }
    }

    /// 사용자의 인물 삭제
    func deletePerson(userId: String, personId: String) async throws {
        try await db.collection("users")
            .document(userId)
            .collection("persons")
            .document(personId)
            .delete()
    }

    /// 사용자의 인물 업데이트
    func updatePerson(userId: String, person: Person) async throws {
        let personData: [String: Any] = [
            "name": person.name,
            "restrictedIngredients": person.restrictedIngredients,
            "updatedAt": Timestamp(date: Date())
        ]

        try await db.collection("users")
            .document(userId)
            .collection("persons")
            .document(person.id)
            .updateData(personData)
    }

    // MARK: - Restaurant Cache (네이버 검색 결과 캐싱)

    /// 식당 정보 캐시에 저장
    func cacheRestaurant(_ restaurant: Restaurant) async throws {
        let restaurantData: [String: Any] = [
            "name": restaurant.name,
            "category": restaurant.category,
            "rating": restaurant.rating,
            "distance": restaurant.distance,
            "address": restaurant.address,
            "operatingStatus": restaurant.operatingStatus,
            "totalMenuCount": restaurant.totalMenuCount,
            "imageUrl": restaurant.imageUrl as Any,
            "cachedAt": Timestamp(date: Date())
        ]

        try await db.collection("restaurants")
            .document(restaurant.id)
            .setData(restaurantData, merge: true)
    }

    /// 캐시된 식당 정보 가져오기
    func getCachedRestaurant(restaurantId: String) async throws -> Restaurant? {
        let document = try await db.collection("restaurants")
            .document(restaurantId)
            .getDocument()

        guard document.exists,
              let data = document.data(),
              let name = data["name"] as? String,
              let category = data["category"] as? String,
              let rating = data["rating"] as? Double,
              let distance = data["distance"] as? String,
              let address = data["address"] as? String,
              let operatingStatus = data["operatingStatus"] as? String,
              let totalMenuCount = data["totalMenuCount"] as? Int else {
            return nil
        }

        return Restaurant(
            id: document.documentID,
            name: name,
            category: category,
            rating: rating,
            distance: distance,
            address: address,
            operatingStatus: operatingStatus,
            operatingHours: [], // TODO: 영업시간 저장 로직 추가
            totalMenuCount: totalMenuCount,
            imageUrl: data["imageUrl"] as? String
        )
    }
}
