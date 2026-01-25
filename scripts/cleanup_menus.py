#!/usr/bin/env python3
"""
메뉴 데이터 정리 스크립트
- OCR 쓰레기 제거
- 중복 제거 (같은 메뉴명은 최신 것만 유지)
- 특수문자/설명문 제거
"""

import re
import firebase_admin
from firebase_admin import credentials, firestore

def is_garbage(name, price=0):
    """쓰레기 데이터인지 확인"""

    # 너무 짧음
    if len(name.strip()) < 2:
        return True, "너무 짧음"

    # 이상한 가격
    if price < 500:
        return True, f"가격 너무 낮음 ({price}원)"
    if price > 500000:
        return True, f"가격 너무 높음 ({price}원)"

    # 가격이 이상한 패턴 (1,992원, 1,508원 등 OCR 오류)
    if price % 1000 not in [0, 500] and price < 5000:
        if price % 100 not in [0]:
            return True, f"가격 패턴 이상 ({price}원)"

    # 특수문자로 시작
    if re.match(r'^[☆★●○◎◇◆□■△▲▽▼→←↑↓\(\)\[\]\{\}<>]', name):
        return True, "특수문자 시작"

    # 설명문 패턴
    bad_patterns = [
        r'변경시', r'추가시', r'주문시', r'선택시',
        r'가능\)', r'이상\s*주', r'부터',
        r'g\s*g', r'g\)', r'gg',  # OCR 오류
        r'HP$', r'wae', r'SINCE', r'STNCE',
        r'^[a-zA-Z\s]+$',  # 영문만
        r'^\d+년$',  # "2년" 같은 것
        r'상품권', r'쿠폰', r'할인권',
        r'서비스$', r'무료$',
        r'^\s*[\-\.\,\:]+',  # 특수문자로 시작
    ]

    for pattern in bad_patterns:
        if re.search(pattern, name, re.IGNORECASE):
            return True, f"패턴: {pattern}"

    # 한글 비율 너무 낮음
    korean = sum(1 for c in name if '\uac00' <= c <= '\ud7a3')
    if len(name) > 3 and korean / len(name) < 0.3:
        return True, "한글 부족"

    return False, ""

def clean_menu_name(name):
    """메뉴명 정리"""
    # 앞 번호 제거 (1. 김치찌개 → 김치찌개)
    name = re.sub(r'^\s*\d+[\.\)\-\s]+', '', name)
    name = re.sub(r'^\s*[①②③④⑤⑥⑦⑧⑨⑩]\s*', '', name)
    name = re.sub(r'^\s*[ㄱㄴㄷㄹㅁㅂㅅㅇㅈㅊㅋㅌㅍㅎ][\.\)\-\s]+', '', name)

    # OCR 쓰레기 제거
    name = re.sub(r'\s*g\s*g\s*', '', name)
    name = re.sub(r'\s*g\s*\)', '', name)
    name = re.sub(r'\s*HP\s*$', '', name)
    name = re.sub(r'\s*•\s*', '', name)
    name = re.sub(r'[☆★●○◎◇◆□■]', '', name)
    name = re.sub(r'\s+', ' ', name)
    return name.strip()

def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true', help='확인만 (삭제 안 함)')
    parser.add_argument('--delete', action='store_true', help='쓰레기 삭제')
    parser.add_argument('--fix-names', action='store_true', help='메뉴명 정리')
    parser.add_argument('--remove-duplicates', action='store_true', help='중복 제거')
    args = parser.parse_args()

    # Firebase 연결
    try:
        cred = credentials.Certificate('firebase-admin-key.json')
        firebase_admin.initialize_app(cred)
    except:
        pass

    db = firestore.client()

    print("=" * 60)
    print("🧹 메뉴 데이터 정리")
    print("=" * 60)

    garbage_list = []
    all_menus = []

    # 모든 메뉴 수집
    for rest in db.collection('restaurants').stream():
        rest_data = rest.to_dict()
        rest_name = rest_data.get('name', '')

        for menu in rest.reference.collection('menus').stream():
            menu_data = menu.to_dict()
            menu_name = menu_data.get('name', '')
            price = menu_data.get('price', 0)

            is_bad, reason = is_garbage(menu_name, price)

            all_menus.append({
                'rest_ref': rest.reference,
                'menu_ref': menu.reference,
                'rest_name': rest_name,
                'menu_name': menu_name,
                'price': price,
                'is_garbage': is_bad,
                'reason': reason
            })

            if is_bad:
                garbage_list.append({
                    'rest_name': rest_name,
                    'menu_name': menu_name,
                    'price': price,
                    'reason': reason,
                    'menu_ref': menu.reference
                })

    print(f"\n📊 전체 메뉴: {len(all_menus)}개")
    print(f"🗑️  쓰레기: {len(garbage_list)}개")

    # 쓰레기 목록 표시
    if args.check or args.delete:
        print(f"\n=== 쓰레기 데이터 (처음 30개) ===")
        for i, g in enumerate(garbage_list[:30]):
            print(f"[{i+1}] {g['menu_name']} ({g['price']:,}원)")
            print(f"    식당: {g['rest_name']}")
            print(f"    이유: {g['reason']}")
            print()

    # 삭제
    if args.delete and garbage_list:
        confirm = input(f"\n{len(garbage_list)}개 쓰레기 삭제? (y/n): ")
        if confirm.lower() == 'y':
            deleted = 0
            for g in garbage_list:
                g['menu_ref'].delete()
                deleted += 1
                if deleted % 50 == 0:
                    print(f"  삭제 중... {deleted}/{len(garbage_list)}")
            print(f"\n✅ {deleted}개 삭제 완료!")

    # 중복 제거
    if args.remove_duplicates:
        print(f"\n=== 중복 확인 ===")

        # 식당별로 메뉴 그룹화
        rest_menus = {}
        for m in all_menus:
            if m['is_garbage']:
                continue
            key = m['rest_ref'].id
            if key not in rest_menus:
                rest_menus[key] = []
            rest_menus[key].append(m)

        duplicates = []
        for rest_id, menus in rest_menus.items():
            # 메뉴명별로 그룹화
            name_groups = {}
            for m in menus:
                clean_name = clean_menu_name(m['menu_name']).lower()
                if clean_name not in name_groups:
                    name_groups[clean_name] = []
                name_groups[clean_name].append(m)

            # 중복 찾기
            for name, group in name_groups.items():
                if len(group) > 1:
                    # 가격이 가장 높은 것 유지 (최신 가격일 가능성)
                    group.sort(key=lambda x: x['price'], reverse=True)
                    for dup in group[1:]:  # 첫 번째 제외하고 삭제 대상
                        duplicates.append(dup)

        print(f"중복 메뉴: {len(duplicates)}개")

        if duplicates:
            for d in duplicates[:20]:
                print(f"  - {d['menu_name']} ({d['price']:,}원) @ {d['rest_name']}")

            confirm = input(f"\n{len(duplicates)}개 중복 삭제? (y/n): ")
            if confirm.lower() == 'y':
                for d in duplicates:
                    d['menu_ref'].delete()
                print(f"✅ {len(duplicates)}개 중복 삭제!")

    # 메뉴명 정리
    if args.fix_names:
        print(f"\n=== 메뉴명 정리 ===")
        fixed = 0
        for m in all_menus:
            if m['is_garbage']:
                continue
            clean = clean_menu_name(m['menu_name'])
            if clean != m['menu_name']:
                print(f"  {m['menu_name']} → {clean}")
                m['menu_ref'].update({'name': clean})
                fixed += 1
                if fixed >= 100:
                    print("  ... (100개까지만 표시)")
                    break
        print(f"✅ {fixed}개 수정!")

    print("\n완료!")

if __name__ == "__main__":
    main()
