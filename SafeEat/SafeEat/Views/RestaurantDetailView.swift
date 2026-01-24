//
//  RestaurantDetailView.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//

import SwiftUI

struct RestaurantDetailView: View {
    @StateObject private var viewModel = RestaurantDetailViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 식당 헤더
                RestaurantHeaderView(restaurant: viewModel.restaurant)

                // 영업 시간 섹션
                OperatingHoursSection(
                    restaurant: viewModel.restaurant,
                    isExpanded: viewModel.isOperatingHoursExpanded,
                    onToggle: { viewModel.toggleOperatingHours() }
                )
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // 지도로 확인하기 버튼
                MapButton()
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                // 메뉴 섹션
                MenuSection(viewModel: viewModel)
                    .padding(.top, 24)

                // 경고 메시지
                WarningMessage()
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
            }
        }
        .background(Color.safeEatBackground)
    }
}

// MARK: - Restaurant Header
struct RestaurantHeaderView: View {
    let restaurant: Restaurant

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(restaurant.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.safeEatTextPrimary)

                Spacer()

                // 별점
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.safeEatPrimary)
                    Text(String(format: "%.1f", restaurant.rating))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.safeEatTextPrimary)
                }
            }

            Text(restaurant.category)
                .font(.system(size: 14))
                .foregroundColor(.safeEatTextSecondary)

            Text(restaurant.distance)
                .font(.system(size: 12))
                .foregroundColor(.safeEatTextSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }
}

// MARK: - Operating Hours Section
struct OperatingHoursSection: View {
    let restaurant: Restaurant
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onToggle) {
                HStack {
                    Text(restaurant.operatingStatus)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.safeEatPrimary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.safeEatPrimary)
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(restaurant.operatingHours) { dayHours in
                        HStack(alignment: .top, spacing: 12) {
                            Text(dayHours.day)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.safeEatTextPrimary)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(dayHours.hours)
                                    .font(.system(size: 13))
                                    .foregroundColor(.safeEatTextPrimary)

                                if let breakTime = dayHours.breakTime {
                                    Text(breakTime)
                                        .font(.system(size: 11))
                                        .foregroundColor(.safeEatTextSecondary)
                                }

                                Text(dayHours.lastOrder)
                                    .font(.system(size: 11))
                                    .foregroundColor(.safeEatTextSecondary)
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.safeEatCardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Map Button
struct MapButton: View {
    var body: some View {
        Button(action: {
            // 지도로 이동
        }) {
            Text("지도로 확인하기")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.safeEatPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.safeEatPrimary, lineWidth: 1)
                )
        }
    }
}

// MARK: - Menu Section
struct MenuSection: View {
    @ObservedObject var viewModel: RestaurantDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 메뉴 헤더
            HStack {
                Text("메뉴")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.safeEatTextPrimary)

                Spacer()

                Text("총 \(viewModel.restaurant.totalMenuCount)개")
                    .font(.system(size: 13))
                    .foregroundColor(.safeEatTextSecondary)
            }
            .padding(.horizontal, 20)

            // 인물별 안전한 메뉴
            ForEach(viewModel.safeMenuInfos) { safeMenuInfo in
                PersonSafeMenuCard(
                    safeMenuInfo: safeMenuInfo,
                    isExpanded: viewModel.isPersonMenuExpanded(personId: safeMenuInfo.person.id),
                    onToggle: {
                        viewModel.togglePersonMenuExpansion(personId: safeMenuInfo.person.id)
                    }
                )
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Person Safe Menu Card
struct PersonSafeMenuCard: View {
    let safeMenuInfo: SafeMenuInfo
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onToggle) {
                HStack {
                    Text("\(safeMenuInfo.person.name) 님에게 안전한 메뉴")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.safeEatTextPrimary)

                    Spacer()

                    Text("총 \(safeMenuInfo.safeMenuCount)개")
                        .font(.system(size: 13))
                        .foregroundColor(.safeEatTextSecondary)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.safeEatTextSecondary)
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(safeMenuInfo.safeMenus) { menu in
                        MenuItemRow(menu: menu)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.safeEatCardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Menu Item Row
struct MenuItemRow: View {
    let menu: Menu

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 메뉴 이미지 플레이스홀더
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.safeEatCardBorder.opacity(0.3))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "fork.knife")
                        .font(.system(size: 20))
                        .foregroundColor(.safeEatTextSecondary)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(menu.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.safeEatTextPrimary)

                if let description = menu.description {
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(.safeEatTextSecondary)
                        .lineLimit(2)
                }

                Text("\(menu.price)원")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.safeEatPrimary)
            }

            Spacer()
        }
    }
}

// MARK: - Warning Message
struct WarningMessage: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundColor(.safeEatTextSecondary)

            Text("브로가 항상 정확하진 않을 수 있어요. 확실한 확인을 위해 꼭 매장에 직접 문의해보세요.")
                .font(.system(size: 12))
                .foregroundColor(.safeEatTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.safeEatCardBorder.opacity(0.2))
        .cornerRadius(8)
    }
}

#Preview {
    RestaurantDetailView()
}
