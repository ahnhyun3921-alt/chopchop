#!/usr/bin/env python3
"""
안양시 전체 식당 완전 수집 스크립트

모든 동 + 모든 카테고리 + 여러 키워드로 빠짐없이 수집

사용법:
  python collect_anyang.py           # 전체 수집
  python collect_anyang.py --dry-run # 테스트 (저장 안 함)

백그라운드 실행 (자는 동안):
  nohup python collect_anyang.py > anyang_log.txt 2>&1 &

로그 확인:
  tail -f anyang_log.txt
"""

import subprocess
import sys
import time
from datetime import datetime

# ==================== 안양시 모든 동 ====================

# 동안구 (15개 동)
DONGAN_DONGS = [
    "평촌동", "호계동", "범계동", "비산동", "관양동",
    "부림동", "평안동", "귀인동", "신촌동", "달안동",
    "갈산동", "지산동", "안양동안구"
]

# 만안구 (16개 동)
MANAN_DONGS = [
    "안양1동", "안양2동", "안양3동", "안양4동", "안양5동",
    "안양6동", "안양7동", "안양8동", "안양9동",
    "석수1동", "석수2동", "석수3동",
    "박달1동", "박달2동",
    "안양만안구"
]

# 주요 랜드마크/역세권 (추가 검색)
LANDMARKS = [
    "평촌역", "범계역", "인덕원역", "안양역", "관악역",
    "평촌 학원가", "범계 먹자골목", "안양 중앙시장",
    "평촌 중앙공원", "안양예술공원"
]

# ==================== 음식 카테고리 ====================

FOOD_CATEGORIES = [
    "한식", "중식", "일식", "양식",
    "분식", "치킨", "피자", "햄버거",
    "고기", "삼겹살", "곱창", "족발",
    "찌개", "국밥", "냉면", "칼국수",
    "해물", "횟집", "초밥",
    "카페", "베이커리", "디저트",
    "술집", "포장마차", "이자카야",
    "베트남", "태국", "인도"
]

# 검색 키워드 변형
SEARCH_KEYWORDS = ["맛집", "식당", "음식점"]

# 각 검색당 가져올 식당 수 (최대)
RESTAURANTS_PER_SEARCH = 45  # 카카오 API 최대치

def run_collector(location, limit, dry_run=False, use_ai=False):
    """menu_collector.py 실행"""
    cmd = [
        sys.executable,
        "menu_collector.py",
        "--location", location,
        "--limit", str(limit),
    ]

    if dry_run:
        cmd.append("--dry-run")

    if use_ai:
        cmd.append("--ai")

    try:
        result = subprocess.run(cmd, capture_output=False, text=True, timeout=600)
        return result.returncode == 0
    except subprocess.TimeoutExpired:
        print(f"⏰ 타임아웃: {location}")
        return False
    except Exception as e:
        print(f"❌ 오류: {e}")
        return False

def generate_all_searches():
    """모든 검색 조합 생성"""
    searches = []

    # 1. 모든 동 + 기본 키워드
    all_dongs = DONGAN_DONGS + MANAN_DONGS
    for dong in all_dongs:
        for keyword in SEARCH_KEYWORDS:
            searches.append(f"안양 {dong} {keyword}")

    # 2. 모든 동 + 음식 카테고리
    for dong in all_dongs:
        for category in FOOD_CATEGORIES:
            searches.append(f"안양 {dong} {category}")

    # 3. 랜드마크 + 키워드
    for landmark in LANDMARKS:
        for keyword in SEARCH_KEYWORDS:
            searches.append(f"{landmark} {keyword}")

    # 4. 랜드마크 + 카테고리
    for landmark in LANDMARKS:
        for category in FOOD_CATEGORIES:
            searches.append(f"{landmark} {category}")

    # 중복 제거
    return list(dict.fromkeys(searches))

def main():
    import argparse
    parser = argparse.ArgumentParser(description='안양시 전체 식당 완전 수집')
    parser.add_argument('--dry-run', action='store_true', help='테스트 모드')
    parser.add_argument('--quick', action='store_true', help='빠른 모드 (동 + 맛집만)')
    parser.add_argument('--limit', type=int, default=0, help='검색 횟수 제한 (0=무제한)')
    parser.add_argument('--ai', action='store_true', help='AI로 메뉴 파싱 (Claude API 사용)')
    args = parser.parse_args()

    start_time = datetime.now()

    # 검색 목록 생성
    if args.quick:
        # 빠른 모드: 동 + 맛집만
        all_dongs = DONGAN_DONGS + MANAN_DONGS + LANDMARKS
        searches = [f"안양 {dong} 맛집" for dong in all_dongs]
    else:
        # 완전 모드: 모든 조합
        searches = generate_all_searches()

    if args.limit > 0:
        searches = searches[:args.limit]

    print("=" * 70)
    print("🏙️  안양시 전체 식당 완전 수집")
    print("=" * 70)
    print(f"📅 시작 시간: {start_time.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"🔍 총 검색 횟수: {len(searches)}회")
    print(f"📊 예상 소요 시간: 약 {len(searches) * 2}분")
    if args.dry_run:
        print("🧪 테스트 모드 (저장 안 함)")
    if args.quick:
        print("⚡ 빠른 모드")
    if args.ai:
        print("🤖 AI 모드 (Claude API 사용)")
    print("=" * 70)
    print("\n처음 10개 검색어:")
    for s in searches[:10]:
        print(f"  - {s}")
    print(f"  ... 외 {len(searches)-10}개")
    print("=" * 70)

    # 잠시 대기 (취소 기회)
    print("\n⏳ 5초 후 시작... (Ctrl+C로 취소)")
    time.sleep(5)

    success_count = 0
    fail_count = 0
    skip_count = 0

    for i, search_query in enumerate(searches, 1):
        print(f"\n{'='*60}")
        print(f"[{i}/{len(searches)}] 🔍 검색: {search_query}")
        print(f"{'='*60}")

        success = run_collector(search_query, RESTAURANTS_PER_SEARCH, args.dry_run, args.ai)

        if success:
            success_count += 1
        else:
            fail_count += 1

        # 검색 간 대기 (API 제한 방지)
        if i < len(searches):
            time.sleep(2)

        # 진행률 표시 (10% 단위)
        if i % max(1, len(searches) // 10) == 0:
            elapsed = datetime.now() - start_time
            remaining = elapsed / i * (len(searches) - i)
            print(f"\n📊 진행: {i}/{len(searches)} ({i*100//len(searches)}%)")
            print(f"⏱️  경과: {elapsed}, 남은 예상: {remaining}")

    # 최종 결과
    end_time = datetime.now()
    duration = end_time - start_time

    print("\n\n" + "=" * 70)
    print("🎉 안양시 전체 수집 완료!")
    print("=" * 70)
    print(f"📅 종료 시간: {end_time.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"⏱️  총 소요 시간: {duration}")
    print(f"✅ 성공: {success_count}회")
    print(f"❌ 실패: {fail_count}회")
    print("=" * 70)

    # 데이터 확인 안내
    print("\n💡 수집된 데이터 확인:")
    print("   python view_data.py")
    print("   python view_data.py --all")
    print("   python view_data.py --export")

if __name__ == "__main__":
    main()
