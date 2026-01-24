//
//  SafeEatApp.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//

import SwiftUI
// Firebase는 나중에 설치 후 활성화
// import FirebaseCore
// KakaoMapsSDK는 SPM 설치 후 활성화
// import KakaoMapsSDK

@main
struct SafeEatApp: App {
    @StateObject private var authService = AuthenticationService()

    // Firebase 초기화 (임시 비활성화)
    init() {
        // Firebase SDK 설치 후 활성화
        // FirebaseApp.configure()

        // 카카오 지도 초기화 (SPM 설치 후 활성화)
        // SPM으로 https://github.com/kakao-mapsSDK/KakaoMapsSDK-SPM 추가 후 활성화
        // SDKInitializer.InitSDK(appKey: Config.kakaoRestAPIKey)
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
