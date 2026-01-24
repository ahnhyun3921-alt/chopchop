#!/usr/bin/env python3
"""
Firestore 데이터 조회 스크립트 (표 형식)

사용법:
  python view_data.py              # 전체 요약
  python view_data.py --all        # 모든 메뉴 표시
  python view_data.py --restaurant "식당명"  # 특정 식당 검색
  python view_data.py --export     # CSV 내보내기
"""

import os
import argparse
import firebase_admin
from firebase_admin import credentials, firestore

# Firebase 초기화
FIREBASE_CRED_PATH = "firebase-admin-key.json"

def init_firebase():
    if not os.path.exists(FIREBASE_CRED_PATH):
        print(f"❌ Firebase 인증 파일이 없습니다: {FIREBASE_CRED_PATH}")
        return None

    if not firebase_admin._apps:
        cred = credentials.Certificate(FIREBASE_CRED_PATH)
        firebase_admin.initialize_app(cred)

    return firestore.client()

def print_table(headers, rows, col_widths=None):
    """표 형식으로 출력"""
    if not rows:
        print("  (데이터 없음)")
        return

    # 컬럼 너비 계산
    if not col_widths:
        col_widths = []
        for i, header in enumerate(headers):
            max_width = len(str(header))
            for row in rows:
                if i < len(row):
                    max_width = max(max_width, len(str(row[i])))
            col_widths.append(min(max_width, 30))  # 최대 30자

    # 구분선
    separator = "+" + "+".join("-" * (w + 2) for w in col_widths) + "+"

    # 헤더
    print(separator)
    header_str = "|"
    for i, header in enumerate(headers):
        header_str += f" {str(header)[:col_widths[i]].ljust(col_widths[i])} |"
    print(header_str)
    print(separator)

    # 데이터
    for row in rows:
        row_str = "|"
        for i, col in enumerate(row):
            if i < len(col_widths):
                cell = str(col)[:col_widths[i]].ljust(col_widths[i])
                row_str += f" {cell} |"
        print(row_str)

    print(separator)

def get_all_data(db):
    """모든 데이터 가져오기"""
    restaurants_data = []
    menus_data = []

    restaurants_ref = db.collection('restaurants')
    for restaurant in restaurants_ref.stream():
        r_id = restaurant.id
        r_data = restaurant.to_dict() or {}

        restaurants_data.append({
            'id': r_id,
            'name': r_data.get('name', '-'),
            'category': r_data.get('category', '-'),
            'address': r_data.get('address', '-'),
        })

        # 메뉴 가져오기
        menus_ref = restaurant.reference.collection('menus')
        for menu in menus_ref.stream():
            m_data = menu.to_dict()
            menus_data.append({
                'restaurant_id': r_id,
                'restaurant_name': r_data.get('name', r_id[:8] + '...'),
                'name': m_data.get('name', '-'),
                'price': m_data.get('price', 0),
                'priceText': m_data.get('priceText', f"{m_data.get('price', 0):,}원"),
                'ingredients': ', '.join(m_data.get('ingredients', [])) or '-',
            })

    return restaurants_data, menus_data

def view_summary(db):
    """요약 보기"""
    restaurants_data, menus_data = get_all_data(db)

    print("\n" + "=" * 70)
    print("📊 Firestore 데이터 요약")
    print("=" * 70)

    print(f"\n총 식당 수: {len(restaurants_data)}개")
    print(f"총 메뉴 수: {len(menus_data)}개")

    # 식당별 메뉴 수
    print("\n📍 식당별 메뉴 수:")
    print("-" * 50)

    restaurant_menu_count = {}
    for menu in menus_data:
        r_name = menu['restaurant_name']
        restaurant_menu_count[r_name] = restaurant_menu_count.get(r_name, 0) + 1

    headers = ["식당명", "메뉴 수"]
    rows = [[name, f"{count}개"] for name, count in sorted(restaurant_menu_count.items(), key=lambda x: -x[1])]
    print_table(headers, rows, [30, 10])

def view_all_menus(db):
    """모든 메뉴 표 형식으로 보기"""
    _, menus_data = get_all_data(db)

    print("\n" + "=" * 90)
    print("📋 전체 메뉴 목록")
    print("=" * 90)

    # 가격순 정렬
    menus_data.sort(key=lambda x: x['price'])

    headers = ["식당", "메뉴명", "가격", "재료"]
    rows = []
    for menu in menus_data:
        rows.append([
            menu['restaurant_name'][:15],
            menu['name'][:20],
            menu['priceText'],
            menu['ingredients'][:25]
        ])

    print_table(headers, rows, [15, 20, 12, 25])
    print(f"\n총 {len(menus_data)}개 메뉴")

def search_restaurant(db, keyword):
    """식당 검색"""
    restaurants_data, menus_data = get_all_data(db)

    # 키워드로 필터링
    matched_menus = [m for m in menus_data if keyword.lower() in m['restaurant_name'].lower()]

    if not matched_menus:
        print(f"\n❌ '{keyword}' 식당을 찾을 수 없습니다.")
        return

    print(f"\n🔍 '{keyword}' 검색 결과")
    print("=" * 80)

    headers = ["메뉴명", "가격", "재료"]
    rows = []
    for menu in sorted(matched_menus, key=lambda x: x['price']):
        rows.append([
            menu['name'],
            menu['priceText'],
            menu['ingredients'][:30]
        ])

    print_table(headers, rows, [25, 12, 35])
    print(f"\n총 {len(matched_menus)}개 메뉴")

def export_csv(db, filename="menus_export.csv"):
    """CSV로 내보내기"""
    _, menus_data = get_all_data(db)

    import csv

    with open(filename, 'w', newline='', encoding='utf-8-sig') as f:
        writer = csv.writer(f)
        writer.writerow(['식당ID', '식당명', '메뉴명', '가격(숫자)', '가격(텍스트)', '재료'])

        for menu in menus_data:
            writer.writerow([
                menu['restaurant_id'],
                menu['restaurant_name'],
                menu['name'],
                menu['price'],
                menu['priceText'],
                menu['ingredients']
            ])

    print(f"✅ {filename}로 내보내기 완료! ({len(menus_data)}개 메뉴)")

def main():
    parser = argparse.ArgumentParser(description='Firestore 데이터 조회 (표 형식)')
    parser.add_argument('--all', action='store_true', help='모든 메뉴 표시')
    parser.add_argument('--restaurant', '-r', type=str, help='특정 식당 검색')
    parser.add_argument('--export', '-e', action='store_true', help='CSV로 내보내기')
    args = parser.parse_args()

    db = init_firebase()
    if not db:
        return

    if args.export:
        export_csv(db)
    elif args.restaurant:
        search_restaurant(db, args.restaurant)
    elif args.all:
        view_all_menus(db)
    else:
        view_summary(db)

if __name__ == "__main__":
    main()
