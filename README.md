# SafeEat 🍽️

알러지가 있는 사람들을 위한 안전한 식당 메뉴 추천 앱

## 프로젝트 개요

**SafeEat**은 식이 제한이 있는 사람들(알러지, 비건, 할랄 등)을 위해 안전하게 먹을 수 있는 메뉴가 있는 식당을 찾아주는 iOS 앱입니다.

### 주요 기능

- 인물별 제한 식품 설정
- 네이버 지도 API 기반 식당 검색
- Claude 3.5 Haiku AI로 메뉴-재료 판단
- 확률 기반 안전 메뉴 필터링
- 인물별 안전한 메뉴 표시

### 기술 스택

- **Frontend**: SwiftUI
- **Backend**: Firebase (Authentication, Firestore)
- **APIs**:
  - 네이버 지도 API
  - Claude 3.5 Haiku API
- **인증**: Apple Login

### 디자인

CHOPCHOP 앱 스타일을 참고한 따뜻한 디자인:
- 주요 색상: 코랄/오렌지 톤 (#F96D5A)
- 둥근 UI 요소
- 직관적이고 친근한 인터페이스

## 프로젝트 구조

```
SafeEat/
├── SafeEat/
│   ├── SafeEatApp.swift          # 앱 진입점 + Firebase 초기화
│   ├── GoogleService-Info.plist  # Firebase 설정 파일
│   ├── Views/
│   │   ├── RestaurantDetailView.swift  # 식당 조회 페이지
│   │   ├── LoginView.swift             # 로그인 화면
│   │   └── SignInWithAppleButton.swift # Apple 로그인 버튼
│   ├── Models/
│   │   └── Restaurant.swift       # 데이터 모델
│   ├── ViewModels/
│   │   └── RestaurantDetailViewModel.swift
│   ├── Services/
│   │   ├── AuthenticationService.swift # Apple 로그인 처리
│   │   └── FirestoreService.swift      # Firestore 데이터베이스 서비스
│   └── Utils/
│       └── ColorExtension.swift   # 색상 시스템
├── SafeEat.xcodeproj/
├── FIREBASE_SETUP.md             # Firebase 설정 가이드
└── ADD_FILES_TO_XCODE.md         # 파일 추가 가이드
```

## 현재 구현 상태

### ✅ 완료
- [x] 프로젝트 기본 구조 설정
- [x] 색상 시스템 및 디자인 토큰
- [x] 식당 상세 페이지 UI (3가지 상태)
  - 기본 상태 (메뉴 개수만 표시)
  - 영업시간 펼침 상태
  - 안전한 메뉴 리스트 펼침 상태
- [x] 데이터 모델 (Restaurant, Menu, Person)
- [x] ViewModel 구조
- [x] 즐겨찾기 기능 (하트 토글 + Firebase 저장)
- [x] **Firebase 통합 (코드 작성 완료)**
  - Firebase 초기화 코드
  - Apple Sign In 인증 서비스
  - Firestore 데이터베이스 서비스
  - 즐겨찾기 Firebase 저장
  - 인물(제한 식품) 관리 서비스
  - 로그인 UI 구현
- [x] **네이버 지도 API 통합 (코드 작성 완료)**
  - NaverSearchService: 식당 검색 API
  - NaverMapView: 지도 뷰 구현
  - LocationManager: 위치 권한 및 현재 위치
  - RestaurantSearchView: 검색 화면 (리스트/지도)
- [x] **Claude AI API 통합 (코드 작성 완료)**
  - ClaudeAPIService: 메뉴 분석 API
  - MenuAnalysisService: 안전한 메뉴 필터링
  - 메뉴 → 재료 분석
  - 알러지 확률 계산

### ⚙️ 설정 필요 (사용자가 수행해야 할 작업)

#### 1. 환경 변수 설정
```bash
cp .env.example .env
# .env 파일을 열어서 API 키들을 실제 값으로 교체
```

#### 2. Firebase 설정
- [ ] Firebase iOS SDK 설치 (SPM - Xcode에서 수동 추가 필요)
- [ ] Firebase 프로젝트 생성 및 GoogleService-Info.plist 교체
- [ ] Apple Sign In Capability 추가
- [ ] Firestore 데이터베이스 생성

**설정 가이드**: `FIREBASE_SETUP.md` 참조

#### 3. 네이버 지도 API 설정
- [ ] 네이버 클라우드 플랫폼 계정 생성
- [ ] Maps API 키 발급 (Client ID)
- [ ] Local Search API 키 발급
- [ ] CocoaPods으로 NMapsMap SDK 설치
- [ ] Info.plist에 API 키 및 위치 권한 추가

**설정 가이드**: `NAVER_MAPS_SETUP.md` 참조

#### 4. Claude API 설정
- [ ] Anthropic Console에서 API 키 발급
- [ ] .env 파일에 API 키 추가

**설정 가이드**: `CLAUDE_API_SETUP.md` 참조

### 🚧 다음 단계
- [ ] 재료 관리 화면 (사용자가 제한 식품 추가/삭제)
- [ ] 인물 관리 화면 (가족 구성원 및 제한 식품 관리)
- [ ] 메인 화면 (홈 피드)
- [ ] 프로필 화면
- [ ] 설정 화면

## 실행 방법

### 최초 설정

1. **Firebase 설정** (필수)
   - `FIREBASE_SETUP.md` 가이드를 따라 Firebase 프로젝트 설정
   - Firebase iOS SDK를 Xcode에 추가
   - GoogleService-Info.plist 교체

2. **새 파일 추가** (필수)
   - `ADD_FILES_TO_XCODE.md` 가이드를 따라 새로 생성된 파일들을 Xcode 프로젝트에 추가

### 앱 실행

1. Xcode에서 `SafeEat.xcodeproj` 열기
2. iOS 시뮬레이터 또는 실제 기기 선택
3. Command + B로 빌드 확인
4. Command + R로 실행

### 문제 해결

- 빌드 에러 발생 시: Firebase SDK가 올바르게 추가되었는지 확인
- 런타임 에러 발생 시: GoogleService-Info.plist가 프로젝트에 포함되어 있는지 확인

## 화면 설명

### 식당 상세 페이지

현재 구현된 식당 조회 페이지는 다음 요소를 포함합니다:

1. **식당 헤더**
   - 식당 이름
   - 카테고리 (예: 이탈리아음식)
   - 별점
   - 거리 정보

2. **영업 시간**
   - 현재 상태 표시 (예: "14:30 브레이크 타임")
   - 펼침/접힘 기능
   - 요일별 상세 영업시간

3. **지도로 확인하기 버튼**
   - 식당 위치 확인 기능

4. **메뉴 섹션**
   - 전체 메뉴 개수
   - 인물별 안전한 메뉴 카드
   - 각 인물에게 안전한 메뉴 리스트
   - 펼침/접힘 기능

5. **경고 메시지**
   - AI 판단의 한계 안내
   - 매장 직접 문의 권장

## 라이선스

MIT License

## 제작

Created by Claude on 2026-01-24
Based on Figma designs for SafeEat Restaurant App
