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
│   ├── SafeEatApp.swift          # 앱 진입점
│   ├── Views/
│   │   └── RestaurantDetailView.swift  # 식당 조회 페이지
│   ├── Models/
│   │   └── Restaurant.swift       # 데이터 모델
│   ├── ViewModels/
│   │   └── RestaurantDetailViewModel.swift
│   └── Utils/
│       └── ColorExtension.swift   # 색상 시스템
└── SafeEat.xcodeproj/
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

### 🚧 진행 예정
- [ ] Firebase 연동
- [ ] 네이버 지도 API 연동
- [ ] Claude API 연동
- [ ] Apple Login 구현
- [ ] 식당 검색 기능
- [ ] 재료 관리 화면
- [ ] 인물 관리 화면

## 실행 방법

1. Xcode에서 `SafeEat.xcodeproj` 열기
2. iOS 시뮬레이터 또는 실제 기기 선택
3. Command + R로 빌드 및 실행

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
