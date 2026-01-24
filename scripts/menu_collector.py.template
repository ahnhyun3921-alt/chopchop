#!/usr/bin/env python3
"""
SafeEat 자동 메뉴 수집 스크립트
완전 무료 메뉴 데이터 수집 시스템 (Apple Vision OCR 사용)

사용 방법:
1. requirements.txt 설치: pip install -r requirements.txt
2. Firebase 인증 파일 다운로드: firebase-admin-key.json
3. 실행: python menu_collector.py --location "평촌" --limit 10

주의: macOS 전용 (Apple Vision 사용)
"""

import os
import re
import time
import uuid
import argparse
import requests
import platform
from io import BytesIO
from PIL import Image
from googleapiclient.discovery import build
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

# macOS에서만 Apple Vision 사용
IS_MACOS = platform.system() == 'Darwin'

if IS_MACOS:
    try:
        import Vision
        from Quartz import CIImage
        from Foundation import NSURL, NSMutableDictionary
        print("✅ Apple Vision OCR 사용")
    except ImportError:
        print("⚠️  pyobjc 미설치. 설치: pip install pyobjc-framework-Vision pyobjc-framework-Quartz")
        IS_MACOS = False
else:
    print("⚠️  macOS가 아니므로 Tesseract 사용")
    import pytesseract

# ==================== 설정 ====================

# Kakao REST API 키 (https://developers.kakao.com/)
KAKAO_API_KEY = "YOUR_KAKAO_REST_API_KEY"

# Google Custom Search API 키
GOOGLE_API_KEY = "AIzaSyDxRZDZ5bTAdcNXrI2RtEddmO20DMlPX-8"
GOOGLE_CX = "c517cbc75ca1044ac"

# Firebase Admin SDK 인증 파일 경로
FIREBASE_CRED_PATH = "firebase-admin-key.json"

# ==================== Firebase 초기화 ====================

def init_firebase():
    """Firebase Admin SDK 초기화"""
    if not firebase_admin._apps:
        cred = credentials.Certificate(FIREBASE_CRED_PATH)
        firebase_admin.initialize_app(cred)
    return firestore.client()

# ==================== Kakao Local API ====================

def search_restaurants(location, radius=5000, size=15):
    """카카오 로컬 API로 식당 검색"""
    url = "https://dapi.kakao.com/v2/local/search/keyword.json"
    headers = {"Authorization": f"KakaoAK {KAKAO_API_KEY}"}
    params = {
        "query": f"{location} 맛집",
        "category_group_code": "FD6",  # 음식점
        "size": size,
        "radius": radius
    }

    response = requests.get(url, headers=headers, params=params)
    response.raise_for_status()
    data = response.json()

    restaurants = []
    for doc in data.get("documents", []):
        restaurant = {
            "id": doc["id"],
            "name": doc["place_name"],
            "category": doc.get("category_name", "").split(" > ")[-1] if doc.get("category_name") else "",
            "address": doc.get("address_name", ""),
            "phone": doc.get("phone", ""),
            "latitude": float(doc["y"]),
            "longitude": float(doc["x"])
        }
        restaurants.append(restaurant)

    return restaurants

# ==================== Google Image Search ====================

def search_menu_images(restaurant_name, location="평촌", num=5):
    """구글 이미지 검색으로 메뉴판 이미지 URL 찾기"""
    service = build("customsearch", "v1", developerKey=GOOGLE_API_KEY)
    query = f"{restaurant_name} 메뉴판 {location}"

    try:
        result = service.cse().list(
            q=query,
            cx=GOOGLE_CX,
            searchType="image",
            num=num
        ).execute()

        if "items" not in result:
            return []

        return [item["link"] for item in result["items"]]
    except Exception as e:
        print(f"  ❌ 이미지 검색 실패: {e}")
        return []

def download_image(image_url):
    """URL에서 이미지 다운로드"""
    try:
        response = requests.get(image_url, timeout=10)
        response.raise_for_status()
        return Image.open(BytesIO(response.content))
    except Exception as e:
        print(f"  ❌ 이미지 다운로드 실패: {e}")
        return None

# ==================== OCR (Apple Vision or Tesseract) ====================

def extract_text_from_image(image):
    """이미지에서 텍스트 추출 (Apple Vision 우선, Tesseract fallback)"""
    if IS_MACOS:
        return extract_text_apple_vision(image)
    else:
        return extract_text_tesseract(image)

def extract_text_apple_vision(image):
    """Apple Vision OCR로 이미지에서 텍스트 추출 (macOS 전용, 무료!)"""
    try:
        # PIL Image를 임시 파일로 저장
        temp_path = "/tmp/menu_temp.jpg"
        image.save(temp_path)

        # 이미지 URL 생성
        image_url = NSURL.fileURLWithPath_(temp_path)

        # Vision 요청 생성
        request = Vision.VNRecognizeTextRequest.alloc().init()
        request.setRecognitionLanguages_(["ko-KR", "en-US"])  # 한글 + 영어
        request.setRecognitionLevel_(Vision.VNRequestTextRecognitionLevelAccurate)  # 정확도 우선
        request.setUsesLanguageCorrection_(True)  # 언어 교정 사용

        # 이미지 핸들러 생성
        ci_image = CIImage.imageWithContentsOfURL_(image_url)
        handler = Vision.VNImageRequestHandler.alloc().initWithCIImage_options_(ci_image, None)

        # OCR 실행
        success = handler.performRequests_error_([request], None)

        if not success:
            print("  ❌ Vision OCR 실패")
            return ""

        # 결과 추출
        results = request.results()
        if not results:
            return ""

        # 모든 인식된 텍스트를 줄바꿈으로 연결
        text_lines = []
        for observation in results:
            candidates = observation.topCandidates_(1)
            if candidates and len(candidates) > 0:
                text_lines.append(candidates[0].string())

        # 임시 파일 삭제
        os.remove(temp_path)

        return "\n".join(text_lines)

    except Exception as e:
        print(f"  ❌ Apple Vision OCR 실패: {e}")
        return ""

def extract_text_tesseract(image):
    """Tesseract OCR로 이미지에서 텍스트 추출 (fallback)"""
    try:
        # 한글 + 영어 인식
        text = pytesseract.image_to_string(image, lang='kor+eng')
        return text
    except Exception as e:
        print(f"  ❌ Tesseract OCR 실패: {e}")
        return ""

def parse_menus(text, restaurant_id):
    """추출된 텍스트에서 메뉴 정보 파싱"""
    menus = []
    lines = [line.strip() for line in text.split('\n') if line.strip()]

    menu_name = None

    for line in lines:
        # 가격 패턴 찾기 (예: 10,000원, 10000원)
        price_match = re.search(r'([0-9,]+)\s*원', line)

        if price_match:
            price_str = price_match.group(1).replace(',', '')
            try:
                price = int(price_str)
            except ValueError:
                continue

            # 가격 앞의 텍스트를 메뉴명으로 추정
            menu_name_candidate = re.sub(r'[0-9,]+\s*원', '', line).strip()

            if menu_name_candidate:
                menu_name = menu_name_candidate

            if menu_name and price > 0:
                # 재료 추출 (괄호 안 내용)
                ingredients = extract_ingredients(line)

                menu = {
                    "id": str(uuid.uuid4()),
                    "restaurantId": restaurant_id,
                    "name": menu_name,
                    "price": price,
                    "ingredients": ingredients,
                    "createdAt": datetime.now()
                }
                menus.append(menu)
                menu_name = None  # 초기화

    return menus

def extract_ingredients(text):
    """괄호 안 재료 추출"""
    ingredients = []
    matches = re.findall(r'\(([^)]+)\)', text)
    for match in matches:
        items = [item.strip() for item in match.split(',')]
        ingredients.extend(items)
    return ingredients

# ==================== 메뉴 자동 수집 ====================

def auto_collect_menus(restaurant, db):
    """한 식당의 메뉴를 자동으로 수집"""
    print(f"\n{'='*60}")
    print(f"🍴 {restaurant['name']} ({restaurant['category']})")
    print(f"📍 {restaurant['address']}")

    # 1. 구글 이미지 검색
    print("  🔍 메뉴판 이미지 검색 중...")
    image_urls = search_menu_images(restaurant['name'])

    if not image_urls:
        print("  ⚠️  메뉴판 이미지를 찾을 수 없습니다")
        return []

    print(f"  ✅ {len(image_urls)}개 이미지 발견")

    all_menus = []

    # 2. 각 이미지 다운로드 및 OCR (최대 3개)
    for idx, image_url in enumerate(image_urls[:3], 1):
        print(f"  📥 [{idx}/{min(3, len(image_urls))}] 이미지 처리 중...")

        # 이미지 다운로드
        image = download_image(image_url)
        if not image:
            continue

        # OCR로 텍스트 추출
        text = extract_text_from_image(image)
        if not text:
            print("    ⚠️  텍스트 추출 실패")
            continue

        # 메뉴 파싱
        menus = parse_menus(text, restaurant['id'])
        if menus:
            print(f"    ✅ {len(menus)}개 메뉴 발견")
            all_menus.extend(menus)

        # 이미지 즉시 삭제 (메모리 절약 + 저작권 보호)
        del image

    # 3. 중복 제거
    unique_menus = remove_duplicate_menus(all_menus)

    # 4. Firestore에 저장
    if unique_menus:
        print(f"  💾 Firestore에 {len(unique_menus)}개 메뉴 저장 중...")
        save_menus_to_firestore(unique_menus, db)
        print(f"  ✅ 저장 완료!")

    return unique_menus

def remove_duplicate_menus(menus):
    """중복 메뉴 제거 (메뉴명 기준)"""
    seen = set()
    unique = []
    for menu in menus:
        normalized_name = menu['name'].lower().strip()
        if normalized_name not in seen:
            seen.add(normalized_name)
            unique.append(menu)
    return unique

def save_menus_to_firestore(menus, db):
    """Firestore에 메뉴 저장"""
    for menu in menus:
        doc_ref = db.collection('restaurants').document(menu['restaurantId']).collection('menus').document(menu['id'])
        doc_ref.set(menu)

# ==================== 메인 ====================

def main():
    parser = argparse.ArgumentParser(description='SafeEat 자동 메뉴 수집')
    parser.add_argument('--location', default='평촌', help='수집할 지역 (기본: 평촌)')
    parser.add_argument('--limit', type=int, default=10, help='수집할 식당 수 (기본: 10)')
    args = parser.parse_args()

    print("=" * 60)
    print("🍽️  SafeEat 자동 메뉴 수집 시스템")
    print("=" * 60)
    print(f"📍 지역: {args.location}")
    print(f"🏪 식당 수: {args.limit}")
    print()

    # Firebase 초기화
    print("🔥 Firebase 연결 중...")
    db = init_firebase()
    print("✅ Firebase 연결 완료")

    # 식당 검색
    print(f"\n🔍 {args.location} 지역 식당 검색 중...")
    restaurants = search_restaurants(args.location, size=args.limit)
    print(f"✅ {len(restaurants)}개 식당 발견")

    # 메뉴 수집
    total_menus = 0
    success_count = 0

    for idx, restaurant in enumerate(restaurants, 1):
        print(f"\n진행: {idx}/{len(restaurants)}")

        try:
            menus = auto_collect_menus(restaurant, db)
            if menus:
                total_menus += len(menus)
                success_count += 1

            # API 제한 방지 (1초 대기)
            time.sleep(1)

        except Exception as e:
            print(f"  ❌ 오류 발생: {e}")
            continue

    # 최종 결과
    print("\n" + "=" * 60)
    print("📊 수집 완료!")
    print("=" * 60)
    print(f"✅ 성공: {success_count}/{len(restaurants)} 식당")
    print(f"🍽️  총 메뉴: {total_menus}개")
    print("=" * 60)

if __name__ == "__main__":
    main()
