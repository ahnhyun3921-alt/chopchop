# Xcode 프로젝트에 새 파일 추가하기

Firebase 통합을 위해 다음 파일들을 생성했습니다. 이 파일들을 Xcode 프로젝트에 추가해야 합니다.

## 자동 추가 (권장)

터미널에서 다음 명령어를 실행하면 자동으로 파일이 프로젝트에 추가됩니다:

```bash
cd /home/user/chopchop
# Xcode가 닫혀있는지 확인하세요!

# 새 파일들을 Xcode 프로젝트에 추가
# (아래 명령어는 pbxproj 파일을 직접 수정하므로 주의가 필요합니다)
# 수동으로 추가하는 것을 권장합니다.
```

## 수동 추가 (안전함, 권장)

### 1. Services 폴더 및 파일 추가

1. Xcode에서 `SafeEat.xcodeproj` 열기
2. 프로젝트 네비게이터에서 `SafeEat` 폴더 선택
3. 우클릭 > "New Group" 선택
4. 그룹 이름: `Services` 입력
5. `Services` 그룹 선택 후 우클릭 > "Add Files to SafeEat..."
6. 다음 파일들 선택:
   - `/home/user/chopchop/SafeEat/SafeEat/Services/AuthenticationService.swift`
   - `/home/user/chopchop/SafeEat/SafeEat/Services/FirestoreService.swift`
7. 옵션 확인:
   - ✅ "Copy items if needed"
   - ✅ "Create groups"
   - ✅ Target: SafeEat 선택
8. "Add" 클릭

### 2. Views 폴더에 파일 추가

1. 프로젝트 네비게이터에서 `Views` 폴더 선택
2. 우클릭 > "Add Files to SafeEat..."
3. 다음 파일들 선택:
   - `/home/user/chopchop/SafeEat/SafeEat/Views/SignInWithAppleButton.swift`
   - `/home/user/chopchop/SafeEat/SafeEat/Views/LoginView.swift`
4. 옵션 확인 후 "Add" 클릭

### 3. GoogleService-Info.plist 추가

**중요: 실제 Firebase 프로젝트를 생성한 후, Firebase Console에서 다운로드한 실제 파일로 교체해야 합니다!**

1. 프로젝트 네비게이터에서 `SafeEat` 폴더 (루트) 선택
2. 우클릭 > "Add Files to SafeEat..."
3. 파일 선택: `/home/user/chopchop/SafeEat/SafeEat/GoogleService-Info.plist`
4. 옵션 확인:
   - ✅ "Copy items if needed"
   - ✅ Target: SafeEat 선택
5. "Add" 클릭

## 파일 추가 확인

모든 파일이 올바르게 추가되었는지 확인:

1. 프로젝트 네비게이터에서 다음 구조 확인:
   ```
   SafeEat/
   ├── SafeEatApp.swift
   ├── GoogleService-Info.plist
   ├── Views/
   │   ├── RestaurantDetailView.swift
   │   ├── SignInWithAppleButton.swift
   │   └── LoginView.swift
   ├── Models/
   │   └── Restaurant.swift
   ├── ViewModels/
   │   └── RestaurantDetailViewModel.swift
   ├── Services/          ← 새로 추가됨
   │   ├── AuthenticationService.swift
   │   └── FirestoreService.swift
   └── Utils/
       └── ColorExtension.swift
   ```

2. 빌드 (⌘ + B)해서 에러가 없는지 확인

## 다음 단계

파일 추가가 완료되면 `FIREBASE_SETUP.md` 문서를 참고하여 Firebase 프로젝트를 설정하세요.
