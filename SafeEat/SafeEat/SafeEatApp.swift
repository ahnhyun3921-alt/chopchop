//
//  SafeEatApp.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//

import SwiftUI
// Firebase는 나중에 설치 후 활성화
// import FirebaseCore

@main
struct SafeEatApp: App {
    @StateObject private var authService = AuthenticationService()

    // Firebase 초기화 (임시 비활성화)
    init() {
        // Firebase SDK 설치 후 활성화
        // FirebaseApp.configure()

        // 네이버 지도 초기화 (CocoaPods 설치 후 활성화)
        // NMFAuthManager.shared().clientId = "YOUR_CLIENT_ID"
    }

    var body: some Scene {
        WindowGroup {
            // Firebase 로그인 없이 바로 메인 화면으로
            // TODO: Firebase 설치 후 로그인 기능 활성화
            MainTabView()
                .environmentObject(authService)
        }
    }
}
