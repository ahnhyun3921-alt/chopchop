#!/usr/bin/env python3
"""
메뉴 데이터 정리 및 AI 수정 스크립트

사용법:
  python fix_menus.py --check        # 이상한 메뉴 확인만
  python fix_menus.py --fix          # AI로 수정
  python fix_menus.py --delete-bad   # 이상한 것 삭제
"""

import os
import re
import json
import argparse
import firebase_admin
from firebase_admin import credentials, firestore

# Claude API
try:
    import anthropic
    CLAUDE_AVAILABLE = True
except ImportError:
    CLAUDE_AVAILABLE = False

CLAUDE_API_KEY = os.environ.get("ANTHROPIC_API_KEY", "")

# ==================== 이상한 메뉴 판별 ====================

def is_suspicious(name, price):
    """이상한 메뉴인지 확인"""
    reasons = []

    # 너무 짧음
    if len(name) < 2:
        reasons.append("너무 짧음")

    # 가격 이상
    if price < 1000:
        reasons.append(f"가격 너무 낮음 ({price}원)")
    if price > 300000:
        reasons.append(f"가격 너무 높음 ({price}원)")

    # OCR 쓰레기 패턴
    garbage_patterns = [
        r'[a-zA-Z]{2,}',  # 영문 2글자 이상 연속
        r'gg|wae|eee|aaa',  # 흔한 OCR 오류
        r'[\:\.\*]{2,}',  # 특수문자 연속
        r'^\s*[\-\.\,]+',  # 시작이 특수문자
        r'\d{4,}',  # 숫자 4개 이상 연속 (전화번호 등)
    ]

    for pattern in garbage_patterns:
        if re.search(pattern, name, re.IGNORECASE):
            reasons.append(f"OCR 오류 패턴")
            break

    # 한글 비율 낮음
    korean_chars = sum(1 for c in name if '\uac00' <= c <= '\ud7a3')
    if len(name) > 0 and korean_chars / len(name) < 0.5:
        reasons.append(f"한글 비율 낮음 ({korean_chars}/{len(name)})")

    # 이상한 단어 포함
    bad_words = ['상품권', '쿠폰', '할인', '서비스', '무료', 'free']
    for word in bad_words:
        if word in name.lower():
            reasons.append(f"'{word}' 포함")
            break

    return reasons

# ==================== AI 수정 ====================

def fix_with_ai(menus_to_fix):
    """AI로 메뉴명 수정"""
    if not CLAUDE_AVAILABLE or not CLAUDE_API_KEY:
        print("❌ Claude API 사용 불가")
        print("   pip install anthropic")
        print("   export ANTHROPIC_API_KEY='...'")
        return None

    client = anthropic.Anthropic(api_key=CLAUDE_API_KEY)

    # 메뉴 목록 준비
    menu_list = "\n".join([
        f"- {m['name']} ({m['price']}원) [식당: {m.get('restaurant_name', '?')}]"
        for m in menus_to_fix[:50]  # 최대 50개씩
    ])

    prompt = f"""다음은 OCR로 인식된 메뉴 목록입니다. OCR 오류로 잘못 인식된 것들이 있습니다.

{menu_list}

각 메뉴에 대해:
1. 올바른 메뉴명으로 수정해주세요 (OCR 오타 교정)
2. 음식이 아닌 것은 "삭제"로 표시해주세요
3. 가격이 이상하면 적절한 가격으로 추정해주세요

JSON 형식으로 응답해주세요:
{{"fixes": [
  {{"original": "원래메뉴명", "fixed": "수정된메뉴명", "price": 가격, "action": "fix/delete"}}
]}}

예시:
- "돼디고기" → "돼지고기"
- "김치찌게" → "김치찌개"
- "숙성 목살gg" → "숙성 목살"
- "상품권 wae" → 삭제"""

    try:
        response = client.messages.create(
            model="claude-3-haiku-20240307",
            max_tokens=2048,
            messages=[{"role": "user", "content": prompt}]
        )

        response_text = response.content[0].text
        json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
        if json_match:
            return json.loads(json_match.group())
    except Exception as e:
        print(f"❌ AI 오류: {e}")

    return None

# ==================== 메인 ====================

def main():
    parser = argparse.ArgumentParser(description='메뉴 데이터 정리')
    parser.add_argument('--check', action='store_true', help='이상한 메뉴 확인')
    parser.add_argument('--fix', action='store_true', help='AI로 수정')
    parser.add_argument('--delete-bad', action='store_true', help='이상한 것 삭제')
    parser.add_argument('--limit', type=int, default=100, help='처리할 최대 개수')
    args = parser.parse_args()

    if not any([args.check, args.fix, args.delete_bad]):
        args.check = True  # 기본: 확인만

    # Firebase 연결
    try:
        cred = credentials.Certificate('firebase-admin-key.json')
        firebase_admin.initialize_app(cred)
    except:
        pass

    db = firestore.client()

    print("=" * 60)
    print("🔍 메뉴 데이터 검사 중...")
    print("=" * 60)

    suspicious_menus = []
    total = 0

    for doc in db.collection('menus').stream():
        total += 1
        data = doc.to_dict()
        name = data.get('name', '')
        price = data.get('price', 0)

        reasons = is_suspicious(name, price)
        if reasons:
            suspicious_menus.append({
                'doc_id': doc.id,
                'name': name,
                'price': price,
                'restaurant_name': data.get('restaurant_name', ''),
                'reasons': reasons
            })

    print(f"\n총 {total}개 메뉴 중 {len(suspicious_menus)}개 의심됨\n")

    if not suspicious_menus:
        print("✅ 이상한 메뉴 없음!")
        return

    # 확인 모드
    if args.check:
        print("=" * 60)
        print("⚠️  의심되는 메뉴 목록")
        print("=" * 60)
        for i, m in enumerate(suspicious_menus[:args.limit], 1):
            print(f"\n[{i}] {m['name']} - {m['price']:,}원")
            print(f"    식당: {m['restaurant_name']}")
            print(f"    문제: {', '.join(m['reasons'])}")

    # AI 수정 모드
    if args.fix:
        print("\n" + "=" * 60)
        print("🤖 AI로 수정 중...")
        print("=" * 60)

        to_fix = suspicious_menus[:args.limit]
        result = fix_with_ai(to_fix)

        if result and 'fixes' in result:
            fixed_count = 0
            deleted_count = 0

            for fix in result['fixes']:
                original = fix.get('original', '')
                action = fix.get('action', 'fix')

                # 원본 찾기
                for m in to_fix:
                    if m['name'] == original:
                        doc_ref = db.collection('menus').document(m['doc_id'])

                        if action == 'delete':
                            print(f"🗑️  삭제: {original}")
                            doc_ref.delete()
                            deleted_count += 1
                        else:
                            fixed_name = fix.get('fixed', original)
                            fixed_price = fix.get('price', m['price'])
                            print(f"✏️  수정: {original} → {fixed_name} ({fixed_price:,}원)")
                            doc_ref.update({
                                'name': fixed_name,
                                'price': fixed_price
                            })
                            fixed_count += 1
                        break

            print(f"\n✅ 수정: {fixed_count}개, 삭제: {deleted_count}개")

    # 삭제 모드
    if args.delete_bad:
        print("\n" + "=" * 60)
        print("🗑️  이상한 메뉴 삭제 중...")
        print("=" * 60)

        confirm = input(f"\n{len(suspicious_menus[:args.limit])}개 삭제하시겠습니까? (y/n): ")
        if confirm.lower() == 'y':
            deleted = 0
            for m in suspicious_menus[:args.limit]:
                doc_ref = db.collection('menus').document(m['doc_id'])
                doc_ref.delete()
                print(f"  삭제: {m['name']}")
                deleted += 1
            print(f"\n✅ {deleted}개 삭제됨")
        else:
            print("취소됨")

if __name__ == "__main__":
    main()
