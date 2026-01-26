#!/usr/bin/env python3
"""
휴튼 서비스 리뷰 크롤링 스크립트
네이버 블로그, 구글 플레이스토어, 앱스토어 리뷰 수집

사용 방법:
1. requirements.txt 설치: pip install -r requirements.txt
2. 실행: python review_crawler.py --keyword "휴튼" --all
   또는 개별 실행:
   - python review_crawler.py --keyword "휴튼" --naver
   - python review_crawler.py --keyword "휴튼" --playstore --app-id "com.example.app"
   - python review_crawler.py --keyword "휴튼" --appstore --app-id "123456789"
"""

import os
import re
import json
import time
import argparse
import requests
from datetime import datetime
from typing import List, Dict, Optional

# ==================== 설정 ====================

# 네이버 검색 API 키 (https://developers.naver.com/)
NAVER_CLIENT_ID = os.environ.get("NAVER_CLIENT_ID", "5mtTvlnrdwnNfvsAUziZ")
NAVER_CLIENT_SECRET = os.environ.get("NAVER_CLIENT_SECRET", "zynF6nUH11")

# 결과 저장 디렉토리
OUTPUT_DIR = "review_results"

# ==================== 유틸리티 ====================

def clean_html(text: str) -> str:
    """HTML 태그 및 특수문자 제거"""
    # HTML 태그 제거
    text = re.sub(r'<[^>]+>', '', text)
    # HTML 엔티티 변환
    text = text.replace('&amp;', '&')
    text = text.replace('&lt;', '<')
    text = text.replace('&gt;', '>')
    text = text.replace('&quot;', '"')
    text = text.replace('&#39;', "'")
    text = text.replace('&nbsp;', ' ')
    # 연속 공백 정리
    text = re.sub(r'\s+', ' ', text).strip()
    return text

def save_results(reviews: List[Dict], platform: str, keyword: str):
    """결과를 JSON 파일로 저장"""
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"{OUTPUT_DIR}/{platform}_{keyword}_{timestamp}.json"

    with open(filename, 'w', encoding='utf-8') as f:
        json.dump({
            "platform": platform,
            "keyword": keyword,
            "crawled_at": datetime.now().isoformat(),
            "total_count": len(reviews),
            "reviews": reviews
        }, f, ensure_ascii=False, indent=2)

    print(f"  💾 저장 완료: {filename}")
    return filename

# ==================== 네이버 블로그 크롤링 ====================

class NaverBlogCrawler:
    """네이버 블로그 검색 API를 사용한 리뷰 크롤링"""

    def __init__(self, client_id: str, client_secret: str):
        self.client_id = client_id
        self.client_secret = client_secret
        self.base_url = "https://openapi.naver.com/v1/search/blog.json"

    def search(self, keyword: str, display: int = 100, start: int = 1, sort: str = "sim") -> Dict:
        """
        네이버 블로그 검색

        Args:
            keyword: 검색 키워드
            display: 검색 결과 개수 (최대 100)
            start: 검색 시작 위치 (최대 1000)
            sort: 정렬 방식 - sim(유사도순), date(날짜순)
        """
        headers = {
            "X-Naver-Client-Id": self.client_id,
            "X-Naver-Client-Secret": self.client_secret
        }
        params = {
            "query": keyword,
            "display": min(display, 100),
            "start": start,
            "sort": sort
        }

        try:
            response = requests.get(self.base_url, headers=headers, params=params)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"  ❌ 네이버 블로그 검색 실패: {e}")
            return {"items": [], "total": 0}

    def crawl(self, keyword: str, max_results: int = 300) -> List[Dict]:
        """
        네이버 블로그 리뷰 크롤링

        Args:
            keyword: 검색 키워드 (예: "휴튼 후기")
            max_results: 최대 수집 개수 (최대 1000)
        """
        print(f"\n{'='*60}")
        print(f"📝 네이버 블로그 크롤링")
        print(f"🔍 검색어: {keyword}")
        print(f"{'='*60}")

        all_reviews = []
        search_queries = [
            f"{keyword} 후기",
            f"{keyword} 리뷰",
            f"{keyword} 사용후기",
            f"{keyword} 앱 후기"
        ]

        for query in search_queries:
            print(f"\n  🔎 검색 중: '{query}'")

            # 페이지네이션 (최대 1000개까지만 접근 가능)
            for start in range(1, min(max_results, 1000), 100):
                if len(all_reviews) >= max_results:
                    break

                data = self.search(query, display=100, start=start)
                items = data.get("items", [])

                if not items:
                    break

                for item in items:
                    review = {
                        "platform": "naver_blog",
                        "title": clean_html(item.get("title", "")),
                        "content": clean_html(item.get("description", "")),
                        "author": item.get("bloggername", ""),
                        "url": item.get("link", ""),
                        "date": item.get("postdate", ""),
                        "crawled_at": datetime.now().isoformat()
                    }

                    # 중복 제거 (URL 기준)
                    if not any(r["url"] == review["url"] for r in all_reviews):
                        all_reviews.append(review)

                print(f"    ✅ {len(items)}개 수집 (총 {len(all_reviews)}개)")
                time.sleep(0.5)  # API 제한 방지

        print(f"\n  📊 총 {len(all_reviews)}개 블로그 리뷰 수집 완료")
        return all_reviews

# ==================== 구글 플레이스토어 크롤링 ====================

class PlayStoreCrawler:
    """구글 플레이스토어 리뷰 크롤링 (google-play-scraper 사용)"""

    def __init__(self):
        try:
            from google_play_scraper import Sort, reviews, app
            self.Sort = Sort
            self.reviews_func = reviews
            self.app_func = app
            self.available = True
        except ImportError:
            print("  ⚠️  google-play-scraper 미설치. 설치: pip install google-play-scraper")
            self.available = False

    def get_app_info(self, app_id: str) -> Optional[Dict]:
        """앱 정보 조회"""
        if not self.available:
            return None

        try:
            info = self.app_func(app_id, lang='ko', country='kr')
            return {
                "app_id": app_id,
                "title": info.get("title", ""),
                "developer": info.get("developer", ""),
                "rating": info.get("score", 0),
                "reviews_count": info.get("reviews", 0),
                "installs": info.get("installs", "")
            }
        except Exception as e:
            print(f"  ❌ 앱 정보 조회 실패: {e}")
            return None

    def crawl(self, app_id: str, max_results: int = 500) -> List[Dict]:
        """
        플레이스토어 리뷰 크롤링

        Args:
            app_id: 앱 패키지 ID (예: "com.kakao.talk")
            max_results: 최대 수집 개수
        """
        if not self.available:
            print("  ❌ google-play-scraper가 설치되지 않았습니다.")
            return []

        print(f"\n{'='*60}")
        print(f"🤖 구글 플레이스토어 크롤링")
        print(f"📱 앱 ID: {app_id}")
        print(f"{'='*60}")

        # 앱 정보 조회
        app_info = self.get_app_info(app_id)
        if app_info:
            print(f"  📱 앱 이름: {app_info['title']}")
            print(f"  ⭐ 평점: {app_info['rating']:.1f}")
            print(f"  📊 총 리뷰: {app_info['reviews_count']:,}개")

        all_reviews = []

        # 최신순 리뷰 수집
        print(f"\n  🔄 최신순 리뷰 수집 중...")
        try:
            result, _ = self.reviews_func(
                app_id,
                lang='ko',
                country='kr',
                sort=self.Sort.NEWEST,
                count=min(max_results // 2, 500)
            )

            for item in result:
                review = {
                    "platform": "play_store",
                    "app_id": app_id,
                    "rating": item.get("score", 0),
                    "content": item.get("content", ""),
                    "author": item.get("userName", ""),
                    "date": item.get("at").isoformat() if item.get("at") else "",
                    "thumbs_up": item.get("thumbsUpCount", 0),
                    "reply": item.get("replyContent", ""),
                    "reply_date": item.get("repliedAt").isoformat() if item.get("repliedAt") else "",
                    "crawled_at": datetime.now().isoformat()
                }
                all_reviews.append(review)

            print(f"    ✅ {len(result)}개 수집")
        except Exception as e:
            print(f"  ❌ 최신순 리뷰 수집 실패: {e}")

        # 관련성순 리뷰 수집
        print(f"\n  🔄 관련성순 리뷰 수집 중...")
        try:
            result, _ = self.reviews_func(
                app_id,
                lang='ko',
                country='kr',
                sort=self.Sort.MOST_RELEVANT,
                count=min(max_results // 2, 500)
            )

            for item in result:
                review = {
                    "platform": "play_store",
                    "app_id": app_id,
                    "rating": item.get("score", 0),
                    "content": item.get("content", ""),
                    "author": item.get("userName", ""),
                    "date": item.get("at").isoformat() if item.get("at") else "",
                    "thumbs_up": item.get("thumbsUpCount", 0),
                    "reply": item.get("replyContent", ""),
                    "reply_date": item.get("repliedAt").isoformat() if item.get("repliedAt") else "",
                    "crawled_at": datetime.now().isoformat()
                }

                # 중복 제거 (내용 + 저자 기준)
                key = f"{review['author']}:{review['content'][:50]}"
                if not any(f"{r['author']}:{r['content'][:50]}" == key for r in all_reviews):
                    all_reviews.append(review)

            print(f"    ✅ 추가 {len(result)}개 수집 (중복 제거 후 총 {len(all_reviews)}개)")
        except Exception as e:
            print(f"  ❌ 관련성순 리뷰 수집 실패: {e}")

        print(f"\n  📊 총 {len(all_reviews)}개 플레이스토어 리뷰 수집 완료")
        return all_reviews

# ==================== 앱스토어 크롤링 ====================

class AppStoreCrawler:
    """애플 앱스토어 리뷰 크롤링 (app-store-scraper 사용)"""

    def __init__(self):
        try:
            from app_store_scraper import AppStore
            self.AppStore = AppStore
            self.available = True
        except ImportError:
            print("  ⚠️  app-store-scraper 미설치. 설치: pip install app-store-scraper")
            self.available = False

    def crawl(self, app_name: str, app_id: str, country: str = "kr", max_results: int = 500) -> List[Dict]:
        """
        앱스토어 리뷰 크롤링

        Args:
            app_name: 앱 이름 (영문, URL용)
            app_id: 앱 ID (숫자)
            country: 국가 코드
            max_results: 최대 수집 개수
        """
        if not self.available:
            print("  ❌ app-store-scraper가 설치되지 않았습니다.")
            return []

        print(f"\n{'='*60}")
        print(f"🍎 앱스토어 크롤링")
        print(f"📱 앱: {app_name} (ID: {app_id})")
        print(f"🌏 국가: {country}")
        print(f"{'='*60}")

        all_reviews = []

        try:
            # 앱스토어 객체 생성
            app = self.AppStore(country=country, app_name=app_name, app_id=app_id)

            print(f"\n  🔄 리뷰 수집 중...")
            app.review(how_many=max_results)

            for item in app.reviews:
                review = {
                    "platform": "app_store",
                    "app_id": app_id,
                    "app_name": app_name,
                    "rating": item.get("rating", 0),
                    "title": item.get("title", ""),
                    "content": item.get("review", ""),
                    "author": item.get("userName", ""),
                    "date": item.get("date").isoformat() if item.get("date") else "",
                    "is_edited": item.get("isEdited", False),
                    "crawled_at": datetime.now().isoformat()
                }
                all_reviews.append(review)

            print(f"    ✅ {len(all_reviews)}개 수집 완료")

        except Exception as e:
            print(f"  ❌ 앱스토어 리뷰 수집 실패: {e}")

        print(f"\n  📊 총 {len(all_reviews)}개 앱스토어 리뷰 수집 완료")
        return all_reviews

# ==================== 통합 크롤러 ====================

class ReviewCrawler:
    """리뷰 크롤링 통합 관리자"""

    def __init__(self):
        self.naver_crawler = NaverBlogCrawler(NAVER_CLIENT_ID, NAVER_CLIENT_SECRET)
        self.playstore_crawler = PlayStoreCrawler()
        self.appstore_crawler = AppStoreCrawler()

    def crawl_all(self, keyword: str, playstore_app_id: str = None,
                  appstore_app_name: str = None, appstore_app_id: str = None,
                  max_results: int = 300) -> Dict[str, List[Dict]]:
        """모든 플랫폼에서 리뷰 크롤링"""

        print("\n" + "=" * 60)
        print(f"🚀 {keyword} 리뷰 크롤링 시작")
        print("=" * 60)

        results = {}

        # 1. 네이버 블로그
        print("\n📌 [1/3] 네이버 블로그 크롤링")
        naver_reviews = self.naver_crawler.crawl(keyword, max_results)
        results["naver_blog"] = naver_reviews
        if naver_reviews:
            save_results(naver_reviews, "naver_blog", keyword)

        # 2. 구글 플레이스토어
        if playstore_app_id:
            print("\n📌 [2/3] 구글 플레이스토어 크롤링")
            playstore_reviews = self.playstore_crawler.crawl(playstore_app_id, max_results)
            results["play_store"] = playstore_reviews
            if playstore_reviews:
                save_results(playstore_reviews, "play_store", keyword)
        else:
            print("\n📌 [2/3] 구글 플레이스토어 건너뜀 (앱 ID 미지정)")
            results["play_store"] = []

        # 3. 앱스토어
        if appstore_app_name and appstore_app_id:
            print("\n📌 [3/3] 앱스토어 크롤링")
            appstore_reviews = self.appstore_crawler.crawl(
                appstore_app_name, appstore_app_id, max_results=max_results
            )
            results["app_store"] = appstore_reviews
            if appstore_reviews:
                save_results(appstore_reviews, "app_store", keyword)
        else:
            print("\n📌 [3/3] 앱스토어 건너뜀 (앱 정보 미지정)")
            results["app_store"] = []

        # 최종 결과 요약
        self._print_summary(keyword, results)

        return results

    def _print_summary(self, keyword: str, results: Dict[str, List[Dict]]):
        """크롤링 결과 요약 출력"""
        print("\n" + "=" * 60)
        print(f"📊 {keyword} 리뷰 크롤링 완료")
        print("=" * 60)

        total = 0
        for platform, reviews in results.items():
            count = len(reviews)
            total += count

            if platform == "naver_blog":
                name = "📝 네이버 블로그"
            elif platform == "play_store":
                name = "🤖 플레이스토어"
            else:
                name = "🍎 앱스토어"

            # 평점 통계 (앱 리뷰의 경우)
            if reviews and "rating" in reviews[0]:
                avg_rating = sum(r.get("rating", 0) for r in reviews) / len(reviews)
                print(f"  {name}: {count}개 (평균 ⭐{avg_rating:.1f})")
            else:
                print(f"  {name}: {count}개")

        print(f"\n  🎉 총 {total}개 리뷰 수집 완료!")
        print(f"  💾 결과 저장 위치: {OUTPUT_DIR}/")
        print("=" * 60)

# ==================== 메인 ====================

def main():
    parser = argparse.ArgumentParser(
        description='휴튼 서비스 리뷰 크롤링 (네이버 블로그, 플레이스토어, 앱스토어)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
사용 예시:
  # 네이버 블로그만 크롤링
  python review_crawler.py --keyword "휴튼" --naver

  # 플레이스토어만 크롤링
  python review_crawler.py --keyword "휴튼" --playstore --playstore-id "com.hueton.app"

  # 앱스토어만 크롤링
  python review_crawler.py --keyword "휴튼" --appstore --appstore-name "hueton" --appstore-id "123456789"

  # 모든 플랫폼 크롤링
  python review_crawler.py --keyword "휴튼" --all \\
    --playstore-id "com.hueton.app" \\
    --appstore-name "hueton" --appstore-id "123456789"
        """
    )

    # 기본 옵션
    parser.add_argument('--keyword', default='휴튼', help='검색 키워드 (기본: 휴튼)')
    parser.add_argument('--max-results', type=int, default=300, help='플랫폼당 최대 수집 개수 (기본: 300)')

    # 플랫폼 선택
    parser.add_argument('--all', action='store_true', help='모든 플랫폼 크롤링')
    parser.add_argument('--naver', action='store_true', help='네이버 블로그 크롤링')
    parser.add_argument('--playstore', action='store_true', help='구글 플레이스토어 크롤링')
    parser.add_argument('--appstore', action='store_true', help='애플 앱스토어 크롤링')

    # 앱 정보
    parser.add_argument('--playstore-id', help='플레이스토어 앱 패키지 ID (예: com.kakao.talk)')
    parser.add_argument('--appstore-name', help='앱스토어 앱 이름 (영문, URL용)')
    parser.add_argument('--appstore-id', help='앱스토어 앱 ID (숫자)')

    args = parser.parse_args()

    # 플랫폼 선택 확인
    if not (args.all or args.naver or args.playstore or args.appstore):
        print("⚠️  크롤링할 플랫폼을 선택해주세요: --all, --naver, --playstore, --appstore")
        parser.print_help()
        return

    print("=" * 60)
    print("🔍 리뷰 크롤링 시스템")
    print("=" * 60)
    print(f"📝 키워드: {args.keyword}")
    print(f"📊 최대 수집: 플랫폼당 {args.max_results}개")
    print()

    crawler = ReviewCrawler()

    # 전체 크롤링
    if args.all:
        crawler.crawl_all(
            keyword=args.keyword,
            playstore_app_id=args.playstore_id,
            appstore_app_name=args.appstore_name,
            appstore_app_id=args.appstore_id,
            max_results=args.max_results
        )
        return

    # 개별 크롤링
    if args.naver:
        reviews = crawler.naver_crawler.crawl(args.keyword, args.max_results)
        if reviews:
            save_results(reviews, "naver_blog", args.keyword)

    if args.playstore:
        if not args.playstore_id:
            print("❌ 플레이스토어 크롤링에는 --playstore-id가 필요합니다.")
        else:
            reviews = crawler.playstore_crawler.crawl(args.playstore_id, args.max_results)
            if reviews:
                save_results(reviews, "play_store", args.keyword)

    if args.appstore:
        if not args.appstore_name or not args.appstore_id:
            print("❌ 앱스토어 크롤링에는 --appstore-name과 --appstore-id가 필요합니다.")
        else:
            reviews = crawler.appstore_crawler.crawl(
                args.appstore_name, args.appstore_id, max_results=args.max_results
            )
            if reviews:
                save_results(reviews, "app_store", args.keyword)

if __name__ == "__main__":
    main()
