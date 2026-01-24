# Firebase 설정 가이드

## 1. Firebase iOS SDK 설치 (Swift Package Manager)

Xcode에서 다음 단계를 따라 Firebase SDK를 설치하세요:

1. Xcode에서 `SafeEat.xcodeproj` 열기
2. File > Add Package Dependencies... 선택
3. 검색창에 다음 URL 입력:
   ```
   https://github.com/firebase/firebase-ios-sdk
   ```
4. Version: `10.20.0` 이상 선택 (Up to Next Major Version)
5. 다음 패키지 선택:
   - **FirebaseAuth** (Apple Login 인증)
   - **FirebaseFirestore** (데이터베이스)
   - **FirebaseFirestoreSwift** (Swift 모델 지원)
6. Add Package 클릭

## 2. Firebase 프로젝트 생성

1. [Firebase Console](https://console.firebase.google.com/) 접속
2. "프로젝트 추가" 클릭
3. 프로젝트 이름: `SafeEat` 입력
4. Google Analytics 설정 (선택사항)
5. 프로젝트 생성 완료

## 3. iOS 앱 추가

1. Firebase 프로젝트 Overview에서 iOS 아이콘 클릭
2. 번들 ID 입력: `com.safeeat.app`
3. 앱 닉네임: `SafeEat` (선택사항)
4. App Store ID: 비워두기 (개발 단계)
5. "앱 등록" 클릭

## 4. GoogleService-Info.plist 다운로드

1. Firebase Console에서 `GoogleService-Info.plist` 파일 다운로드
2. 다운로드한 파일을 `/home/user/chopchop/SafeEat/SafeEat/` 폴더에 복사
3. Xcode에서 파일을 프로젝트에 추가:
   - 파일을 SafeEat 폴더로 드래그
   - "Copy items if needed" 체크
   - Target: SafeEat 선택

## 5. Apple Sign In 설정

### Xcode 설정:
1. Xcode에서 SafeEat 타겟 선택
2. "Signing & Capabilities" 탭 선택
3. "+ Capability" 클릭
4. "Sign in with Apple" 추가

### Firebase Console 설정:
1. Firebase Console > Authentication > Sign-in method
2. "Apple" 활성화
3. 설정 저장

## 6. Firestore 데이터베이스 설정

1. Firebase Console > Firestore Database
2. "데이터베이스 만들기" 클릭
3. 모드 선택: **테스트 모드**로 시작 (개발용)
4. 위치 선택: `asia-northeast3` (서울)
5. 사용 설정 클릭

### 보안 규칙 (나중에 프로덕션 전 수정 필요):
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 개발 중에는 테스트 모드
    match /{document=**} {
      allow read, write: if request.time < timestamp.date(2026, 3, 1);
    }
  }
}
```

## 7. 설치 확인

모든 설정이 완료되면 앱을 실행하여 Firebase 초기화 로그를 확인하세요:
```
[Firebase/Core][I-COR000001] Configured the default Firebase app.
```

## 다음 단계

- [ ] Firebase iOS SDK 설치 완료
- [ ] GoogleService-Info.plist 추가 완료
- [ ] Apple Sign In 권한 추가 완료
- [ ] Firestore 데이터베이스 생성 완료
- [ ] 앱 실행 및 Firebase 초기화 확인
