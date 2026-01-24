//
//  LoginView.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthenticationService

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // 로고 및 타이틀
            VStack(spacing: 16) {
                Image(systemName: "fork.knife.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.safeEatPrimary)

                Text("SafeEat")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.safeEatPrimary)

                Text("알러지가 있는 사람들을 위한\n안전한 식당 메뉴 추천")
                    .font(.system(size: 16))
                    .foregroundColor(.safeEatTextSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Apple Sign In 버튼
            VStack(spacing: 20) {
                SignInWithAppleButton()
                    .frame(maxWidth: 280)

                Text("로그인하면 SafeEat의 서비스 약관 및\n개인정보 보호정책에 동의하게 됩니다")
                    .font(.system(size: 12))
                    .foregroundColor(.safeEatTextSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
                .frame(height: 60)
        }
        .padding(.horizontal, 40)
        .background(Color.safeEatBackground)
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthenticationService())
    }
}
