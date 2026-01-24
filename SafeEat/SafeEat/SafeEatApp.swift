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
    // Firebase 초기화
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RestaurantDetailView()
        }
    }
}
