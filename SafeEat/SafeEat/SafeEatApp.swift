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

    init() {
        // Firebase 초기화
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(authService)
        }
    }
}
