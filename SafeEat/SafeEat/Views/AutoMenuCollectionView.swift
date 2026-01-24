//
//  AutoMenuCollectionView.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//

import SwiftUI
import CoreLocation

struct AutoMenuCollectionView: View {
    @StateObject private var viewModel = AutoMenuCollectionViewModel()
    @StateObject private var locationManager = LocationManager()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.safeEatBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // 안내 메시지
                    VStack(spacing: 12) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 48))
                            .foregroundColor(.safeEatPrimary)

                        Text("자동 메뉴 수집")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.safeEatTextPrimary)

                        VStack(spacing: 4) {
                            Text("평촌 지역 식당의 메뉴를 자동으로 수집합니다")
                                .font(.system(size: 14))
                                .foregroundColor(.safeEatTextSecondary)

                            Text("구글 이미지 검색 + Apple Vision OCR (무료)")
                                .font(.system(size: 13))
                                .foregroundColor(.green)

                            Text("⚠️ 일일 할당량: 100회")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                        }
                        .multilineTextAlignment(.center)
                    }
                    .padding(.top, 32)

                    // 지역 선택
                    VStack(alignment: .leading, spacing: 12) {
                        Text("1. 수집 지역")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.safeEatTextPrimary)

                        HStack {
                            TextField("예: 평촌", text: $viewModel.locationQuery)
                                .font(.system(size: 15))
                                .textFieldStyle(RoundedBorderTextFieldStyle())

                            Button(action: {
                                Task {
                                    await viewModel.searchRestaurants(location: locationManager.currentLocation)
                                }
                            }) {
                                Text("검색")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(Color.safeEatPrimary)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // 검색된 식당 목록
                    if !viewModel.restaurants.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("2. 식당 선택 (\(viewModel.selectedRestaurants.count)/\(viewModel.restaurants.count))")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.safeEatTextPrimary)

                                Spacer()

                                Button(action: {
                                    if viewModel.selectedRestaurants.count == viewModel.restaurants.count {
                                        viewModel.selectedRestaurants.removeAll()
                                    } else {
                                        viewModel.selectedRestaurants = Set(viewModel.restaurants.map { $0.id })
                                    }
                                }) {
                                    Text(viewModel.selectedRestaurants.count == viewModel.restaurants.count ? "전체 해제" : "전체 선택")
                                        .font(.system(size: 13))
                                        .foregroundColor(.safeEatPrimary)
                                }
                            }

                            ForEach(viewModel.restaurants) { restaurant in
                                RestaurantCheckRow(
                                    restaurant: restaurant,
                                    isSelected: viewModel.selectedRestaurants.contains(restaurant.id),
                                    onToggle: {
                                        if viewModel.selectedRestaurants.contains(restaurant.id) {
                                            viewModel.selectedRestaurants.remove(restaurant.id)
                                        } else {
                                            viewModel.selectedRestaurants.insert(restaurant.id)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }

                    // 수집 시작 버튼
                    if !viewModel.selectedRestaurants.isEmpty && !viewModel.isCollecting {
                        Button(action: {
                            Task {
                                await viewModel.startAutoCollection()
                            }
                        }) {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                Text("메뉴 자동 수집 시작 (\(viewModel.selectedRestaurants.count)개 식당)")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }

                    // 진행 상황
                    if viewModel.isCollecting {
                        VStack(spacing: 16) {
                            ProgressView(value: viewModel.progress, total: Double(viewModel.selectedRestaurants.count))
                                .progressViewStyle(LinearProgressViewStyle(tint: .safeEatPrimary))

                            VStack(spacing: 8) {
                                Text("\(viewModel.currentRestaurantName)")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.safeEatTextPrimary)

                                Text("\(Int(viewModel.progress))/\(viewModel.selectedRestaurants.count) 완료")
                                    .font(.system(size: 13))
                                    .foregroundColor(.safeEatTextSecondary)

                                if viewModel.totalMenusCollected > 0 {
                                    Text("총 \(viewModel.totalMenusCollected)개 메뉴 수집됨")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // 수집 결과
                    if !viewModel.collectionResults.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("수집 결과")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.safeEatTextPrimary)

                            ForEach(viewModel.collectionResults, id: \.restaurantName) { result in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(result.restaurantName)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.safeEatTextPrimary)

                                        if result.success {
                                            Text("✅ \(result.menuCount)개 메뉴 수집")
                                                .font(.system(size: 12))
                                                .foregroundColor(.green)
                                        } else {
                                            Text("❌ \(result.errorMessage ?? "실패")")
                                                .font(.system(size: 12))
                                                .foregroundColor(.red)
                                        }
                                    }

                                    Spacer()
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // 에러 메시지
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("자동 메뉴 수집")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            locationManager.requestLocation()
        }
        .alert("법적 고지", isPresented: $viewModel.showLegalWarning) {
            Button("취소", role: .cancel) { }
            Button("동의하고 계속") {
                viewModel.acceptLegalWarning()
            }
        } message: {
            Text("⚠️ 이 기능은 구글 이미지 검색을 사용합니다.\n\n- 메뉴판 이미지는 즉시 삭제되며 텍스트만 저장됩니다\n- 개인 용도로만 사용하세요\n- 일일 할당량: 100회\n- 상업적 사용 금지")
        }
    }
}

// MARK: - Restaurant Check Row
struct RestaurantCheckRow: View {
    let restaurant: Restaurant
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .safeEatPrimary : .gray.opacity(0.3))
                    .font(.system(size: 20))

                VStack(alignment: .leading, spacing: 4) {
                    Text(restaurant.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.safeEatTextPrimary)

                    Text(restaurant.category)
                        .font(.system(size: 12))
                        .foregroundColor(.safeEatTextSecondary)
                }

                Spacer()
            }
            .padding()
            .background(Color.white)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - View Model
@MainActor
class AutoMenuCollectionViewModel: ObservableObject {
    @Published var locationQuery = "평촌"
    @Published var restaurants: [Restaurant] = []
    @Published var selectedRestaurants = Set<String>()
    @Published var isCollecting = false
    @Published var progress: Double = 0
    @Published var currentRestaurantName = ""
    @Published var totalMenusCollected = 0
    @Published var collectionResults: [CollectionResult] = []
    @Published var errorMessage: String?
    @Published var showLegalWarning = false

    private let kakaoService = KakaoLocalService.shared
    private let googleService = GoogleSearchService.shared
    private let firestoreService = FirestoreService.shared
    private var hasAcceptedWarning = false

    func searchRestaurants(location: CLLocationCoordinate2D?) async {
        guard !locationQuery.isEmpty else { return }

        errorMessage = nil

        do {
            // 키워드로 식당 검색
            let response = try await kakaoService.searchKeyword(
                query: "\(locationQuery) 맛집",
                location: location,
                radius: 5000,
                size: 15
            )

            restaurants = response.documents.map { $0.toRestaurant() }
        } catch {
            errorMessage = "식당 검색 실패: \(error.localizedDescription)"
        }
    }

    func startAutoCollection() async {
        // 법적 경고 표시
        if !hasAcceptedWarning {
            showLegalWarning = true
            return
        }

        isCollecting = true
        progress = 0
        totalMenusCollected = 0
        collectionResults = []
        errorMessage = nil

        let selectedRestaurantList = restaurants.filter { selectedRestaurants.contains($0.id) }

        for (index, restaurant) in selectedRestaurantList.enumerated() {
            currentRestaurantName = restaurant.name

            do {
                // 구글 이미지 검색 + OCR로 메뉴 자동 추출
                let menus = try await googleService.autoExtractMenus(from: restaurant)

                // Firestore에 저장
                for menu in menus {
                    try await firestoreService.addMenu(menu)
                }

                // 결과 기록
                collectionResults.append(CollectionResult(
                    restaurantName: restaurant.name,
                    success: true,
                    menuCount: menus.count,
                    errorMessage: nil
                ))

                totalMenusCollected += menus.count

            } catch let error as GoogleSearchError {
                collectionResults.append(CollectionResult(
                    restaurantName: restaurant.name,
                    success: false,
                    menuCount: 0,
                    errorMessage: error.localizedDescription
                ))

                // 할당량 초과 시 중단
                if case .quotaExceeded = error {
                    errorMessage = "구글 API 일일 할당량(100회)을 초과했습니다. 내일 다시 시도하세요."
                    break
                }
            } catch {
                collectionResults.append(CollectionResult(
                    restaurantName: restaurant.name,
                    success: false,
                    menuCount: 0,
                    errorMessage: error.localizedDescription
                ))
            }

            progress = Double(index + 1)

            // 다음 요청 전 딜레이 (API 제한 방지)
            try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1초
        }

        isCollecting = false
        currentRestaurantName = ""
    }

    func acceptLegalWarning() {
        hasAcceptedWarning = true
        Task {
            await startAutoCollection()
        }
    }
}

struct CollectionResult {
    let restaurantName: String
    let success: Bool
    let menuCount: Int
    let errorMessage: String?
}

struct AutoMenuCollectionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AutoMenuCollectionView()
        }
    }
}
