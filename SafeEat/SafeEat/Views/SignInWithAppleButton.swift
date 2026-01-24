//
//  SignInWithAppleButton.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//

import SwiftUI
import AuthenticationServices

struct SignInWithAppleButton: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        SignInWithAppleButtonRepresentable(
            onRequest: { request in
                // AuthenticationService에서 nonce 설정된 request 가져오기
                let appleRequest = authService.startSignInWithAppleFlow()
                request.requestedScopes = appleRequest.requestedScopes
                request.nonce = appleRequest.nonce
            },
            onCompletion: { result in
                Task {
                    do {
                        switch result {
                        case .success(let authorization):
                            try await authService.handleSignInWithAppleCompletion(authorization)
                        case .failure(let error):
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    } catch {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
        )
        .frame(height: 50)
        .alert("로그인 실패", isPresented: $showError) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
}

// UIKit의 ASAuthorizationAppleIDButton을 SwiftUI에서 사용하기 위한 Representable
struct SignInWithAppleButtonRepresentable: UIViewRepresentable {
    let onRequest: (ASAuthorizationAppleIDRequest) -> Void
    let onCompletion: (Result<ASAuthorization, Error>) -> Void

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(
            authorizationButtonType: .signIn,
            authorizationButtonStyle: .black
        )
        button.cornerRadius = 8
        button.addTarget(
            context.coordinator,
            action: #selector(Coordinator.handleTap),
            for: .touchUpInside
        )
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        let parent: SignInWithAppleButtonRepresentable

        init(_ parent: SignInWithAppleButtonRepresentable) {
            self.parent = parent
        }

        @objc func handleTap() {
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            parent.onRequest(request)

            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            authorizationController.performRequests()
        }

        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            parent.onCompletion(.success(authorization))
        }

        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            parent.onCompletion(.failure(error))
        }

        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                return UIWindow()
            }
            return window
        }
    }
}
