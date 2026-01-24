//
//  RestaurantSearchView.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//

import SwiftUI
import CoreLocation

struct RestaurantSearchView: View {
    @StateObject private var viewModel = RestaurantSearchViewModel()
    @StateObject private var locationManager = LocationManager()
    @State private var searchText = ""
    @State private var showMap = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 검색 바
                SearchBar(text: $searchText, onSearch: {
                    Task {
                        await viewModel.searchRestaurants(
                            keyword: searchText,
                            location: locationManager.currentLocation
                        )
                    }
                })
                .padding()

                // 지도/리스트 전환 버튼
                HStack {
                    Button(action: { showMap = false }) {
                        Text("리스트")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(showMap ? .safeEatTextSecondary : .safeEatPrimary)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 20)
                            .background(showMap ? Color.clear : Color.safeEatPrimaryLight)
                            .cornerRadius(20)
                    }

                    Button(action: { showMap = true }) {
                        Text("지도")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(showMap ? .safeEatPrimary : .safeEatTextSecondary)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 20)
                            .background(showMap ? Color.safeEatPrimaryLight : Color.clear)
                            .cornerRadius(20)
                    }

                    Spacer()

                    // 현재 위치 버튼
                    Button(action: {
                        Task {
                            await viewModel.searchNearbyRestaurants(
                                location: locationManager.currentLocation
                            )
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 12))
                            Text("주변 검색")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.safeEatPrimary)
                        .cornerRadius(20)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                Divider()
                    .background(Color(hex: "#EEEEEE"))

                // 로딩 상태
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .safeEatPrimary))
                    Spacer()
                }
                // 에러 상태
                else if let error = viewModel.errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.safeEatTextSecondary)
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.safeEatTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                }
                // 결과 표시
                else if showMap {
                    KakaoMapView(
                        restaurants: $viewModel.restaurants,
                        selectedRestaurant: $viewModel.selectedRestaurant,
                        currentLocation: locationManager.currentLocation
                    )
                } else {
                    RestaurantListView(
                        restaurants: viewModel.restaurants,
                        selectedRestaurant: $viewModel.selectedRestaurant
                    )
                }
            }
            .navigationTitle("식당 검색")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            locationManager.requestPermission()
            locationManager.startUpdatingLocation()

            // 초기 검색 (주변 맛집)
            Task {
                await viewModel.searchNearbyRestaurants(
                    location: locationManager.currentLocation
                )
            }
        }
    }
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String
    var onSearch: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.safeEatTextSecondary)

            TextField("식당 이름이나 음식 종류를 검색하세요", text: $text)
                .font(.system(size: 15))
                .submitLabel(.search)
                .onSubmit {
                    onSearch()
                }

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.safeEatTextSecondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Restaurant List View

struct RestaurantListView: View {
    let restaurants: [Restaurant]
    @Binding var selectedRestaurant: Restaurant?

    var body: some View {
        if restaurants.isEmpty {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundColor(.safeEatTextSecondary)
                Text("검색 결과가 없습니다")
                    .font(.system(size: 16))
                    .foregroundColor(.safeEatTextSecondary)
                Text("다른 키워드로 검색해보세요")
                    .font(.system(size: 14))
                    .foregroundColor(.safeEatTextSecondary)
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(restaurants) { restaurant in
                        NavigationLink(destination: RestaurantDetailView(restaurant: restaurant)) {
                            RestaurantSearchCard(restaurant: restaurant)
                        }
                        .buttonStyle(PlainButtonStyle())

                        Divider()
                            .background(Color(hex: "#EEEEEE"))
                    }
                }
            }
        }
    }
}

// MARK: - Restaurant Search Card

struct RestaurantSearchCard: View {
    let restaurant: Restaurant

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 식당 이미지
            Rectangle()
                .fill(Color.gray.opacity(0.15))
                .frame(width: 80, height: 80)
                .cornerRadius(8)
                .overlay(
                    Image(systemName: "fork.knife")
                        .foregroundColor(.gray.opacity(0.5))
                )

            // 식당 정보
            VStack(alignment: .leading, spacing: 6) {
                Text(restaurant.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.safeEatTextPrimary)
                    .lineLimit(1)

                Text(restaurant.category)
                    .font(.system(size: 13))
                    .foregroundColor(.safeEatTextSecondary)

                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.safeEatPrimary)
                    Text(String(format: "%.1f", restaurant.rating))
                        .font(.system(size: 13))
                        .foregroundColor(.safeEatTextPrimary)

                    if !restaurant.distance.isEmpty {
                        Text("•")
                            .foregroundColor(.safeEatTextSecondary)
                        Text(restaurant.distance)
                            .font(.system(size: 13))
                            .foregroundColor(.safeEatTextSecondary)
                    }
                }

                Text(restaurant.address)
                    .font(.system(size: 12))
                    .foregroundColor(.safeEatTextSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // 화살표
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.safeEatTextSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white)
    }
}

// MARK: - View Model

@MainActor
class RestaurantSearchViewModel: ObservableObject {
    @Published var restaurants: [Restaurant] = []
    @Published var selectedRestaurant: Restaurant?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let kakaoService = KakaoLocalService.shared

    func searchRestaurants(keyword: String, location: CLLocationCoordinate2D?) async {
        guard !keyword.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            // Kakao Local API로 검색
            let response = try await kakaoService.searchKeyword(
                query: keyword,
                location: location,
                radius: 5000,  // 5km 반경
                size: 15
            )

            // Restaurant 모델로 변환
            restaurants = response.documents.map { place in
                var restaurant = place.toRestaurant()

                // 평점 랜덤 생성 (Kakao API는 평점 제공 안 함)
                restaurant = Restaurant(
                    id: restaurant.id,
                    name: restaurant.name,
                    category: restaurant.category,
                    rating: Double.random(in: 3.5...4.9),
                    distance: restaurant.distance,
                    address: restaurant.address,
                    operatingStatus: restaurant.operatingStatus,
                    operatingHours: restaurant.operatingHours,
                    totalMenuCount: restaurant.totalMenuCount,
                    imageUrl: restaurant.imageUrl,
                    phoneNumber: restaurant.phoneNumber,
                    latitude: restaurant.latitude,
                    longitude: restaurant.longitude
                )

                return restaurant
            }

            isLoading = false
        } catch {
            errorMessage = "검색 중 오류가 발생했습니다: \(error.localizedDescription)"
            isLoading = false
        }
    }

    func searchNearbyRestaurants(location: CLLocationCoordinate2D?) async {
        guard let location = location else {
            errorMessage = "위치 정보를 가져올 수 없습니다"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // Kakao Local API로 주변 식당 검색
            let response = try await kakaoService.searchByCategory(
                categoryCode: "FD6",  // 음식점
                location: location,
                radius: 2000,  // 2km 반경
                size: 15
            )

            // Restaurant 모델로 변환
            restaurants = response.documents.map { place in
                var restaurant = place.toRestaurant()

                // 평점 랜덤 생성
                restaurant = Restaurant(
                    id: restaurant.id,
                    name: restaurant.name,
                    category: restaurant.category,
                    rating: Double.random(in: 3.5...4.9),
                    distance: restaurant.distance,
                    address: restaurant.address,
                    operatingStatus: restaurant.operatingStatus,
                    operatingHours: restaurant.operatingHours,
                    totalMenuCount: restaurant.totalMenuCount,
                    imageUrl: restaurant.imageUrl,
                    phoneNumber: restaurant.phoneNumber,
                    latitude: restaurant.latitude,
                    longitude: restaurant.longitude
                )

                return restaurant
            }

            isLoading = false
        } catch {
            errorMessage = "주변 검색 중 오류가 발생했습니다: \(error.localizedDescription)"
            isLoading = false
        }
    }
}

struct RestaurantSearchView_Previews: PreviewProvider {
    static var previews: some View {
        RestaurantSearchView()
    }
}
