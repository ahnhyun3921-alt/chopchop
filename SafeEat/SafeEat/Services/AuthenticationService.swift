//
//  AuthenticationService.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//

import Foundation
// Firebase는 나중에 설치 후 활성화
// import FirebaseAuth
import AuthenticationServices
import CryptoKit

// 임시 User 타입 정의 (Firebase 설치 전)
struct User {
    let uid: String
    let email: String?
    let displayName: String?
}

@MainActor
class AuthenticationService: ObservableObject {
    @Published var user: User?
    @Published var isAuthenticated = false

    private var currentNonce: String?

    init() {
        // Firebase 설치 전 임시 상태
        self.user = nil
        self.isAuthenticated = false

        // Firebase 설치 후 활성화:
        // self.user = Auth.auth().currentUser
        // self.isAuthenticated = user != nil
        // Auth.auth().addStateDidChangeListener { [weak self] _, user in
        //     self?.user = user
        //     self?.isAuthenticated = user != nil
        // }
    }

    // Apple Sign In 시작 (Firebase 설치 후 활성화)
    func startSignInWithAppleFlow() -> ASAuthorizationAppleIDRequest {
        let nonce = randomNonceString()
        currentNonce = nonce

        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        return request
    }

    // Apple Sign In 완료 처리 (Firebase 설치 후 활성화)
    func handleSignInWithAppleCompletion(_ authorization: ASAuthorization) async throws {
        // Firebase 설치 후 구현
        throw AuthenticationError.invalidCredential

        /* Firebase 설치 후 활성화:
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthenticationError.invalidCredential
        }

        let credential = OAuthProvider.credential(
            withProviderID: "apple.com",
            idToken: idTokenString,
            rawNonce: nonce
        )

        let result = try await Auth.auth().signIn(with: credential)
        self.user = result.user
        self.isAuthenticated = true

        if let fullName = appleIDCredential.fullName {
            let changeRequest = result.user.createProfileChangeRequest()
            let displayName = [fullName.givenName, fullName.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            if !displayName.isEmpty {
                changeRequest.displayName = displayName
            }
            try await changeRequest.commitChanges()
        }
        */
    }

    // 로그아웃 (Firebase 설치 후 활성화)
    func signOut() throws {
        // Firebase 설치 후 구현
        // try Auth.auth().signOut()
        self.user = nil
        self.isAuthenticated = false
    }

    // MARK: - Private Helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }

        return String(nonce)
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()

        return hashString
    }
}

enum AuthenticationError: LocalizedError {
    case invalidCredential

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Apple 로그인 인증 정보가 유효하지 않습니다."
        }
    }
}
