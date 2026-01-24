//
//  MainTabView.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @StateObject private var favoritesViewModel = FavoritesViewModel()

    var body: some View {
        TabView(selection: $selectedTab) {
            // 홈 (검색)
            RestaurantSearchView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "magnifyingglass.circle.fill" : "magnifyingglass.circle")
                    Text("검색")
                }
                .tag(0)
                .environmentObject(favoritesViewModel)

            // 즐겨찾기
            FavoritesView()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "heart.fill" : "heart")
                    Text("즐겨찾기")
                }
                .tag(1)
                .environmentObject(favoritesViewModel)

            // 인물 관리
            PersonManagementView()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "person.2.fill" : "person.2")
                    Text("인물")
                }
                .tag(2)

            // 프로필
            ProfileView()
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "person.circle.fill" : "person.circle")
                    Text("프로필")
                }
                .tag(3)
        }
        .accentColor(.safeEatPrimary)
    }
}

// MARK: - Profile View

struct ProfileView: View {
    @EnvironmentObject var authService: AuthenticationService

    var body: some View {
        NavigationView {
            ZStack {
                Color.safeEatBackground.ignoresSafeArea()

                List {
                    // 프로필 헤더
                    Section {
                        HStack(spacing: 16) {
                            Circle()
                                .fill(Color.safeEatPrimary.opacity(0.15))
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(.safeEatPrimary)
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                if let user = authService.user {
                                    Text(user.displayName ?? "사용자")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.safeEatTextPrimary)

                                    Text(user.email ?? "")
                                        .font(.system(size: 14))
                                        .foregroundColor(.safeEatTextSecondary)
                                } else {
                                    Text("로그인이 필요합니다")
                                        .font(.system(size: 16))
                                        .foregroundColor(.safeEatTextSecondary)
                                }
                            }

                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }

                    // 설정
                    Section {
                        NavigationLink(destination: Text("알림 설정")) {
                            SettingRow(icon: "bell.fill", title: "알림 설정")
                        }

                        NavigationLink(destination: Text("언어 설정")) {
                            SettingRow(icon: "globe", title: "언어")
                        }

                        NavigationLink(destination: Text("개인정보 처리방침")) {
                            SettingRow(icon: "hand.raised.fill", title: "개인정보 처리방침")
                        }

                        NavigationLink(destination: Text("서비스 이용약관")) {
                            SettingRow(icon: "doc.text.fill", title: "서비스 이용약관")
                        }
                    } header: {
                        Text("설정")
                    }

                    // 앱 정보
                    Section {
                        HStack {
                            Text("버전")
                                .foregroundColor(.safeEatTextPrimary)
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(.safeEatTextSecondary)
                        }

                        NavigationLink(destination: Text("개발자 정보")) {
                            SettingRow(icon: "info.circle.fill", title: "앱 정보")
                        }
                    } header: {
                        Text("앱")
                    }

                    // 로그아웃
                    if authService.isAuthenticated {
                        Section {
                            Button(action: {
                                do {
                                    try authService.signOut()
                                } catch {
                                    print("로그아웃 실패: \(error.localizedDescription)")
                                }
                            }) {
                                HStack {
                                    Spacer()
                                    Text("로그아웃")
                                        .foregroundColor(.red)
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("프로필")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Setting Row

struct SettingRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.safeEatPrimary)
                .frame(width: 24)

            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.safeEatTextPrimary)
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(AuthenticationService())
    }
}
