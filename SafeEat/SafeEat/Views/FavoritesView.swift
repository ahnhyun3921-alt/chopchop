//
//  FavoritesView.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//

import SwiftUI

struct FavoritesView: View {
    @StateObject private var viewModel = FavoritesViewModel()
    @State private var selectedRestaurant: Restaurant?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 커스텀 네비게이션 바
                FavoritesNavigationBar()

                if viewModel.isLoading {
                    // 로딩 중
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Spacer()
                } else if viewModel.favoriteRestaurants.isEmpty {
                    // 즐겨찾기 없음
                    EmptyFavoritesView()
                } else {
                    // 즐겨찾기 목록
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(viewModel.favoriteRestaurants) { restaurant in
                                FavoriteRestaurantCard(
                                    restaurant: restaurant,
                                    isFavorite: viewModel.isFavorite(restaurantId: restaurant.id),
                                    onFavoriteToggle: {
                                        viewModel.removeFavorite(restaurant: restaurant)
                                    },
                                    onTap: {
                                        selectedRestaurant = restaurant
                                    }
                                )
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)

                                if restaurant.id != viewModel.favoriteRestaurants.last?.id {
                                    Divider()
                                        .background(Color(hex: "F5F5F5"))
                                        .padding(.horizontal, 20)
                                }
                            }
                        }
                        .padding(.top, 16)
                    }
                }
            }
            .background(Color.white)
            .navigationBarHidden(true)
            .sheet(item: $selectedRestaurant) { restaurant in
                RestaurantDetailView(restaurant: restaurant)
            }
        }
    }
}

// MARK: - Navigation Bar
struct FavoritesNavigationBar: View {
    var body: some View {
        HStack {
            Text("즐겨찾기")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.safeEatPrimary)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white)
        .overlay(
            Divider()
                .background(Color(hex: "F5F5F5")),
            alignment: .bottom
        )
    }
}

// MARK: - Empty State
struct EmptyFavoritesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "heart.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.3))

            Text("아직 즐겨찾기한 식당이 없어요")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.safeEatTextSecondary)

            Text("마음에 드는 식당을 찾아\n하트를 눌러보세요")
                .font(.system(size: 14))
                .foregroundColor(.safeEatTextSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
    }
}

// MARK: - Favorite Restaurant Card
struct FavoriteRestaurantCard: View {
    let restaurant: Restaurant
    let isFavorite: Bool
    let onFavoriteToggle: () -> Void
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // 식당 이미지
                if let imageUrl = restaurant.imageUrl {
                    AsyncImage(url: URL(string: imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.2)
                            .overlay(
                                Image(systemName: "fork.knife")
                                    .font(.system(size: 20))
                                    .foregroundColor(.gray.opacity(0.3))
                            )
                    }
                    .frame(width: 80, height: 80)
                    .cornerRadius(8)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 80, height: 80)
                        .cornerRadius(8)
                        .overlay(
                            Image(systemName: "fork.knife")
                                .font(.system(size: 20))
                                .foregroundColor(.gray.opacity(0.3))
                        )
                }

                // 식당 정보
                VStack(alignment: .leading, spacing: 6) {
                    // 식당명
                    Text(restaurant.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.safeEatTextPrimary)
                        .lineLimit(1)

                    // 카테고리
                    Text(restaurant.category)
                        .font(.system(size: 13))
                        .foregroundColor(.safeEatTextSecondary)

                    // 평점 & 거리
                    HStack(spacing: 6) {
                        if restaurant.rating > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.safeEatPrimary)
                                Text(String(format: "%.1f", restaurant.rating))
                                    .font(.system(size: 12))
                                    .foregroundColor(.safeEatTextPrimary)
                            }
                        }

                        if !restaurant.distance.isEmpty {
                            Text("•")
                                .font(.system(size: 12))
                                .foregroundColor(.safeEatTextSecondary)

                            Text(restaurant.distance)
                                .font(.system(size: 12))
                                .foregroundColor(.safeEatTextSecondary)
                        }
                    }

                    // 영업 상태
                    Text(restaurant.operatingStatus)
                        .font(.system(size: 12))
                        .foregroundColor(restaurant.operatingStatus.contains("영업 중") ? .green : .safeEatTextSecondary)
                }

                Spacer()

                // 하트 버튼
                Button(action: {
                    onFavoriteToggle()
                }) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 20))
                        .foregroundColor(isFavorite ? .safeEatPrimary : .safeEatTextSecondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
struct FavoritesView_Previews: PreviewProvider {
    static var previews: some View {
        FavoritesView()
    }
}
