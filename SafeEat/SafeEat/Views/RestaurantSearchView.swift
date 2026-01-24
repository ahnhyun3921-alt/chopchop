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
    @State private var sheetHeight: CGFloat = 200 // 하단 시트 높이
    @State private var isDragging = false

    let minSheetHeight: CGFloat = 200
    let maxSheetHeight: CGFloat = 600

    var body: some View {
        ZStack {
            // 전체 화면 지도
            KakaoMapView(
                restaurants: $viewModel.restaurants,
                selectedRestaurant: $viewModel.selectedRestaurant,
                currentLocation: locationManager.currentLocation,
                mapCenter: $viewModel.mapCenter
            )
            .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // 상단 검색 바 (floating)
                VStack(spacing: 12) {
                    SearchBar(text: $searchText, onSearch: {
                        Task {
                            await viewModel.searchRestaurants(
                                keyword: searchText,
                                location: locationManager.currentLocation
                            )
                        }
                    })

                    // 현재 위치 버튼
                    HStack {
                        Spacer()
                        Button(action: {
                            Task {
                                await viewModel.searchNearbyRestaurants(
                                    location: locationManager.currentLocation
                                )
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 13))
                                Text("주변 검색")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.safeEatPrimary)
                            .cornerRadius(24)
                            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                        }
                    }
                }
                .padding()
                .background(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 8, y: 2)

                Spacer()

                // 하단 리스트 시트
                VStack(spacing: 0) {
                    // 드래그 핸들
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 5)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                    // 로딩 또는 에러 상태
                    if viewModel.isLoading {
                        VStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .safeEatPrimary))
                                .padding(.top, 40)
                            Spacer()
                        }
                        .frame(height: sheetHeight - 25)
                    } else if let error = viewModel.errorMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 36))
                                .foregroundColor(.safeEatTextSecondary)
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(.safeEatTextSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(height: sheetHeight - 25)
                    } else if viewModel.restaurants.isEmpty {
                        // 검색 결과 없음 또는 초기 상태
                        VStack(spacing: 12) {
                            Image(systemName: viewModel.hasSearched ? "magnifyingglass" : "location.circle")
                                .font(.system(size: 36))
                                .foregroundColor(.safeEatTextSecondary)
                            Text(viewModel.hasSearched ? "검색 결과가 없습니다" : "주변 검색 버튼을 눌러\n가까운 식당을 찾아보세요")
                                .font(.system(size: 14))
                                .foregroundColor(.safeEatTextSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(height: sheetHeight - 25)
                    } else {
                        // 리스트
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(viewModel.restaurants) { restaurant in
                                    NavigationLink(destination: RestaurantDetailView(restaurant: restaurant)) {
                                        RestaurantSearchCard(restaurant: restaurant)
                                            .onTapGesture {
                                                viewModel.selectedRestaurant = restaurant
                                                viewModel.mapCenter = restaurant.coordinate
                                            }
                                    }
                                    .buttonStyle(PlainButtonStyle())

                                    Divider()
                                        .background(Color(hex: "#EEEEEE"))
                                }
                            }
                        }
                        .frame(height: sheetHeight - 25)
                    }
                }
                .frame(height: sheetHeight)
                .background(Color.white)
                .cornerRadius(20, corners: [.topLeft, .topRight])
                .shadow(color: .black.opacity(0.1), radius: 10, y: -2)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            let newHeight = sheetHeight - value.translation.height
                            sheetHeight = min(max(newHeight, minSheetHeight), maxSheetHeight)
                        }
                        .onEnded { _ in
                            isDragging = false
                            // 스냅 효과
                            withAnimation(.spring()) {
                                if sheetHeight < (minSheetHeight + maxSheetHeight) / 2 {
                                    sheetHeight = minSheetHeight
                                } else {
                                    sheetHeight = maxSheetHeight
                                }
                            }
                        }
                )
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            locationManager.requestLocation()
        }
        .onChange(of: locationManager.currentLocation) { newLocation in
            // 위치를 처음 받았을 때만 자동으로 주변 검색
            if newLocation != nil && viewModel.restaurants.isEmpty && !viewModel.hasSearched {
                Task {
                    await viewModel.searchNearbyRestaurants(location: newLocation)
                }
            }
        }
    }
}

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
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
                .font(.system(size: 16))

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
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(12)
    }
}

// MARK: - Restaurant Search Card
struct RestaurantSearchCard: View {
    let restaurant: Restaurant

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 식당 이미지
            Rectangle()
                .fill(Color.gray.opacity(0.12))
                .frame(width: 70, height: 70)
                .cornerRadius(8)
                .overlay(
                    Image(systemName: "fork.knife")
                        .foregroundColor(.gray.opacity(0.4))
                        .font(.system(size: 20))
                )

            // 식당 정보
            VStack(alignment: .leading, spacing: 5) {
                Text(restaurant.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.safeEatTextPrimary)
                    .lineLimit(1)

                Text(restaurant.category)
                    .font(.system(size: 12))
                    .foregroundColor(.safeEatTextSecondary)

                if !restaurant.distance.isEmpty {
                    Text(restaurant.distance)
                        .font(.system(size: 12))
                        .foregroundColor(.safeEatTextSecondary)
                }

                Text(restaurant.address)
                    .font(.system(size: 11))
                    .foregroundColor(.safeEatTextSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // 화살표
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.safeEatTextSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.white)
    }
}

// MARK: - View Model
@MainActor
class RestaurantSearchViewModel: ObservableObject {
    @Published var restaurants: [Restaurant] = []
    @Published var selectedRestaurant: Restaurant?
    @Published var mapCenter: CLLocationCoordinate2D?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasSearched = false

    private let kakaoService = KakaoLocalService.shared

    func searchRestaurants(keyword: String, location: CLLocationCoordinate2D?) async {
        guard !keyword.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        hasSearched = true

        do {
            let response = try await kakaoService.searchKeyword(
                query: keyword,
                location: location,
                radius: 5000,
                size: 15
            )

            restaurants = response.documents.map { $0.toRestaurant() }

            // 검색 결과 첫 번째 위치로 지도 이동
            if let first = restaurants.first, let coord = first.coordinate {
                mapCenter = coord
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
        hasSearched = true
        mapCenter = location

        do {
            let response = try await kakaoService.searchByCategory(
                categoryCode: "FD6",
                location: location,
                radius: 2000,
                size: 15
            )

            restaurants = response.documents.map { $0.toRestaurant() }

            isLoading = false
        } catch {
            errorMessage = "주변 검색 중 오류가 발생했습니다: \(error.localizedDescription)"
            isLoading = false
        }
    }
}

struct RestaurantSearchView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            RestaurantSearchView()
        }
    }
}
