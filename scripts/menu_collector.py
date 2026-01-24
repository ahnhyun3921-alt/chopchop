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
import json
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

# Claude API (선택적)
try:
    import anthropic
    CLAUDE_AVAILABLE = True
except ImportError:
    CLAUDE_AVAILABLE = False

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

# Claude API 키 (AI 메뉴 보정용, 선택적)
CLAUDE_API_KEY = os.environ.get("ANTHROPIC_API_KEY", "")

# AI 파싱 사용 여부
USE_AI_PARSING = False  # --ai 옵션으로 활성화

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
    """카카오 로컬 API로 식당 검색 (페이지네이션 지원)

    카카오 API는 한 번에 최대 15개까지만 반환.
    더 많은 결과가 필요하면 여러 페이지를 가져옴.
    """
    url = "https://dapi.kakao.com/v2/local/search/keyword.json"
    headers = {"Authorization": f"KakaoAK {KAKAO_API_KEY}"}

    restaurants = []
    seen_ids = set()  # 중복 방지
    page = 1
    max_pages = (size + 14) // 15  # 필요한 페이지 수 계산

    while len(restaurants) < size and page <= max_pages:
        params = {
            "query": f"{location} 맛집",
            "category_group_code": "FD6",  # 음식점
            "size": min(15, size - len(restaurants)),  # 최대 15
            "page": page,
            "radius": radius
        }

        try:
            response = requests.get(url, headers=headers, params=params)
            response.raise_for_status()
            data = response.json()
        except Exception as e:
            print(f"❌ 카카오 API 오류: {e}")
            break

        documents = data.get("documents", [])
        if not documents:
            break  # 더 이상 결과 없음

        for doc in documents:
            if doc["id"] in seen_ids:
                continue
            seen_ids.add(doc["id"])

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

            if len(restaurants) >= size:
                break

        # 다음 페이지가 없으면 종료
        if data.get("meta", {}).get("is_end", True):
            break

        page += 1
        time.sleep(0.2)  # API 제한 방지

    return restaurants

# ==================== 네이버 이미지 검색 ====================

def clean_restaurant_name(name):
    """식당명 정제 (검색 최적화)

    1. 지점명 제거: "맛있는집 평촌점" → "맛있는집"
    2. 특수문자 제거: "맛있는집(본점)" → "맛있는집"
    3. 연속 공백 정리: "맛있는  집" → "맛있는 집"
    """
    # 1. 괄호 안 내용 제거: (본점), [평촌], 【직영】 등
    name = re.sub(r'[\(\[\【\<][^\)\]\】\>]*[\)\]\】\>]', '', name)

    # 2. 지점명 제거: 공백 + 무언가 + 점
    name = re.sub(r'\s+\S+점$', '', name)

    # 3. 특수문자 제거 (한글, 영문, 숫자, 공백만 유지)
    name = re.sub(r'[^\w\s가-힣a-zA-Z0-9]', ' ', name)

    # 4. 연속 공백을 하나로
    name = re.sub(r'\s+', ' ', name)

    return name.strip()

def search_menu_images(restaurant_name, location, num=10):
    """이미지 검색 (DuckDuckGo 사용 - API 키 불필요)

    Args:
        restaurant_name: 식당 이름
        location: 지역명 (필수!)
        num: 검색할 이미지 수
    """
    # 지점명 제거 (예: '맛있는집 평촌점' → '맛있는집')
    clean_name = clean_restaurant_name(restaurant_name)

    # 검색 쿼리 조합 (지역 + 식당명(지점명 제외) + 메뉴판)
    query = f"{location} {clean_name} 메뉴판"
    debug_log(f"원래 식당명: '{restaurant_name}'")
    debug_log(f"정제된 식당명: '{clean_name}'")
    debug_log(f"검색 쿼리: '{query}'")

    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    }

    try:
        # DuckDuckGo 이미지 검색
        # 먼저 토큰 얻기
        token_url = "https://duckduckgo.com/"
        token_params = {"q": query}
        token_resp = requests.get(token_url, params=token_params, headers=headers, timeout=10)

        # vqd 토큰 추출
        vqd_match = re.search(r'vqd=([\d-]+)', token_resp.text)
        if not vqd_match:
            vqd_match = re.search(r'vqd="([\d-]+)"', token_resp.text)
        if not vqd_match:
            debug_log("DuckDuckGo 토큰을 찾을 수 없음")
            return []

        vqd = vqd_match.group(1)
        debug_log(f"DuckDuckGo vqd 토큰: {vqd}")

        # 이미지 검색
        image_url = "https://duckduckgo.com/i.js"
        image_params = {
            "l": "kr-kr",
            "o": "json",
            "q": query,
            "vqd": vqd,
            "f": ",,,",
            "p": "1",
        }

        image_resp = requests.get(image_url, params=image_params, headers=headers, timeout=10)
        data = image_resp.json()

        results = []
        for item in data.get("results", [])[:num]:
            results.append({
                "url": item.get("image", ""),
                "title": item.get("title", ""),
                "source": item.get("source", "")
            })

        debug_log(f"검색 결과 {len(results)}개")
        return results

    except Exception as e:
        debug_log(f"DuckDuckGo 검색 실패: {e}")

    # 폴백: 구글 이미지 검색 (간단한 스크래핑)
    try:
        debug_log("Google 이미지 검색 시도...")
        google_url = f"https://www.google.com/search?q={requests.utils.quote(query)}&tbm=isch"
        google_resp = requests.get(google_url, headers=headers, timeout=10)

        # 이미지 URL 추출
        img_pattern = r'\["(https://[^"]+\.(?:jpg|jpeg|png|webp))"'
        matches = re.findall(img_pattern, google_resp.text, re.IGNORECASE)

        results = []
        seen = set()
        for url in matches[:num*2]:  # 더 많이 찾아서 필터링
            if url not in seen and 'gstatic' not in url:
                seen.add(url)
                results.append({
                    "url": url,
                    "title": query,
                    "source": urlparse(url).netloc
                })
            if len(results) >= num:
                break

        debug_log(f"Google 검색 결과 {len(results)}개")
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

def format_price(price):
    """가격을 통일된 형식으로 포맷 (예: 8000 → "8,000원")"""
    return f"{price:,}원"

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
    ]

    for pattern in patterns_to_remove:
        menu_name = re.sub(pattern, '', menu_name)

    # OCR 오류 문자 정리 (특수문자 모두 제거)
    menu_name = clean_ocr_text(menu_name)

    # 너무 짧거나 숫자만 있으면 무효
    if len(menu_name) < 2 or menu_name.isdigit():
        return None

    return menu_name

# ==================== AI 메뉴 파싱 (Claude API) ====================

def parse_menus_with_ai(text, restaurant_id, restaurant_name="", category=""):
    """Claude API로 OCR 텍스트에서 메뉴 추출 (더 정확함)"""
    if not CLAUDE_AVAILABLE or not CLAUDE_API_KEY:
        debug_log("Claude API 사용 불가, 기본 파싱 사용")
        return None

    try:
        client = anthropic.Anthropic(api_key=CLAUDE_API_KEY)

        prompt = f"""다음은 '{restaurant_name}' ({category}) 식당의 메뉴판 OCR 텍스트입니다.
이 텍스트에서 메뉴명과 가격을 추출해주세요.

OCR 텍스트:
{text}

규칙:
1. OCR 오타를 보정해주세요 (예: "김치찌게" → "김치찌개", "볶읍밥" → "볶음밥")
2. 메뉴명에서 가격, 숫자, 특수문자를 제거해주세요
3. 가격은 숫자만 (예: 8000)
4. 명확한 메뉴-가격 쌍만 추출하세요
5. 식당 카테고리({category})에 맞지 않는 메뉴는 제외하세요

JSON 형식으로만 응답해주세요:
{{"menus": [{{"name": "메뉴명", "price": 가격숫자}}]}}"""

        response = client.messages.create(
            model="claude-3-haiku-20240307",
            max_tokens=1024,
            messages=[{"role": "user", "content": prompt}]
        )

        # JSON 파싱
        response_text = response.content[0].text
        # JSON 부분만 추출
        json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
        if json_match:
            data = json.loads(json_match.group())
            menus = []
            for item in data.get("menus", []):
                if item.get("name") and item.get("price"):
                    menu_name = item["name"]
                    menu = {
                        "id": str(uuid.uuid4()),
                        "restaurantId": restaurant_id,
                        "name": menu_name,
                        "price": int(item["price"]),
                        "priceText": format_price(int(item["price"])),
                        "menuCategory": classify_menu(menu_name),
                        "ingredients": [],
                        "createdAt": datetime.now()
                    }
                    menus.append(menu)
            debug_log(f"AI 파싱 결과: {len(menus)}개 메뉴")
            return menus

    except Exception as e:
        debug_log(f"AI 파싱 실패: {e}")

    return None

# ==================== 오타 교정 사전 ====================

TYPO_CORRECTIONS = {
    # 찌개류
    "찌게": "찌개", "찌게": "찌개", "찌깨": "찌개",
    "김치찌게": "김치찌개", "된장찌게": "된장찌개", "순두부찌게": "순두부찌개",
    # 볶음류
    "볶읍": "볶음", "뽁음": "볶음", "볶옴": "볶음",
    "제육볶읍": "제육볶음", "오징어볶읍": "오징어볶음",
    # 밥류
    "비빔밥": "비빔밥", "볶읍밥": "볶음밥", "덮밥": "덮밥",
    # 면류
    "짜장": "짜장", "짬뽕": "짬뽕", "우동": "우동",
    "칼국수": "칼국수", "칼국숫": "칼국수", "칼굿수": "칼국수",
    # 고기류
    "삼겹살": "삼겹살", "삼겹": "삼겹살", "목살": "목살",
    "갈비": "갈비", "갈비살": "갈비살",
    # 탕/국류
    "설렁탕": "설렁탕", "설렁탕": "설렁탕", "설농탕": "설렁탕",
    "감자탕": "감자탕", "뼈해장국": "뼈해장국",
    "국밥": "국밥", "국밥": "국밥",
    # 일식
    "돈까스": "돈까스", "돈가스": "돈까스", "톤까스": "돈까스",
    "우동": "우동", "라멘": "라멘", "라면": "라면",
    # 중식
    "짜장면": "짜장면", "자장면": "짜장면",
    "짬뽕": "짬뽕", "짬봉": "짬뽕",
    "탕수육": "탕수육", "탕슈육": "탕수육",
    # 기타
    "비빔냉면": "비빔냉면", "물냉면": "물냉면",
    "공기밥": "공기밥", "공기밥": "공기밥",
    "계란": "계란", "게란": "계란",
}

def correct_typos(text):
    """오타 교정"""
    corrected = text
    for typo, correct in TYPO_CORRECTIONS.items():
        corrected = corrected.replace(typo, correct)
    return corrected

# ==================== 메뉴 카테고리 분류 ====================

MENU_CATEGORIES = {
    "밥류": ["밥", "비빔밥", "덮밥", "볶음밥", "김밥", "공기밥", "정식", "백반", "쌈밥"],
    "면류": ["면", "국수", "칼국수", "냉면", "라면", "라멘", "우동", "파스타", "짜장면", "짬뽕", "쌀국수"],
    "찌개/탕류": ["찌개", "탕", "전골", "국", "국밥", "설렁탕", "감자탕", "부대찌개", "순두부", "된장"],
    "고기류": ["고기", "삼겹살", "목살", "갈비", "불고기", "제육", "수육", "보쌈", "족발", "곱창", "막창"],
    "튀김류": ["튀김", "돈까스", "돈가스", "치킨", "탕수육", "꿔바로우", "텐동"],
    "분식류": ["떡볶이", "순대", "튀김", "오뎅", "김밥", "라볶이", "만두"],
    "해물류": ["회", "초밥", "생선", "해물", "새우", "오징어", "조개", "굴", "전복", "랍스터"],
    "일식": ["스시", "사시미", "롤", "덮밥", "라멘", "우동", "돈부리", "가츠동"],
    "중식": ["짜장", "짬뽕", "탕수육", "마파두부", "깐풍기", "유린기", "양장피"],
    "양식": ["스테이크", "파스타", "피자", "리조또", "햄버거", "샐러드", "수프"],
    "음료/디저트": ["음료", "커피", "차", "주스", "에이드", "스무디", "아이스크림", "케이크", "빵"],
    "주류": ["소주", "맥주", "막걸리", "사케", "와인", "칵테일"],
    "사이드": ["공기밥", "계란", "김치", "반찬", "샐러드", "피클"],
}

# 카테고리 우선순위 (정렬용)
CATEGORY_ORDER = [
    "밥류", "면류", "찌개/탕류", "고기류", "튀김류", "분식류",
    "해물류", "일식", "중식", "양식", "사이드", "음료/디저트", "주류", "기타"
]

# 음식이 아닌 것들 (필터링용)
NON_FOOD_KEYWORDS = [
    # 일반 텍스트
    "전화", "주소", "영업", "시간", "휴무", "문의", "예약", "배달", "포장",
    "카드", "현금", "계좌", "입금", "결제", "할인", "이벤트", "쿠폰",
    "주차", "wifi", "화장실", "좌석", "테이블", "룸",
    # 숫자/기호만
    "원", "won", "₩", "~", "-", "+",
    # 설명문
    "선택", "추가", "변경", "업그레이드", "세트", "단품", "기본",
    "대", "중", "소", "특대", "점보",
    # 기타
    "안내", "공지", "메뉴판", "가격표", "menu", "price",
]

def clean_ocr_text(text):
    """OCR 오류 문자 정리"""
    if not text:
        return ""

    # 1. 특수문자 모두 제거 (한글, 영문, 숫자, 공백만 유지)
    text = re.sub(r'[^\w\s가-힣a-zA-Z0-9]', '', text)

    # 2. 연속 공백 정리
    text = re.sub(r'\s+', ' ', text)

    return text.strip()

def is_valid_food(menu_name):
    """유효한 음식 메뉴인지 확인"""
    if not menu_name or len(menu_name) < 2:
        return False

    # OCR 쓰레기 문자 정리
    menu_name = clean_ocr_text(menu_name)

    if not menu_name or len(menu_name) < 2:
        return False

    # 숫자만 있으면 제외
    if menu_name.replace(' ', '').isdigit():
        return False

    # 너무 긴 이름은 제외 (설명문일 가능성)
    if len(menu_name) > 20:
        return False

    # 음식 아닌 키워드 포함시 제외
    menu_lower = menu_name.lower()
    for keyword in NON_FOOD_KEYWORDS:
        if keyword in menu_lower:
            return False

    # 한글이 하나도 없으면 제외 (영어/숫자만)
    if not any('\uac00' <= c <= '\ud7a3' for c in menu_name):
        return False

    # 한글 비율이 너무 낮으면 제외 (OCR 오류일 가능성)
    korean_chars = sum(1 for c in menu_name if '\uac00' <= c <= '\ud7a3')
    if korean_chars < len(menu_name) * 0.3:  # 한글 30% 미만이면 제외
        return False

    return True

def classify_menu(menu_name):
    """메뉴명으로 카테고리 분류"""
    menu_lower = menu_name.lower()

    for category, keywords in MENU_CATEGORIES.items():
        for keyword in keywords:
            if keyword in menu_lower:
                return category

    return "기타"

def parse_menus(text, restaurant_id, restaurant_name="", category=""):
    """추출된 텍스트에서 메뉴 정보 파싱 (개선된 버전)"""

    # AI 파싱 사용 (옵션)
    if USE_AI_PARSING:
        ai_result = parse_menus_with_ai(text, restaurant_id, restaurant_name, category)
        if ai_result:
            return ai_result

    # 오타 교정
    text = correct_typos(text)

    menus = []
    lines = [line.strip() for line in text.split('\n') if line.strip()]

    debug_log(f"파싱할 라인 수: {len(lines)}")

    for line in lines:
        # 가격 파싱
        price = parse_price(line)

        if price:
            # 메뉴명 추출
            menu_name = extract_menu_name(line)

            if menu_name and is_valid_food(menu_name):
                debug_log(f"메뉴 발견: '{menu_name}' = {price:,}원")

                # 재료 추출 (괄호 안 내용)
                ingredients = extract_ingredients(line)

                menu = {
                    "id": str(uuid.uuid4()),
                    "restaurantId": restaurant_id,
                    "name": menu_name,
                    "price": price,
                    "priceText": format_price(price),  # "8,000원" 형식
                    "menuCategory": classify_menu(menu_name),  # 메뉴 종류
                    "ingredients": ingredients,
                    "createdAt": datetime.now()
                }
                menus.append(menu)
            elif menu_name:
                debug_log(f"음식 아님, 제외: '{menu_name}'")

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
    clean_name = clean_restaurant_name(restaurant['name'])
    print(f"  🔍 '{location} {clean_name} 메뉴' 검색 중...")
    if clean_name != restaurant['name']:
        print(f"     (원래 이름: {restaurant['name']})")
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

        # 메뉴 파싱 (식당 정보 전달)
        menus = parse_menus(text, restaurant['id'], restaurant['name'], restaurant.get('category', ''))
        if menus:
            print(f"    ✅ {len(menus)}개 메뉴 발견")
            for menu in menus[:5]:  # 처음 5개만 미리보기
                print(f"       - {menu['name']}: {format_price(menu['price'])}")
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
        # 정렬된 메뉴 미리보기
        print(f"  📋 수집된 메뉴 ({len(unique_menus)}개, 가격순 정렬):")
        for menu in unique_menus[:8]:
            print(f"     {menu['name']}: {format_price(menu['price'])}")
        if len(unique_menus) > 8:
            print(f"     ... 외 {len(unique_menus)-8}개")

        if dry_run:
            print(f"  🧪 [Dry-run] 저장 안 함")
        elif db:
            print(f"  💾 Firestore에 저장 중 (중복 체크)...")
            saved = save_menus_to_firestore(unique_menus, db, restaurant['id'])
            print(f"  ✅ {saved}개 새 메뉴 저장 완료!")
        else:
            print(f"  ⚠️  Firebase 미연결, 저장 안 됨")

    return unique_menus

def normalize_menu_name(name):
    """메뉴명 정규화 (중복 비교용)"""
    # 소문자 변환, 공백/특수문자 제거
    normalized = re.sub(r'[\s\-\_\.\,\(\)]+', '', name.lower())
    # 흔한 변형 통일 (ex: 찌개/찌게, 볶음/볶음밥)
    normalized = normalized.replace('찌게', '찌개')
    normalized = normalized.replace('뽁음', '볶음')
    normalized = normalized.replace('비빔밥', '비빔밥')
    return normalized

def remove_duplicate_menus(menus):
    """중복 메뉴 제거 + 카테고리별/가격순 정렬"""
    seen = {}  # {정규화된이름: 메뉴}

    for menu in menus:
        normalized = normalize_menu_name(menu['name'])

        if normalized not in seen:
            seen[normalized] = menu
        else:
            # 이미 있으면, 더 합리적인 가격을 선택 (중간값에 가까운 것)
            existing = seen[normalized]
            # 가격이 더 현실적인 범위(3000~50000)에 가까우면 대체
            existing_score = abs(existing['price'] - 15000)
            new_score = abs(menu['price'] - 15000)
            if new_score < existing_score:
                seen[normalized] = menu

    unique = list(seen.values())

    # 카테고리별 + 가격순 정렬
    def sort_key(menu):
        category = menu.get('menuCategory', '기타')
        category_index = CATEGORY_ORDER.index(category) if category in CATEGORY_ORDER else len(CATEGORY_ORDER)
        return (category_index, menu['price'])

    unique.sort(key=sort_key)

    return unique

def get_existing_menu_names(restaurant_id, db):
    """Firestore에서 기존 메뉴명 가져오기"""
    if not db:
        return set()

    try:
        menus_ref = db.collection('restaurants').document(restaurant_id).collection('menus')
        docs = menus_ref.stream()
        existing = set()
        for doc in docs:
            data = doc.to_dict()
            if 'name' in data:
                existing.add(normalize_menu_name(data['name']))
        return existing
    except Exception as e:
        debug_log(f"기존 메뉴 조회 실패: {e}")
        return set()

def save_menus_to_firestore(menus, db, restaurant_id=None):
    """Firestore에 메뉴 저장 (중복 제외)"""
    if not menus:
        return 0

    # 기존 메뉴 가져오기
    rid = restaurant_id or menus[0]['restaurantId']
    existing_names = get_existing_menu_names(rid, db)

    saved_count = 0
    skipped_count = 0

    for menu in menus:
        normalized = normalize_menu_name(menu['name'])

        # 이미 존재하는 메뉴는 건너뛰기
        if normalized in existing_names:
            debug_log(f"중복 건너뜀: {menu['name']}")
            skipped_count += 1
            continue

        doc_ref = db.collection('restaurants').document(menu['restaurantId']).collection('menus').document(menu['id'])
        doc_ref.set(menu)
        existing_names.add(normalized)  # 방금 저장한 것도 추가
        saved_count += 1

    if skipped_count > 0:
        print(f"    ⏭️  {skipped_count}개 중복 메뉴 건너뜀")

    return saved_count

# ==================== 메인 ====================

def main():
    global DEBUG_MODE

    parser = argparse.ArgumentParser(description='SafeEat 자동 메뉴 수집')
    parser.add_argument('--location', default='평촌', help='수집할 지역 (기본: 평촌)')
    parser.add_argument('--limit', type=int, default=10, help='수집할 식당 수 (기본: 10)')
    parser.add_argument('--debug', action='store_true', help='디버그 모드 (상세 로그 출력)')
    parser.add_argument('--dry-run', action='store_true', help='테스트 모드 (Firebase 저장 안 함)')
    parser.add_argument('--ai', action='store_true', help='AI 메뉴 파싱 사용 (Claude API, 유료)')
    args = parser.parse_args()

    DEBUG_MODE = args.debug

    global USE_AI_PARSING
    USE_AI_PARSING = args.ai

    print("=" * 60)
    print("🍽️  SafeEat 자동 메뉴 수집 시스템")
    print("=" * 60)
    print(f"📍 지역: {args.location}")
    print(f"🏪 식당 수: {args.limit}")
    if args.debug:
        print("🐛 디버그 모드: ON")
    if args.dry_run:
        print("🧪 테스트 모드: ON (저장 안 함)")
    if args.ai:
        if CLAUDE_AVAILABLE and CLAUDE_API_KEY:
            print("🤖 AI 파싱 모드: ON (Claude API)")
        else:
            print("⚠️  AI 파싱 불가 (anthropic 패키지 또는 API 키 없음)")
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
