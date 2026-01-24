//
//  ColorExtension.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//

import SwiftUI

extension Color {
    // CHOPCHOP 스타일 - 따뜻한 코랄/오렌지 톤
    static let safeEatPrimary = Color(red: 0.977, green: 0.427, blue: 0.355) // #F96D5A
    static let safeEatPrimaryLight = Color(red: 0.957, green: 0.659, blue: 0.620).opacity(0.13)
    static let safeEatBorder = Color(red: 0.957, green: 0.659, blue: 0.620) // #F4A89E

    // 배경 색상
    static let safeEatBackground = Color(red: 1.0, green: 0.995, blue: 0.975)
    static let safeEatGradientTop = Color(red: 1.0, green: 0.949, blue: 0.941)
    static let safeEatGradientBottom = Color(red: 1.0, green: 0.995, blue: 0.975)

    // 텍스트 색상
    static let safeEatTextPrimary = Color.black
    static let safeEatTextSecondary = Color(red: 0.508, green: 0.508, blue: 0.508)
    static let safeEatTextDisabled = Color(red: 0.681, green: 0.681, blue: 0.681)

    // 카드 색상
    static let safeEatCardBackground = Color.white
    static let safeEatCardBorder = Color(red: 0.929, green: 0.929, blue: 0.929)

    // 노란색 강조 (검색 화면 하단)
    static let safeEatYellowHighlight = Color(red: 1.0, green: 0.970, blue: 0.551).opacity(0.13)
}
