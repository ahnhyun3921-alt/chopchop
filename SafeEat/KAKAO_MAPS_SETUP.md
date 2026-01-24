# 카카오 지도 SDK 설치 가이드

CocoaPods 없이 Swift Package Manager로 카카오 지도를 사용하는 방법입니다.

## 1. Swift Package Manager로 KakaoMapsSDK 추가

### Xcode에서 패키지 추가:
1. Xcode에서 프로젝트 열기
2. 메뉴에서 `File` > `Add Package Dependencies...` 선택
3. 검색창에 다음 URL 입력:
   ```
   https://github.com/kakao-mapsSDK/KakaoMapsSDK-SPM
   ```
4. `Dependency Rule`을 `Branch: master` 또는 원하는 버전으로 설정
5. `Add Package` 클릭
6. `KakaoMapsSDK` 제품 선택 후 `Add Package` 클릭

## 2. 코드 주석 해제

### 2.1. SafeEatApp.swift
다음 부분의 주석을 해제:
```swift
import KakaoMapsSDK

// init() 메서드 안에서:
SDKInitializer.InitSDK(appKey: Config.kakaoRestAPIKey)
```

### 2.2. KakaoMapView.swift
파일 상단에서:
```swift
import KakaoMapsSDK
```

그리고 파일 내의 `TODO: KakaoMapsSDK 설치 후 활성화` 주석으로 표시된 코드들을 활성화:
- `makeUIView` 메서드의 지도 컨테이너 생성 코드
- `updateUIView` 메서드의 마커 추가 코드
- `MapControllerDelegate` extension

## 3. API 키 확인

`Config.swift`에 Kakao REST API 키가 이미 설정되어 있습니다:
```swift
static let kakaoRestAPIKey = "076dadf5b4de23d8c6ce0340ecfa9201"
```

**참고:** 카카오 지도 SDK는 Native App Key가 필요할 수 있습니다. 만약 REST API 키로 작동하지 않으면:
1. [Kakao Developers](https://developers.kakao.com/console/app) 접속
2. 앱 선택 후 `앱 키` 메뉴에서 `Native 앱 키` 확인
3. `Config.swift`에 Native App Key 추가 및 사용

## 4. 빌드 및 실행

1. Xcode에서 `Cmd + B`로 빌드
2. 시뮬레이터 또는 실제 기기에서 실행
3. 검색 탭에서 지도 아이콘을 눌러 카카오 지도 확인

## 5. 문제 해결

### 빌드 오류 발생 시:
- Xcode를 재시작
- `Product` > `Clean Build Folder` (Shift + Cmd + K)
- 다시 빌드

### 지도가 표시되지 않을 시:
- API 키가 올바른지 확인
- Kakao Developers 콘솔에서 앱 설정 확인
- 번들 ID가 Kakao 앱에 등록되어 있는지 확인

## 참고 자료

- [KakaoMaps SDK GitHub](https://github.com/kakao-mapsSDK/KakaoMapsSDK-SPM)
- [Kakao Maps API 문서](https://apis.map.kakao.com/ios_v2/)
- [Kakao Developers](https://developers.kakao.com/)

---

## 왜 카카오 지도로 변경했나요?

기존에는 Naver Maps SDK를 사용하려 했으나:
- CocoaPods 설치가 Ruby 버전 및 네트워크 문제로 실패
- CocoaPods는 2026년 Q2 이후 새 버전 출시 중단 예정
- Swift Package Manager가 Apple의 공식 권장 패키지 관리자

카카오 지도의 장점:
- ✅ Swift Package Manager 지원 (설치 간편)
- ✅ 기존에 사용 중인 Kakao Local API와 자연스럽게 통합
- ✅ 좌표 데이터 호환성 (동일한 API 응답 사용)
- ✅ 무료 (1일 30만 호출)
