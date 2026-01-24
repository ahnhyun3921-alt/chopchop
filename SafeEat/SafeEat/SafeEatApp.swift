//
//  SafeEatApp.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//

import SwiftUI
import FirebaseCore

@main
struct SafeEatApp: App {
    @StateObject private var authService = AuthenticationService()

    // Firebase 초기화
    init() {
        FirebaseApp.configure()
        // 네이버 지도 초기화 (Info.plist의 NMFClientId 사용)
        // NMFAuthManager.shared().clientId = "YOUR_CLIENT_ID"
    }

    var body: some Scene {
        WindowGroup {
            // 로그인 상태에 따라 화면 전환
            Group {
                if authService.isAuthenticated {
                    MainTabView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(authService)
        }
    }
}
