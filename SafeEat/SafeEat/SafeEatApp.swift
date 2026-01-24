//
//  SafeEatApp.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//

import SwiftUI
// Firebase는 나중에 설치 후 활성화
// import FirebaseCore
// KakaoMapsSDK는 설치 실패로 Apple MapKit 사용
// import KakaoMapsSDK_SPM

@main
struct SafeEatApp: App {
    @StateObject private var authService = AuthenticationService()

    init() {
        // Firebase SDK 설치 후 활성화
        // FirebaseApp.configure()

        // 카카오 맵 SDK 설치 실패로 Apple MapKit 사용
        // SDKInitializer.InitSDK(appKey: Config.kakaoNativeAppKey)
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
