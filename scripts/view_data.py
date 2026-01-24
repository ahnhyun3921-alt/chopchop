#!/usr/bin/env python3
"""
Firestore 데이터 조회 스크립트
"""

import firebase_admin
from firebase_admin import credentials, firestore

# Firebase 초기화
FIREBASE_CRED_PATH = "firebase-admin-key.json"

if not firebase_admin._apps:
    cred = credentials.Certificate(FIREBASE_CRED_PATH)
    firebase_admin.initialize_app(cred)

db = firestore.client()

print("=" * 60)
print("🔍 Firestore 데이터 조회")
print("=" * 60)

# restaurants 컬렉션 조회
restaurants_ref = db.collection('restaurants')
restaurants = restaurants_ref.stream()

total_restaurants = 0
total_menus = 0

for restaurant in restaurants:
    total_restaurants += 1
    restaurant_data = restaurant.to_dict()

    print(f"\n📍 식당 ID: {restaurant.id}")

    # 식당 정보 출력 (만약 있다면)
    if restaurant_data:
        print(f"   데이터: {restaurant_data}")

    # 메뉴 서브컬렉션 조회
    menus_ref = restaurant.reference.collection('menus')
    menus = list(menus_ref.stream())

    if menus:
        print(f"   📋 메뉴 개수: {len(menus)}개")
        total_menus += len(menus)

        # 처음 3개 메뉴만 출력
        for i, menu in enumerate(menus[:3], 1):
            menu_data = menu.to_dict()
            print(f"      {i}. {menu_data.get('name', '이름 없음')} - {menu_data.get('price', 0):,}원")
            if menu_data.get('ingredients'):
                print(f"         재료: {', '.join(menu_data.get('ingredients', []))}")

        if len(menus) > 3:
            print(f"      ... 외 {len(menus) - 3}개 메뉴")
    else:
        print(f"   ⚠️  메뉴 없음")

print("\n" + "=" * 60)
print(f"📊 요약")
print("=" * 60)
print(f"총 식당 수: {total_restaurants}개")
print(f"총 메뉴 수: {total_menus}개")
print("=" * 60)
