# SafeEat 자동 메뉴 수집 스크립트

완전 무료로 평촌 지역 식당의 메뉴를 자동으로 수집하는 Python 스크립트입니다.

## 🎯 작동 방식

```
1. Kakao Local API로 평촌 지역 식당 검색
2. Google Image Search로 각 식당의 "메뉴판" 이미지 검색
3. Apple Vision OCR로 메뉴판 이미지에서 텍스트 추출 (무료!)
4. 메뉴명, 가격, 재료 파싱
5. Firebase Firestore에 저장
6. 이미지 즉시 삭제 (저작권 보호)
```

## 💰 비용

**완전 무료!**

- Kakao Local API: 무료
- Google Custom Search API: 일 100회 무료
- **Apple Vision OCR: 무료 (macOS 내장, 정확도 95%+)**
- Firebase Firestore: 무료 할당량 내

## 📋 필수 요구사항

### 1. macOS (권장)

**Apple Vision OCR이 내장되어 있어 별도 설치 불필요!**
- 정확도: 95%+ (Tesseract: 70-80%)
- 한글 인식 우수
- 완전 무료

### 2. Python 3.8 이상

```bash
python3 --version
```

### 3. Python 패키지 설치

```bash
cd scripts
pip install -r requirements.txt
```

**참고:** macOS에서는 자동으로 Apple Vision을 사용합니다.
다른 OS에서는 Tesseract가 fallback으로 사용됩니다 (별도 설치 필요).

## 🔧 설정

### 1. Kakao REST API 키 발급

1. https://developers.kakao.com/ 접속
2. 내 애플리케이션 → 애플리케이션 추가하기
3. 앱 이름: SafeEat
4. 앱 키 → REST API 키 복사
5. `menu_collector.py` 파일 열기:
   ```python
   KAKAO_API_KEY = "여기에_REST_API_키_붙여넣기"
   ```

### 2. Firebase Admin SDK 인증 파일

1. Firebase Console (https://console.firebase.google.com/) 접속
2. CHOPCHOP 프로젝트 선택
3. 프로젝트 설정 (⚙️) → 서비스 계정
4. "새 비공개 키 생성" 클릭
5. JSON 파일 다운로드
6. 파일 이름을 `firebase-admin-key.json`으로 변경
7. `scripts/` 폴더에 복사:
   ```bash
   cp ~/Downloads/chopchop-xxx-firebase-adminsdk-xxx.json scripts/firebase-admin-key.json
   ```

### 3. Google Custom Search API (이미 설정됨)

✅ API 키와 검색엔진 ID가 이미 스크립트에 포함되어 있습니다.

## 🚀 사용 방법

### 기본 사용 (평촌 지역, 10개 식당)

```bash
python menu_collector.py
```

### 옵션 지정

```bash
# 수집 지역 변경
python menu_collector.py --location "안양"

# 식당 수 변경 (최대 15개)
python menu_collector.py --limit 15

# 둘 다 지정
python menu_collector.py --location "범계" --limit 20
```

### 출력 예시

```
============================================================
🍽️  SafeEat 자동 메뉴 수집 시스템
============================================================
📍 지역: 평촌
🏪 식당 수: 10

🔥 Firebase 연결 중...
✅ Firebase 연결 완료

🔍 평촌 지역 식당 검색 중...
✅ 10개 식당 발견

진행: 1/10
============================================================
🍴 평촌돈까스 (일식)
📍 경기 안양시 동안구 평촌대로 123
  🔍 메뉴판 이미지 검색 중...
  ✅ 5개 이미지 발견
  📥 [1/3] 이미지 처리 중...
    ✅ 3개 메뉴 발견
  📥 [2/3] 이미지 처리 중...
    ✅ 2개 메뉴 발견
  💾 Firestore에 5개 메뉴 저장 중...
  ✅ 저장 완료!

...

============================================================
📊 수집 완료!
============================================================
✅ 성공: 8/10 식당
🍽️  총 메뉴: 47개
============================================================
```

## ⚠️ 주의사항

### 1. API 할당량

- Google Custom Search API: **일 100회 제한**
- 식당 1개당 최대 5회 검색 (이미지 5개)
- **하루에 최대 20개 식당** 수집 권장

### 2. OCR 정확도

- **Apple Vision 정확도: 95%+ (macOS)**
- Tesseract 정확도: 70-80% (다른 OS)
- 손글씨나 특수 폰트는 인식 어려움
- 수집 후 검토 권장

### 3. 저작권

- 메뉴판 이미지는 **즉시 삭제**
- 텍스트 데이터만 저장
- 개인 용도로만 사용

### 4. 실행 시간

- 식당 1개당 약 5-10초
- 10개 식당: 약 1-2분

## 🔍 트러블슈팅

### pyobjc 설치 오류 (macOS)

```bash
# Xcode Command Line Tools 설치 필요
xcode-select --install

# pyobjc 재설치
pip install --upgrade pyobjc-framework-Vision pyobjc-framework-Quartz
```

### Apple Vision을 찾을 수 없음

- macOS 10.15 (Catalina) 이상 필요
- `python3 --version`으로 Python이 올바르게 설치되었는지 확인

### Firebase 인증 오류

- `firebase-admin-key.json` 파일이 `scripts/` 폴더에 있는지 확인
- Firebase Console에서 새 키 다운로드

### Google API 할당량 초과

```
Error: Resource has been exhausted (e.g. check quota).
```

- 하루에 100회 제한
- 내일 다시 시도

### 메뉴가 인식 안 됨

- 메뉴판 이미지 품질이 낮을 경우
- 손글씨 메뉴판 (Apple Vision도 인식 어려움)
- 다른 식당으로 시도하거나 앱에서 수동 등록

## 📊 데이터 구조

Firestore에 저장되는 메뉴 데이터:

```json
{
  "id": "uuid-string",
  "restaurantId": "kakao-place-id",
  "name": "김치찌개",
  "price": 8000,
  "ingredients": ["돼지고기", "김치", "두부"],
  "createdAt": "2026-01-24T12:00:00"
}
```

저장 위치:
```
restaurants/{restaurantId}/menus/{menuId}
```

## 📝 라이센스

개인 용도로만 사용하세요. 상업적 사용 금지.

## 🆘 문제 해결

문제가 발생하면:
1. Python 버전 확인 (3.8 이상)
2. Tesseract 설치 확인
3. API 키 확인
4. Firebase 인증 파일 확인
