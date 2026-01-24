#!/usr/bin/env python3
"""
안양시 전체 식당 자동 수집 스크립트

사용법:
  python collect_anyang.py           # 전체 수집
  python collect_anyang.py --dry-run # 테스트 (저장 안 함)

백그라운드 실행:
  nohup python collect_anyang.py > anyang_log.txt 2>&1 &

로그 확인:
  tail -f anyang_log.txt
"""

import subprocess
import sys
import time
from datetime import datetime

# 안양시 지역 목록 (동안구 + 만안구)
ANYANG_AREAS = [
    # 동안구
    "평촌",
    "범계",
    "호계동",
    "비산동",
    "관양동",
    "평안동",
    "귀인동",
    "부림동",
    "달안동",
    "신촌동",
    "안양 인덕원",
    # 만안구
    "안양역",
    "안양1동",
    "석수동",
    "박달동",
    "안양만안",
    "안양중앙",
]

# 각 지역당 수집할 식당 수
RESTAURANTS_PER_AREA = 15

def run_collector(location, limit, dry_run=False):
    """menu_collector.py 실행"""
    cmd = [
        sys.executable,
        "menu_collector.py",
        "--location", location,
        "--limit", str(limit),
    ]

    if dry_run:
        cmd.append("--dry-run")

    print(f"\n{'='*60}")
    print(f"🏃 수집 시작: {location} (최대 {limit}개 식당)")
    print(f"{'='*60}")

    try:
        result = subprocess.run(cmd, capture_output=False, text=True)
        return result.returncode == 0
    except Exception as e:
        print(f"❌ 오류: {e}")
        return False

def main():
    import argparse
    parser = argparse.ArgumentParser(description='안양시 전체 식당 수집')
    parser.add_argument('--dry-run', action='store_true', help='테스트 모드')
    parser.add_argument('--areas', type=int, default=len(ANYANG_AREAS),
                        help=f'수집할 지역 수 (기본: {len(ANYANG_AREAS)})')
    args = parser.parse_args()

    start_time = datetime.now()

    print("=" * 60)
    print("🏙️  안양시 전체 식당 자동 수집")
    print("=" * 60)
    print(f"📅 시작 시간: {start_time.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"📍 수집 지역: {len(ANYANG_AREAS[:args.areas])}개")
    print(f"🏪 지역당 식당: {RESTAURANTS_PER_AREA}개")
    print(f"📊 예상 총 식당: ~{len(ANYANG_AREAS[:args.areas]) * RESTAURANTS_PER_AREA}개")
    if args.dry_run:
        print("🧪 테스트 모드 (저장 안 함)")
    print("=" * 60)

    success_count = 0
    fail_count = 0

    for i, area in enumerate(ANYANG_AREAS[:args.areas], 1):
        print(f"\n\n{'#'*60}")
        print(f"# 진행: {i}/{len(ANYANG_AREAS[:args.areas])} - {area}")
        print(f"{'#'*60}")

        success = run_collector(area, RESTAURANTS_PER_AREA, args.dry_run)

        if success:
            success_count += 1
        else:
            fail_count += 1

        # 지역 간 대기 (API 제한 방지)
        if i < len(ANYANG_AREAS[:args.areas]):
            print(f"\n⏳ 다음 지역까지 5초 대기...")
            time.sleep(5)

    # 최종 결과
    end_time = datetime.now()
    duration = end_time - start_time

    print("\n\n" + "=" * 60)
    print("🎉 안양시 전체 수집 완료!")
    print("=" * 60)
    print(f"📅 종료 시간: {end_time.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"⏱️  소요 시간: {duration}")
    print(f"✅ 성공: {success_count}개 지역")
    print(f"❌ 실패: {fail_count}개 지역")
    print("=" * 60)

    # 데이터 확인 안내
    print("\n💡 수집된 데이터 확인:")
    print("   python view_data.py --all")
    print("   python view_data.py --export")

if __name__ == "__main__":
    main()
