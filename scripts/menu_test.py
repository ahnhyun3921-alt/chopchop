#!/usr/bin/env python3
"""
메뉴 알러지 분석 테스트 도구

사용법:
  python menu_test.py "크림파스타" "우유,밀,새우"
  python menu_test.py "김치찌개" "돼지고기,대두"
  python menu_test.py  # 대화형 모드
"""

import requests
import json
import sys

import os
API_KEY = os.environ.get("CLAUDE_API_KEY", "")
MODEL = "claude-3-haiku-20240307"

def analyze_menu(menu_name: str, restrictions: list[str]) -> dict:
    """메뉴 알러지 확률 분석"""

    restrictions_str = ", ".join(restrictions)

    prompt = f"""다음 음식 메뉴가 제한 성분을 포함할 확률을 분석해주세요.

메뉴: {menu_name}
제한 성분: {restrictions_str}

각 제한 성분에 대해 포함 확률(0-100%)과 이유를 분석하세요.

다음 형식의 JSON으로 응답:
{{
  "menu": "{menu_name}",
  "results": [
    {{"ingredient": "성분명", "probability": 95, "reason": "이유", "safe": false}}
  ],
  "overall_safe": false,
  "recommendation": "이 메뉴에 대한 추천 또는 주의사항"
}}

JSON만 출력하세요."""

    response = requests.post(
        "https://api.anthropic.com/v1/messages",
        headers={
            "x-api-key": API_KEY,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json"
        },
        json={
            "model": MODEL,
            "max_tokens": 1024,
            "messages": [{"role": "user", "content": prompt}]
        }
    )

    if response.status_code != 200:
        raise Exception(f"API 오류: {response.status_code}")

    data = response.json()
    text = data["content"][0]["text"]

    # JSON 파싱
    if "```json" in text:
        text = text.split("```json")[1].split("```")[0]
    elif "```" in text:
        text = text.split("```")[1].split("```")[0]

    return json.loads(text.strip())

def print_result(result: dict):
    """결과 출력"""
    print()
    print("=" * 60)
    print(f"🍽️  메뉴: {result.get('menu', '알 수 없음')}")
    print("=" * 60)
    print()

    for r in result.get("results", []):
        prob = r["probability"]

        # 확률에 따른 이모지와 색상
        if prob >= 70:
            emoji = "🔴"
            status = "위험"
        elif prob >= 30:
            emoji = "🟡"
            status = "주의"
        else:
            emoji = "🟢"
            status = "안전"

        print(f"  {emoji} {r['ingredient']}: {prob}% ({status})")
        print(f"     └ {r['reason']}")
        print()

    print("-" * 60)

    if result.get("overall_safe"):
        print("  ✅ 결과: 안전하게 드실 수 있습니다!")
    else:
        print("  ⚠️  결과: 주의가 필요합니다!")

    if result.get("recommendation"):
        print(f"  💡 {result['recommendation']}")

    print("=" * 60)
    print()

def interactive_mode():
    """대화형 모드"""
    print()
    print("🍽️  메뉴 알러지 분석 도구")
    print("=" * 40)
    print()

    # 제한 성분 입력
    print("제한 성분을 입력하세요 (쉼표로 구분)")
    print("예: 우유, 밀, 새우, 땅콩")
    restrictions_input = input("\n제한 성분: ").strip()

    if not restrictions_input:
        print("제한 성분을 입력해주세요.")
        return

    restrictions = [r.strip() for r in restrictions_input.split(",")]

    print(f"\n✅ 제한 성분: {', '.join(restrictions)}")
    print()
    print("-" * 40)
    print("메뉴를 입력하세요 (종료: q)")
    print("-" * 40)

    while True:
        menu = input("\n메뉴 입력: ").strip()

        if menu.lower() == 'q':
            print("\n👋 종료합니다.")
            break

        if not menu:
            continue

        print(f"\n⏳ '{menu}' 분석 중...")

        try:
            result = analyze_menu(menu, restrictions)
            print_result(result)
        except Exception as e:
            print(f"\n❌ 오류: {e}")

def main():
    if len(sys.argv) >= 3:
        # 명령줄 인자로 실행
        menu = sys.argv[1]
        restrictions = [r.strip() for r in sys.argv[2].split(",")]

        print(f"\n⏳ '{menu}' 분석 중...")
        result = analyze_menu(menu, restrictions)
        print_result(result)
    else:
        # 대화형 모드
        interactive_mode()

if __name__ == "__main__":
    main()
