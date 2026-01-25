#!/usr/bin/env python3
"""
로그 파일에서 메뉴 데이터 복구 스크립트
"""

import re
import uuid
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

def is_valid_menu(name, price):
    """유효한 메뉴인지 확인"""
    # 너무 짧음
    if len(name) < 2:
        return False

    # 가격 이상
    if price < 1000 or price > 500000:
        return False

    # 한글 없음
    korean_chars = sum(1 for c in name if '\uac00' <= c <= '\ud7a3')
    if korean_chars < 1:
        return False

    # OCR 쓰레기 패턴
    garbage_patterns = [
        r'^[a-zA-Z\s]+$',  # 영문만
        r'SINCE|STNCE',  # 흔한 OCR 오류
        r'^\d+년$',  # "2년" 같은 것
        r'주원가능|이상\s*주|가능\)',  # 설명문
        r'^[\s\-\.\•\(\)]+$',  # 특수문자만
    ]

    for pattern in garbage_patterns:
        if re.search(pattern, name, re.IGNORECASE):
            return False

    return True

def clean_menu_name(name):
    """메뉴명 정리"""
    # g g, g), HP 등 OCR 쓰레기 제거
    name = re.sub(r'\s*g\s*g\s*', '', name)
    name = re.sub(r'\s*g\s*\)', '', name)
    name = re.sub(r'\s*HP\s*', '', name)
    name = re.sub(r'\s*•\s*', '', name)
    name = re.sub(r'\s+', ' ', name)
    return name.strip()

def parse_log_file(log_path):
    """로그 파일 파싱"""
    restaurants = []
    current_restaurant = None

    with open(log_path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()

            # 식당 이름 (🍴 송도갈비 천지연 인덕원점 (갈비))
            if line.startswith('🍴'):
                if current_restaurant and current_restaurant.get('menus'):
                    restaurants.append(current_restaurant)

                match = re.match(r'🍴\s*(.+?)\s*\((.+?)\)', line)
                if match:
                    current_restaurant = {
                        'name': match.group(1).strip(),
                        'category': match.group(2).strip(),
                        'address': '',
                        'menus': []
                    }
                else:
                    current_restaurant = {
                        'name': line.replace('🍴', '').strip(),
                        'category': '',
                        'address': '',
                        'menus': []
                    }

            # 주소 (📍 경기 안양시...)
            elif line.startswith('📍') and current_restaurant:
                addr = line.replace('📍', '').strip()
                # "지역: 안양 평촌동 맛집" 같은 건 제외
                if '지역:' not in addr and '맛집' not in addr:
                    current_restaurant['address'] = addr

            # 메뉴 (- 김치찌개: 8,000원)
            elif line.startswith('-') and current_restaurant:
                match = re.match(r'-\s*(.+?):\s*([\d,]+)원', line)
                if match:
                    menu_name = clean_menu_name(match.group(1))
                    price_str = match.group(2).replace(',', '')
                    try:
                        price = int(price_str)
                        if is_valid_menu(menu_name, price):
                            current_restaurant['menus'].append({
                                'name': menu_name,
                                'price': price
                            })
                    except:
                        pass

    # 마지막 식당 추가
    if current_restaurant and current_restaurant.get('menus'):
        restaurants.append(current_restaurant)

    return restaurants

def get_existing_restaurants(db):
    """이미 저장된 식당 이름 목록 가져오기"""
    existing = set()
    for doc in db.collection('restaurants').stream():
        name = doc.to_dict().get('name', '')
        if name:
            existing.add(name.strip().lower())
    return existing

def save_to_firebase(restaurants, db):
    """Firebase에 저장 (속도 제한 + 중복 체크 포함)"""
    import time
    total_menus = 0
    batch_count = 0
    skipped = 0

    # 기존 식당 목록 가져오기
    print("📋 기존 식당 확인 중...")
    existing = get_existing_restaurants(db)
    print(f"   이미 저장된 식당: {len(existing)}개")

    for i, rest in enumerate(restaurants):
        if not rest['menus']:
            continue

        # 중복 체크
        if rest['name'].strip().lower() in existing:
            skipped += 1
            continue

        # 식당 ID 생성
        rest_id = str(uuid.uuid4())

        # 식당 저장
        rest_ref = db.collection('restaurants').document(rest_id)
        rest_ref.set({
            'id': rest_id,
            'name': rest['name'],
            'category': rest['category'],
            'address': rest['address'],
            'createdAt': datetime.now()
        })

        # 메뉴 저장
        for menu in rest['menus']:
            menu_id = str(uuid.uuid4())
            menu_ref = rest_ref.collection('menus').document(menu_id)
            menu_ref.set({
                'id': menu_id,
                'restaurantId': rest_id,
                'name': menu['name'],
                'price': menu['price'],
                'priceText': f"{menu['price']:,}원",
                'createdAt': datetime.now()
            })
            total_menus += 1
            batch_count += 1

            # 50개마다 1초 대기 (속도 제한)
            if batch_count >= 50:
                time.sleep(1)
                batch_count = 0

        print(f"[{i+1}/{len(restaurants)}] ✅ {rest['name']}: {len(rest['menus'])}개 메뉴")

        # 식당마다 0.5초 대기
        time.sleep(0.5)

    if skipped > 0:
        print(f"\n⏭️  {skipped}개 중복 식당 건너뜀")

    return total_menus

def main():
    import sys

    log_path = sys.argv[1] if len(sys.argv) > 1 else 'anyang_log.txt'

    print("=" * 60)
    print("📋 로그에서 데이터 복구 중...")
    print("=" * 60)

    # 로그 파싱
    restaurants = parse_log_file(log_path)

    total_menus = sum(len(r['menus']) for r in restaurants)
    print(f"\n📊 파싱 결과:")
    print(f"   식당: {len(restaurants)}개")
    print(f"   메뉴: {total_menus}개")

    if not restaurants:
        print("❌ 복구할 데이터 없음")
        return

    # 미리보기
    print(f"\n📝 미리보기 (처음 5개 식당):")
    for rest in restaurants[:5]:
        print(f"\n🍴 {rest['name']} ({rest['category']})")
        print(f"   📍 {rest['address']}")
        for menu in rest['menus'][:3]:
            print(f"   - {menu['name']}: {menu['price']:,}원")
        if len(rest['menus']) > 3:
            print(f"   ... 외 {len(rest['menus'])-3}개")

    # Firebase 저장 확인
    confirm = input(f"\n\nFirebase에 저장할까요? (y/n): ")
    if confirm.lower() != 'y':
        print("취소됨")
        return

    # Firebase 연결
    try:
        cred = credentials.Certificate('firebase-admin-key.json')
        firebase_admin.initialize_app(cred)
    except:
        pass

    db = firestore.client()

    print("\n💾 Firebase에 저장 중...")
    saved = save_to_firebase(restaurants, db)

    print(f"\n✅ 완료! {saved}개 메뉴 저장됨")

if __name__ == "__main__":
    main()
