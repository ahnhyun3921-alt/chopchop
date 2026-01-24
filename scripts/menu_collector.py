#!/usr/bin/env python3
"""
SafeEat 자동 메뉴 수집 스크립트
완전 무료 메뉴 데이터 수집 시스템 (Apple Vision OCR 사용)

사용 방법:
1. requirements.txt 설치: pip install -r requirements.txt
2. Firebase 인증 파일 다운로드: firebase-admin-key.json
3. 실행: python menu_collector.py --location "평촌" --limit 10

테스트 모드 (Firebase 저장 없이):
  python menu_collector.py --location "평촌" --limit 3 --dry-run --debug

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
from urllib.parse import urlparse
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
import urllib3

# SSL 경고 숨기기
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# ==================== 전역 설정 ====================
DEBUG_MODE = False

def debug_log(message):
    """디버그 모드일 때만 출력"""
    if DEBUG_MODE:
        print(f"    [DEBUG] {message}")

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
    try:
        import pytesseract
    except ImportError:
        print("❌ pytesseract 미설치. 설치: pip install pytesseract")

# ==================== 설정 ====================

# Kakao REST API 키 (https://developers.kakao.com/)
KAKAO_API_KEY = os.environ.get("KAKAO_API_KEY", "076dadf5b4de23d8c6ce0340ecfa9201")

# 네이버 검색 API 키 (https://developers.naver.com/)
NAVER_CLIENT_ID = os.environ.get("NAVER_CLIENT_ID", "5mtTvlnrdwnNfvsAUziZ")
NAVER_CLIENT_SECRET = os.environ.get("NAVER_CLIENT_SECRET", "zynF6nUH11")

# Firebase Admin SDK 인증 파일 경로
FIREBASE_CRED_PATH = "firebase-admin-key.json"

# ==================== Firebase 초기화 ====================

def init_firebase(dry_run=False):
    """Firebase Admin SDK 초기화"""
    if dry_run:
        print("🧪 Dry-run 모드: Firebase 연결 건너뜀")
        return None

    if not os.path.exists(FIREBASE_CRED_PATH):
        print(f"❌ Firebase 인증 파일이 없습니다: {FIREBASE_CRED_PATH}")
        print("   Firebase Console에서 서비스 계정 키를 다운로드하세요.")
        return None

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

    try:
        response = requests.get(url, headers=headers, params=params)
        response.raise_for_status()
        data = response.json()
    except Exception as e:
        print(f"❌ 카카오 API 오류: {e}")
        return []

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

# ==================== 네이버 이미지 검색 ====================

def search_menu_images(restaurant_name, location, num=10):
    """네이버 이미지 검색으로 메뉴 이미지 URL 찾기

    Args:
        restaurant_name: 식당 이름
        location: 지역명 (필수!)
        num: 검색할 이미지 수
    """
    url = "https://openapi.naver.com/v1/search/image"
    headers = {
        "X-Naver-Client-Id": NAVER_CLIENT_ID,
        "X-Naver-Client-Secret": NAVER_CLIENT_SECRET
    }

    # 검색 쿼리 조합 (지역 + 식당명 + 메뉴)
    query = f"{location} {restaurant_name} 메뉴판"
    debug_log(f"검색 쿼리: '{query}'")

    params = {
        "query": query,
        "display": min(num, 100),  # 최대 100개
        "sort": "sim"  # 유사도순
    }

    try:
        response = requests.get(url, headers=headers, params=params)
        response.raise_for_status()
        data = response.json()

        if "items" not in data:
            debug_log(f"검색 결과 없음: {data}")
            return []

        results = []
        for item in data["items"]:
            results.append({
                "url": item["link"],
                "title": item.get("title", ""),
                "source": urlparse(item["link"]).netloc
            })

        debug_log(f"검색 결과 {len(results)}개")
        return results

    except Exception as e:
        print(f"  ❌ 이미지 검색 실패: {e}")
        return []

def get_referer_for_url(image_url):
    """이미지 URL에 맞는 Referer 헤더 생성"""
    parsed = urlparse(image_url)
    domain = parsed.netloc

    # 주요 도메인별 Referer 설정
    referer_map = {
        "postfiles.pstatic.net": "https://blog.naver.com/",
        "blogfiles.naver.net": "https://blog.naver.com/",
        "cafeptthumb-phinf.pstatic.net": "https://cafe.naver.com/",
        "img1.daumcdn.net": "https://blog.daum.net/",
        "t1.daumcdn.net": "https://blog.daum.net/",
        "k.kakaocdn.net": "https://story.kakao.com/",
        "img.khan.co.kr": "https://www.khan.co.kr/",
    }

    for key, referer in referer_map.items():
        if key in domain:
            return referer

    # 기본: 같은 도메인을 Referer로 사용
    return f"https://{domain}/"

def download_image(image_url):
    """URL에서 이미지 다운로드 (동적 Referer 설정)"""
    try:
        referer = get_referer_for_url(image_url)
        debug_log(f"다운로드: {image_url[:60]}...")
        debug_log(f"Referer: {referer}")

        headers = {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Referer': referer,
            'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
            'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
        }
        response = requests.get(image_url, headers=headers, timeout=15, verify=False)
        response.raise_for_status()

        # 이미지 형식 확인
        content_type = response.headers.get('Content-Type', '')
        if 'image' not in content_type and len(response.content) < 1000:
            debug_log(f"이미지가 아님: {content_type}")
            return None

        img = Image.open(BytesIO(response.content))

        # 너무 작은 이미지 필터링 (썸네일 제외)
        if img.width < 200 or img.height < 200:
            debug_log(f"이미지가 너무 작음: {img.width}x{img.height}")
            return None

        debug_log(f"다운로드 성공: {img.width}x{img.height}")
        return img

    except Exception as e:
        debug_log(f"다운로드 실패: {str(e)[:80]}")
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

        # RGB로 변환 (RGBA인 경우)
        if image.mode == 'RGBA':
            image = image.convert('RGB')
        image.save(temp_path, 'JPEG')

        # 이미지 URL 생성
        image_url = NSURL.fileURLWithPath_(temp_path)

        # Vision 요청 생성
        request = Vision.VNRecognizeTextRequest.alloc().init()
        request.setRecognitionLanguages_(["ko-KR", "en-US"])  # 한글 + 영어
        request.setRecognitionLevel_(Vision.VNRequestTextRecognitionLevelAccurate)
        request.setUsesLanguageCorrection_(True)

        # 이미지 핸들러 생성
        ci_image = CIImage.imageWithContentsOfURL_(image_url)
        handler = Vision.VNImageRequestHandler.alloc().initWithCIImage_options_(ci_image, None)

        # OCR 실행
        success = handler.performRequests_error_([request], None)

        if not success:
            debug_log("Vision OCR 요청 실패")
            return ""

        # 결과 추출
        results = request.results()
        if not results:
            debug_log("Vision OCR 결과 없음")
            return ""

        # 모든 인식된 텍스트를 줄바꿈으로 연결
        text_lines = []
        for observation in results:
            candidates = observation.topCandidates_(1)
            if candidates and len(candidates) > 0:
                text_lines.append(candidates[0].string())

        # 임시 파일 삭제
        os.remove(temp_path)

        text = "\n".join(text_lines)
        debug_log(f"OCR 추출 텍스트 ({len(text_lines)}줄):\n{text[:500]}...")
        return text

    except Exception as e:
        debug_log(f"Apple Vision OCR 실패: {e}")
        return ""

def extract_text_tesseract(image):
    """Tesseract OCR로 이미지에서 텍스트 추출 (fallback)"""
    try:
        # RGB로 변환 (RGBA인 경우)
        if image.mode == 'RGBA':
            image = image.convert('RGB')

        # 한글 + 영어 인식
        text = pytesseract.image_to_string(image, lang='kor+eng')
        debug_log(f"Tesseract OCR 결과:\n{text[:500]}...")
        return text
    except Exception as e:
        debug_log(f"Tesseract OCR 실패: {e}")
        return ""

# ==================== 메뉴 파싱 (개선된 버전) ====================

def parse_price(text):
    """다양한 가격 형식을 파싱

    지원 형식:
    - 10,000원, 10000원
    - 10,000 / 10000 (원 없이)
    - ₩10,000
    - 1만원, 1만5천원
    - 8천원
    """
    # 1. "만원" 형식 (1만원, 1만5천원, 2만원 등)
    man_pattern = re.search(r'(\d+)\s*만\s*(\d*)\s*천?\s*원?', text)
    if man_pattern:
        man = int(man_pattern.group(1)) * 10000
        chun = int(man_pattern.group(2)) * 1000 if man_pattern.group(2) else 0
        return man + chun

    # 2. "천원" 형식 (8천원, 9천5백원 등)
    chun_pattern = re.search(r'(\d+)\s*천\s*(\d*)\s*백?\s*원?', text)
    if chun_pattern:
        chun = int(chun_pattern.group(1)) * 1000
        baek = int(chun_pattern.group(2)) * 100 if chun_pattern.group(2) else 0
        return chun + baek

    # 3. 숫자+원 형식 (10,000원, 10000원)
    won_pattern = re.search(r'([0-9][0-9,\.]+)\s*원', text)
    if won_pattern:
        price_str = won_pattern.group(1).replace(',', '').replace('.', '')
        try:
            return int(price_str)
        except ValueError:
            pass

    # 4. ₩ 형식
    currency_pattern = re.search(r'₩\s*([0-9][0-9,\.]+)', text)
    if currency_pattern:
        price_str = currency_pattern.group(1).replace(',', '').replace('.', '')
        try:
            return int(price_str)
        except ValueError:
            pass

    # 5. 숫자만 있는 경우 (메뉴판에서 흔함)
    # "김치찌개 8,000" 또는 "김치찌개 8000" 또는 "김치찌개...8,000"
    number_pattern = re.search(r'[\.\s]+([0-9][0-9,]+)$', text)
    if number_pattern:
        price_str = number_pattern.group(1).replace(',', '')
        try:
            price = int(price_str)
            # 합리적인 가격 범위인지 확인 (1,000 ~ 500,000)
            if 1000 <= price <= 500000:
                return price
        except ValueError:
            pass

    # 6. 줄 끝의 4-6자리 숫자 (쉼표 없이)
    end_number = re.search(r'\s(\d{4,6})$', text)
    if end_number:
        try:
            price = int(end_number.group(1))
            if 1000 <= price <= 500000:
                return price
        except ValueError:
            pass

    return None

def extract_menu_name(line, price_text=None):
    """라인에서 메뉴명 추출"""
    menu_name = line

    # 가격 관련 텍스트 제거
    patterns_to_remove = [
        r'₩?\s*[0-9][0-9,\.]+\s*원?',  # 가격
        r'\d+\s*만\s*\d*\s*천?\s*원?',  # X만원
        r'\d+\s*천\s*\d*\s*백?\s*원?',  # X천원
        r'\.{2,}',  # 점선
        r'\s{2,}',  # 연속 공백
    ]

    for pattern in patterns_to_remove:
        menu_name = re.sub(pattern, ' ', menu_name)

    # 앞뒤 공백 및 특수문자 정리
    menu_name = menu_name.strip(' .-_:')

    # 너무 짧거나 숫자만 있으면 무효
    if len(menu_name) < 2 or menu_name.isdigit():
        return None

    return menu_name

def parse_menus(text, restaurant_id):
    """추출된 텍스트에서 메뉴 정보 파싱 (개선된 버전)"""
    menus = []
    lines = [line.strip() for line in text.split('\n') if line.strip()]

    debug_log(f"파싱할 라인 수: {len(lines)}")

    for line in lines:
        # 가격 파싱
        price = parse_price(line)

        if price:
            # 메뉴명 추출
            menu_name = extract_menu_name(line)

            if menu_name:
                debug_log(f"메뉴 발견: '{menu_name}' = {price:,}원")

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

    debug_log(f"총 {len(menus)}개 메뉴 파싱됨")
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

def auto_collect_menus(restaurant, location, db, dry_run=False):
    """한 식당의 메뉴를 자동으로 수집

    Args:
        restaurant: 식당 정보 dict
        location: 지역명 (중요!)
        db: Firestore 클라이언트
        dry_run: True면 저장하지 않고 테스트만
    """
    print(f"\n{'='*60}")
    print(f"🍴 {restaurant['name']} ({restaurant['category']})")
    print(f"📍 {restaurant['address']}")

    # 1. 네이버 이미지 검색 (location 파라미터 전달!)
    print(f"  🔍 '{location} {restaurant['name']} 메뉴판' 검색 중...")
    image_results = search_menu_images(restaurant['name'], location=location, num=20)

    if not image_results:
        print("  ⚠️  메뉴 이미지를 찾을 수 없습니다")
        return []

    print(f"  ✅ {len(image_results)}개 이미지 발견")

    all_menus = []
    successful_images = 0
    max_successful = 3  # 성공적으로 처리할 이미지 개수

    # 2. 각 이미지 다운로드 및 OCR
    for idx, img_info in enumerate(image_results, 1):
        if successful_images >= max_successful:
            break

        image_url = img_info["url"]
        source = img_info.get("source", "unknown")

        print(f"  📥 [{successful_images+1}/{max_successful}] 이미지 {idx} ({source})")

        # 이미지 다운로드
        image = download_image(image_url)
        if not image:
            print(f"    ⚠️  다운로드 실패")
            continue

        # OCR로 텍스트 추출
        print(f"    🔤 OCR 처리 중...")
        text = extract_text_from_image(image)
        if not text:
            print("    ⚠️  텍스트 추출 실패")
            continue

        # 메뉴 파싱
        menus = parse_menus(text, restaurant['id'])
        if menus:
            print(f"    ✅ {len(menus)}개 메뉴 발견")
            for menu in menus[:5]:  # 처음 5개만 미리보기
                print(f"       - {menu['name']}: {menu['price']:,}원")
            if len(menus) > 5:
                print(f"       ... 외 {len(menus)-5}개")
            all_menus.extend(menus)
            successful_images += 1
        else:
            print("    ⚠️  메뉴 파싱 실패 (가격 패턴 없음)")

        # 이미지 즉시 삭제 (메모리 절약)
        del image

    # 3. 중복 제거
    unique_menus = remove_duplicate_menus(all_menus)

    # 4. Firestore에 저장 (dry_run이 아닐 때만)
    if unique_menus:
        if dry_run:
            print(f"  🧪 [Dry-run] {len(unique_menus)}개 메뉴 발견 (저장 안 함)")
        elif db:
            print(f"  💾 Firestore에 {len(unique_menus)}개 메뉴 저장 중...")
            save_menus_to_firestore(unique_menus, db)
            print(f"  ✅ 저장 완료!")
        else:
            print(f"  ⚠️  Firebase 미연결, {len(unique_menus)}개 메뉴 저장 안 됨")

    return unique_menus

def remove_duplicate_menus(menus):
    """중복 메뉴 제거 (메뉴명 기준)"""
    seen = set()
    unique = []
    for menu in menus:
        # 정규화: 소문자, 공백 제거
        normalized_name = re.sub(r'\s+', '', menu['name'].lower())
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
    global DEBUG_MODE

    parser = argparse.ArgumentParser(description='SafeEat 자동 메뉴 수집')
    parser.add_argument('--location', default='평촌', help='수집할 지역 (기본: 평촌)')
    parser.add_argument('--limit', type=int, default=10, help='수집할 식당 수 (기본: 10)')
    parser.add_argument('--debug', action='store_true', help='디버그 모드 (상세 로그 출력)')
    parser.add_argument('--dry-run', action='store_true', help='테스트 모드 (Firebase 저장 안 함)')
    args = parser.parse_args()

    DEBUG_MODE = args.debug

    print("=" * 60)
    print("🍽️  SafeEat 자동 메뉴 수집 시스템")
    print("=" * 60)
    print(f"📍 지역: {args.location}")
    print(f"🏪 식당 수: {args.limit}")
    if args.debug:
        print("🐛 디버그 모드: ON")
    if args.dry_run:
        print("🧪 테스트 모드: ON (저장 안 함)")
    print()

    # Firebase 초기화
    print("🔥 Firebase 연결 중...")
    db = init_firebase(dry_run=args.dry_run)
    if db:
        print("✅ Firebase 연결 완료")
    elif not args.dry_run:
        print("⚠️  Firebase 없이 진행 (메뉴 저장 안 됨)")

    # 식당 검색
    print(f"\n🔍 {args.location} 지역 식당 검색 중...")
    restaurants = search_restaurants(args.location, size=args.limit)

    if not restaurants:
        print("❌ 식당을 찾을 수 없습니다. 지역명을 확인해주세요.")
        return

    print(f"✅ {len(restaurants)}개 식당 발견")
    for r in restaurants[:5]:
        print(f"   - {r['name']} ({r['category']})")
    if len(restaurants) > 5:
        print(f"   ... 외 {len(restaurants)-5}개")

    # 메뉴 수집
    total_menus = 0
    success_count = 0

    for idx, restaurant in enumerate(restaurants, 1):
        print(f"\n진행: {idx}/{len(restaurants)}")

        try:
            # location을 명시적으로 전달!
            menus = auto_collect_menus(
                restaurant,
                location=args.location,
                db=db,
                dry_run=args.dry_run
            )
            if menus:
                total_menus += len(menus)
                success_count += 1

            # API 제한 방지 (1초 대기)
            time.sleep(1)

        except Exception as e:
            print(f"  ❌ 오류 발생: {e}")
            if args.debug:
                import traceback
                traceback.print_exc()
            continue

    # 최종 결과
    print("\n" + "=" * 60)
    print("📊 수집 완료!")
    print("=" * 60)
    print(f"✅ 성공: {success_count}/{len(restaurants)} 식당")
    print(f"🍽️  총 메뉴: {total_menus}개")
    if args.dry_run:
        print("🧪 (테스트 모드 - 실제 저장되지 않음)")
    print("=" * 60)

if __name__ == "__main__":
    main()
