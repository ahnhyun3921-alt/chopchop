#!/bin/bash
# SafeEat 메뉴 수집 스크립트 자동 설정

echo "============================================================"
echo "🍽️  SafeEat 메뉴 수집 스크립트 설정"
echo "============================================================"
echo ""

# 현재 디렉토리 확인
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# 1. Python 버전 확인
echo "1️⃣  Python 버전 확인..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    echo "   ✅ $PYTHON_VERSION"
else
    echo "   ❌ Python 3가 설치되지 않았습니다"
    echo "   설치: brew install python3"
    exit 1
fi
echo ""

# 2. macOS 확인
echo "2️⃣  운영체제 확인..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "   ✅ macOS - Apple Vision OCR 사용 가능"
    USE_APPLE_VISION=true
else
    echo "   ⚠️  macOS가 아님 - Tesseract 필요"
    USE_APPLE_VISION=false
fi
echo ""

# 3. Python 패키지 설치
echo "3️⃣  Python 패키지 설치 중..."
if pip3 install -r requirements.txt; then
    echo "   ✅ 패키지 설치 완료"
else
    echo "   ❌ 패키지 설치 실패"
    exit 1
fi
echo ""

# 4. Kakao API 키 확인
echo "4️⃣  Kakao REST API 키 설정..."
if grep -q "YOUR_KAKAO_REST_API_KEY" menu_collector.py; then
    echo "   ⚠️  Kakao API 키가 설정되지 않았습니다"
    echo ""
    echo "   📝 Kakao API 키 발급 방법:"
    echo "   1. https://developers.kakao.com/ 접속"
    echo "   2. 내 애플리케이션 → 애플리케이션 추가하기"
    echo "   3. 앱 이름: SafeEat"
    echo "   4. 앱 키 → REST API 키 복사"
    echo ""
    read -p "   REST API 키를 입력하세요 (Enter로 건너뛰기): " KAKAO_KEY

    if [ -n "$KAKAO_KEY" ]; then
        # macOS sed와 Linux sed 모두 지원
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/YOUR_KAKAO_REST_API_KEY/$KAKAO_KEY/" menu_collector.py
        else
            sed -i "s/YOUR_KAKAO_REST_API_KEY/$KAKAO_KEY/" menu_collector.py
        fi
        echo "   ✅ Kakao API 키 설정 완료"
    else
        echo "   ⏭️  건너뜀 (나중에 menu_collector.py 파일 직접 수정)"
    fi
else
    echo "   ✅ Kakao API 키 이미 설정됨"
fi
echo ""

# 5. Firebase 인증 파일 확인
echo "5️⃣  Firebase 인증 파일 확인..."
if [ -f "firebase-admin-key.json" ]; then
    echo "   ✅ firebase-admin-key.json 파일 존재"
else
    echo "   ⚠️  firebase-admin-key.json 파일이 없습니다"
    echo ""
    echo "   📝 Firebase 인증 파일 다운로드 방법:"
    echo "   1. https://console.firebase.google.com/ 접속"
    echo "   2. CHOPCHOP 프로젝트 선택"
    echo "   3. 프로젝트 설정 (⚙️) → 서비스 계정"
    echo "   4. 새 비공개 키 생성 → JSON 다운로드"
    echo "   5. 파일명을 firebase-admin-key.json으로 변경"
    echo "   6. 이 폴더(scripts/)에 복사"
    echo ""

    if [ -d ~/Downloads ]; then
        echo "   🔍 Downloads 폴더에서 Firebase 키 파일 찾는 중..."
        FIREBASE_FILE=$(find ~/Downloads -name "*firebase*adminsdk*.json" -type f | head -n 1)

        if [ -n "$FIREBASE_FILE" ]; then
            echo "   발견: $FIREBASE_FILE"
            read -p "   이 파일을 사용하시겠습니까? (y/N): " USE_FILE

            if [[ $USE_FILE =~ ^[Yy]$ ]]; then
                cp "$FIREBASE_FILE" firebase-admin-key.json
                echo "   ✅ Firebase 인증 파일 복사 완료"
            fi
        else
            echo "   ⏭️  Downloads 폴더에서 파일을 찾을 수 없습니다"
        fi
    fi
fi
echo ""

# 6. 최종 확인
echo "============================================================"
echo "📊 설정 완료 확인"
echo "============================================================"

READY=true

# Kakao API 키 확인
if grep -q "YOUR_KAKAO_REST_API_KEY" menu_collector.py; then
    echo "❌ Kakao API 키 미설정"
    READY=false
else
    echo "✅ Kakao API 키 설정됨"
fi

# Firebase 인증 파일 확인
if [ -f "firebase-admin-key.json" ]; then
    echo "✅ Firebase 인증 파일 존재"
else
    echo "❌ Firebase 인증 파일 없음"
    READY=false
fi

# Python 패키지 확인
if python3 -c "import firebase_admin" 2>/dev/null; then
    echo "✅ Python 패키지 설치됨"
else
    echo "❌ Python 패키지 미설치"
    READY=false
fi

echo "============================================================"

if [ "$READY" = true ]; then
    echo ""
    echo "🎉 모든 설정이 완료되었습니다!"
    echo ""
    echo "실행 방법:"
    echo "  python3 menu_collector.py --location \"평촌\" --limit 10"
    echo ""
else
    echo ""
    echo "⚠️  일부 설정이 완료되지 않았습니다."
    echo "위의 ❌ 항목을 확인하고 수동으로 설정해주세요."
    echo ""
    echo "자세한 내용은 README.md를 참조하세요."
    echo ""
fi
