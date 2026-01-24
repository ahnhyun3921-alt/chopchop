# 네이버 지도 API 설정 가이드

## 1. 네이버 클라우드 플랫폼 API 키 발급

### 1.1 프로젝트 생성
1. [네이버 클라우드 플랫폼](https://console.ncloud.com/) 접속 및 로그인
2. Console > Services > Application Service > Maps 선택
3. "Application 등록" 클릭
4. Application 이름: `SafeEat`
5. Service 선택:
   - **Mobile Dynamic Map** (iOS용 지도 SDK)
   - **Geocoding** (주소 → 좌표 변환)
   - **Directions 5** (길찾기, 선택사항)
   - **Local Search** (지역 검색)

### 1.2 API 키 복사
- **Client ID** 복사 (앱에서 사용)
- **Client Secret** 복사 (서버에서 사용, 필요시)

## 2. 네이버 지도 SDK 설치 (CocoaPods)

### 2.1 CocoaPods 설치 확인
```bash
pod --version
```

설치 안 되어 있다면:
```bash
sudo gem install cocoapods
```

### 2.2 Podfile 생성
프로젝트 루트 디렉토리에서:
```bash
cd /home/user/chopchop/SafeEat
pod init
```

### 2.3 Podfile 편집
생성된 `Podfile`을 다음과 같이 수정:

```ruby
# Uncomment the next line to define a global platform for your project
platform :ios, '14.0'

target 'SafeEat' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for SafeEat
  pod 'NMapsMap'  # 네이버 지도 SDK

end
```

### 2.4 Pod 설치
```bash
pod install
```

**중요**: 이제부터 `SafeEat.xcworkspace` 파일을 열어야 합니다! (`.xcodeproj`가 아님)

## 3. Info.plist 설정

### 3.1 위치 권한 설정
`Info.plist` 파일에 다음 키 추가:

1. Xcode에서 `SafeEat.xcworkspace` 열기
2. 프로젝트 네비게이터에서 `Info.plist` 선택
3. 우클릭 > "Add Row"로 다음 항목 추가:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>주변 식당을 찾기 위해 위치 정보가 필요합니다</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>주변 식당을 찾기 위해 위치 정보가 필요합니다</string>

<key>NMFClientId</key>
<string>YOUR_NAVER_MAPS_CLIENT_ID</string>
```

**중요**: `YOUR_NAVER_MAPS_CLIENT_ID`를 실제 네이버 클라우드에서 발급받은 Client ID로 교체하세요!

### 3.2 HTTP 통신 허용 (개발용)
네이버 API 호출을 위해 `Info.plist`에 추가:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

## 4. 환경 변수 설정 (.env 파일)

API 키를 안전하게 관리하기 위해 `.env` 파일 사용:

### 4.1 .env 파일 생성
프로젝트 루트에 `.env` 파일 생성:
```bash
# Naver Cloud Platform API Keys
NAVER_MAPS_CLIENT_ID=your_client_id_here
NAVER_CLIENT_ID=your_naver_api_client_id
NAVER_CLIENT_SECRET=your_naver_api_client_secret

# Claude API Key
CLAUDE_API_KEY=your_claude_api_key_here
```

### 4.2 .gitignore에 추가
`.env` 파일이 Git에 올라가지 않도록:
```bash
echo ".env" >> .gitignore
```

## 5. 네이버 지도 초기화

`SafeEatApp.swift`에서 네이버 지도 초기화:

```swift
import NMapsMap

init() {
    FirebaseApp.configure()
    NMFAuthManager.shared().clientId = "YOUR_CLIENT_ID"
}
```

## 6. 설치 확인

1. `SafeEat.xcworkspace` 열기 (중요!)
2. Command + B로 빌드
3. 에러 없이 빌드되면 성공

## 7. 문제 해결

### Pod 설치 실패
```bash
pod repo update
pod install --repo-update
```

### 빌드 에러: "No such module 'NMapsMap'"
- `SafeEat.xcworkspace`를 열었는지 확인 (`.xcodeproj`가 아님!)
- Clean Build Folder (Command + Shift + K)
- 다시 빌드 (Command + B)

### 지도가 표시되지 않음
- Info.plist의 `NMFClientId` 값 확인
- 네이버 클라우드 플랫폼에서 Mobile Dynamic Map 서비스 활성화 확인
- Client ID가 올바른지 확인

## 다음 단계

네이버 지도 SDK 설치 후:
1. 지도 뷰 구현
2. 현재 위치 표시
3. 식당 검색 API 연동
4. 식당 마커 표시
