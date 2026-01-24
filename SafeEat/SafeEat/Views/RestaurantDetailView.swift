//
//  RestaurantDetailView.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//  Redesigned to match Figma design

import SwiftUI

struct RestaurantDetailView: View {
    @StateObject private var viewModel = RestaurantDetailViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // 네비게이션 바
            NavigationBar(restaurantName: viewModel.restaurant.name, category: viewModel.restaurant.category)

            ScrollView {
                VStack(spacing: 0) {
                    // 이미지 갤러리
                    ImageGallery()

                    // 위치 정보 - 흰색 배경으로 완전 분리
                    VStack(spacing: 0) {
                        LocationSection(
                            rating: viewModel.restaurant.rating,
                            distance: viewModel.restaurant.distance
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                        // 영업시간
                        OperatingHoursSection(
                            status: viewModel.restaurant.operatingStatus,
                            hours: viewModel.restaurant.operatingHours,
                            isExpanded: $viewModel.isOperatingHoursExpanded
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                        Divider()
                            .background(Color(hex: "F5F5F5"))
                            .padding(.top, 20)

                        // 메뉴 섹션
                        MenuSection(viewModel: viewModel)
                            .padding(.top, 20)
                    }
                    .background(Color.white)
                }
            }
        }
        .background(Color.white)
        .navigationBarHidden(true)
    }
}

// MARK: - Navigation Bar
struct NavigationBar: View {
    let restaurantName: String
    let category: String

    var body: some View {
        HStack(spacing: 12) {
            // 뒤로가기
            Button(action: {}) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.safeEatPrimary)
            }

            // 식당명 + 카테고리
            VStack(alignment: .leading, spacing: 2) {
                Text(restaurantName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.safeEatPrimary)

                Text(category)
                    .font(.system(size: 12))
                    .foregroundColor(.safeEatTextSecondary)
            }

            Spacer()

            // 하트
            Button(action: {}) {
                Image(systemName: "heart")
                    .font(.system(size: 18))
                    .foregroundColor(.safeEatTextSecondary)
            }

            // 전화 버튼
            Button(action: {}) {
                HStack(spacing: 4) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 11))
                    Text("전화")
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
        .padding(.vertical, 12)
        .background(Color.white)
    }
}

// MARK: - Image Gallery
struct ImageGallery: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let imageSize = width / 2

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: imageSize, height: imageSize)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 30))
                                .foregroundColor(.gray.opacity(0.3))
                        )

                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: imageSize, height: imageSize)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 30))
                                .foregroundColor(.gray.opacity(0.3))
                        )
                }

                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: imageSize, height: imageSize)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 30))
                                .foregroundColor(.gray.opacity(0.3))
                        )

                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: imageSize, height: imageSize)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 30))
                                .foregroundColor(.gray.opacity(0.3))
                        )
                }
            }
        }
        .frame(height: 280)
    }
}

// MARK: - Location Section
struct LocationSection: View {
    let rating: Double
    let distance: String

    var body: some View {
        HStack(spacing: 12) {
            // 위치 아이콘
            Image(systemName: "location.fill")
                .font(.system(size: 18))
                .foregroundColor(.safeEatTextSecondary)

            // 평점 뱃지
            HStack(spacing: 4) {
                Text("\(Int(rating))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.safeEatPrimary)
            .cornerRadius(12)

            // 거리
            Text(distance)
                .font(.system(size: 14))
                .foregroundColor(.safeEatTextPrimary)

            Spacer()

            // 지도로 확인하기
            Button(action: {}) {
                HStack(spacing: 4) {
                    Image(systemName: "map")
                        .font(.system(size: 11))
                    Text("지도로 확인하기")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.safeEatPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.safeEatPrimary, lineWidth: 1)
                )
            }
        }
    }
}

// MARK: - Operating Hours Section
struct OperatingHoursSection: View {
    let status: String
    let hours: [DayOperatingHours]
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { isExpanded.toggle() }) {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 16))
                        .foregroundColor(.safeEatTextSecondary)

                    Text(status)
                        .font(.system(size: 14))
                        .foregroundColor(.safeEatTextPrimary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.safeEatTextSecondary)
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(hours) { dayHours in
                        HStack(alignment: .top, spacing: 8) {
                            Text(dayHours.day)
                                .font(.system(size: 13))
                                .foregroundColor(.safeEatTextPrimary)
                                .frame(width: 20, alignment: .leading)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(dayHours.hours)
                                    .font(.system(size: 13))
                                    .foregroundColor(.safeEatTextPrimary)

                                if let breakTime = dayHours.breakTime {
                                    Text(breakTime)
                                        .font(.system(size: 12))
                                        .foregroundColor(.safeEatTextSecondary)
                                }

                                Text(dayHours.lastOrder)
                                    .font(.system(size: 12))
                                    .foregroundColor(.safeEatTextSecondary)
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }
}

// MARK: - Menu Section
struct MenuSection: View {
    @ObservedObject var viewModel: RestaurantDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 탭 헤더
            MenuTabs(
                selectedTab: $viewModel.selectedMenuTab,
                safeMenuCount: viewModel.totalSafeMenuCount,
                otherMenuCount: viewModel.restaurant.totalMenuCount
            )

            // 경고 메시지
            Text("브로가 항상 정확하진 않을 수 있어요. 확실한 확인을 위해 꼭 매장에 직접 문의해보세요.")
                .font(.system(size: 12))
                .foregroundColor(.safeEatTextSecondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.white)

            // 안전한 메뉴 탭 내용
            if viewModel.selectedMenuTab == .safe {
                VStack(spacing: 0) {
                    ForEach(viewModel.safeMenuInfos) { safeMenuInfo in
                        PersonSafeMenuSection(safeMenuInfo: safeMenuInfo)
                    }
                }
                .padding(.bottom, 32)
            }
        }
    }
}

// MARK: - Menu Tabs
struct MenuTabs: View {
    @Binding var selectedTab: MenuTab
    let safeMenuCount: Int
    let otherMenuCount: Int

    var body: some View {
        HStack(spacing: 0) {
            // 안전한 메뉴 탭
            TabButton(
                title: "안전한 메뉴",
                count: safeMenuCount,
                isSelected: selectedTab == .safe,
                action: { selectedTab = .safe }
            )

            // 그 외 메뉴 탭
            TabButton(
                title: "그 외 메뉴",
                count: otherMenuCount,
                isSelected: selectedTab == .other,
                action: { selectedTab = .other }
            )
        }
        .padding(.horizontal, 20)
    }
}

struct TabButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    Text("총 \(count)개")
                        .font(.system(size: 12))
                }
                .foregroundColor(isSelected ? .safeEatPrimary : .safeEatTextSecondary)

                Rectangle()
                    .fill(isSelected ? Color.safeEatPrimary : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Person Safe Menu Section
struct PersonSafeMenuSection: View {
    let safeMenuInfo: SafeMenuInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 위쪽 구분선
            Divider()
                .background(Color(hex: "EEEEEE"))

            // 헤더
            HStack {
                Text("\(safeMenuInfo.person.name) 님에게 안전한 메뉴")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.safeEatPrimary)

                Spacer()

                Text("총 \(safeMenuInfo.safeMenuCount)개")
                    .font(.system(size: 12))
                    .foregroundColor(.safeEatTextSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            // 메뉴 리스트
            VStack(spacing: 20) {
                ForEach(safeMenuInfo.safeMenus) { menu in
                    MenuCard(menu: menu)
                        .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 20)

            // 아래쪽 구분선
            Divider()
                .background(Color(hex: "EEEEEE"))
        }
    }
}

// MARK: - Menu Card
struct MenuCard: View {
    let menu: Menu

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 메뉴 이미지
            Rectangle()
                .fill(Color.gray.opacity(0.15))
                .frame(width: 90, height: 90)
                .cornerRadius(8)
                .overlay(
                    Image(systemName: "fork.knife")
                        .font(.system(size: 24))
                        .foregroundColor(.gray.opacity(0.3))
                )

            // 메뉴 정보
            VStack(alignment: .leading, spacing: 8) {
                Text(menu.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.safeEatTextPrimary)

                Text("\(menu.price.formatted())원")
                    .font(.system(size: 14))
                    .foregroundColor(.safeEatTextPrimary)

                // 확률 태그들 - 가로 스크롤
                if !menu.probabilityTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(menu.probabilityTags, id: \.self) { tag in
                                ProbabilityTag(text: tag)
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Probability Tag
struct ProbabilityTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundColor(.safeEatPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.safeEatPrimary.opacity(0.1))
            .cornerRadius(12)
    }
}

// MARK: - Flow Layout (for tags)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct RestaurantDetailView_Previews: PreviewProvider {
    static var previews: some View {
        RestaurantDetailView()
    }
}
