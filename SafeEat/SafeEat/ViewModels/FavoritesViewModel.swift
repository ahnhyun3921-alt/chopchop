//
//  FavoritesViewModel.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//

import Foundation
import Combine

@MainActor
class FavoritesViewModel: ObservableObject {
    @Published var favoriteRestaurants: [Restaurant] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let firestoreService = FirestoreService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadFavorites()
    }

    /// 즐겨찾기 목록 불러오기
    func loadFavorites() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                // TODO: 실제 userId를 AuthenticationService에서 가져와야 함
                let userId = "temp_user_id"

                // 즐겨찾기한 식당 ID 목록 가져오기
                let favoriteIds = try await firestoreService.getFavorites(userId: userId)

                // 각 식당 정보 가져오기 (캐시에서)
                var restaurants: [Restaurant] = []
                for restaurantId in favoriteIds {
                    if let restaurant = try await firestoreService.getCachedRestaurant(restaurantId: restaurantId) {
                        restaurants.append(restaurant)
                    }
                }

                await MainActor.run {
                    self.favoriteRestaurants = restaurants
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "즐겨찾기 목록을 불러오는데 실패했습니다."
                    self.isLoading = false
                }
                print("즐겨찾기 로드 실패: \(error.localizedDescription)")
            }
        }
    }

    /// 즐겨찾기 제거
    func removeFavorite(restaurant: Restaurant) {
        Task {
            do {
                // TODO: 실제 userId를 AuthenticationService에서 가져와야 함
                let userId = "temp_user_id"

                try await firestoreService.removeFavorite(userId: userId, restaurantId: restaurant.id)

                // 로컬 목록에서도 제거
                await MainActor.run {
                    self.favoriteRestaurants.removeAll { $0.id == restaurant.id }
                }
            } catch {
                print("즐겨찾기 제거 실패: \(error.localizedDescription)")
            }
        }
    }

    /// 즐겨찾기 토글 (추가/제거)
    func toggleFavorite(restaurant: Restaurant) {
        let isFavorite = favoriteRestaurants.contains { $0.id == restaurant.id }

        if isFavorite {
            removeFavorite(restaurant: restaurant)
        } else {
            addFavorite(restaurant: restaurant)
        }
    }

    /// 즐겨찾기 추가
    private func addFavorite(restaurant: Restaurant) {
        Task {
            do {
                // TODO: 실제 userId를 AuthenticationService에서 가져와야 함
                let userId = "temp_user_id"

                // 즐겨찾기 추가 + 식당 정보 캐싱
                try await firestoreService.addFavorite(userId: userId, restaurantId: restaurant.id)
                try await firestoreService.cacheRestaurant(restaurant)

                // 로컬 목록에도 추가
                await MainActor.run {
                    if !self.favoriteRestaurants.contains(where: { $0.id == restaurant.id }) {
                        self.favoriteRestaurants.insert(restaurant, at: 0)
                    }
                }
            } catch {
                print("즐겨찾기 추가 실패: \(error.localizedDescription)")
            }
        }
    }

    /// 특정 식당이 즐겨찾기인지 확인
    func isFavorite(restaurantId: String) -> Bool {
        favoriteRestaurants.contains { $0.id == restaurantId }
    }
}
