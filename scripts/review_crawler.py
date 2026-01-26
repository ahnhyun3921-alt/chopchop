#!/usr/bin/env python3
"""
휴튼 서비스 리뷰 크롤링 스크립트 (강화 버전)
네이버 블로그, 구글 플레이스토어, 앱스토어, 티스토리, 브런치 등 다양한 소스에서 수집

사용 방법:
  pip install -r requirements.txt
  python review_crawler.py --keyword "휴튼" --all \
    --playstore-id "com.danbikebi.heutonmobile" \
    --appstore-id "6469672209"
"""

import os
import re
import json
import time
import argparse
import requests
from datetime import datetime
from typing import List, Dict, Optional
from urllib.parse import quote, urlencode
from bs4 import BeautifulSoup

# ==================== 설정 ====================

# 결과 저장 디렉토리
OUTPUT_DIR = "review_results"

# 요청 헤더 (브라우저처럼 보이게)
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
    "Accept-Language": "ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7",
    "Accept-Encoding": "gzip, deflate, br",
    "Connection": "keep-alive",
}

# ==================== 유틸리티 ====================

def clean_html(text: str) -> str:
    """HTML 태그 및 특수문자 제거"""
    if not text:
        return ""
    text = re.sub(r'<[^>]+>', '', str(text))
    text = text.replace('&amp;', '&')
    text = text.replace('&lt;', '<')
    text = text.replace('&gt;', '>')
    text = text.replace('&quot;', '"')
    text = text.replace('&#39;', "'")
    text = text.replace('&nbsp;', ' ')
    text = re.sub(r'\s+', ' ', text).strip()
    return text

def save_results(reviews: List[Dict], platform: str, keyword: str):
    """결과를 JSON 파일로 저장"""
    if not reviews:
        print(f"  ⚠️  저장할 리뷰가 없습니다.")
        return None

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

    print(f"  💾 저장 완료: {filename} ({len(reviews)}개)")
    return filename

# ==================== 네이버 블로그 웹 크롤링 ====================

class NaverBlogCrawler:
    """네이버 블로그 웹 크롤링 (API 없이)"""

    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update(HEADERS)

    def search(self, keyword: str, start: int = 1) -> List[Dict]:
        """네이버 블로그 검색 (웹 크롤링)"""
        url = "https://search.naver.com/search.naver"
        params = {
            "where": "blog",
            "query": keyword,
            "start": start,
            "sm": "tab_opt",
            "nso": "so:r,p:all"  # 최신순
        }

        try:
            response = self.session.get(url, params=params, timeout=10)
            response.raise_for_status()
            soup = BeautifulSoup(response.text, 'html.parser')

            results = []
            # 블로그 검색 결과 파싱
            posts = soup.select('li.bx')

            for post in posts:
                try:
                    title_elem = post.select_one('a.title_link')
                    desc_elem = post.select_one('a.dsc_link')
                    author_elem = post.select_one('a.name')
                    date_elem = post.select_one('span.sub')

                    if title_elem:
                        results.append({
                            "platform": "naver_blog",
                            "title": clean_html(title_elem.get_text()),
                            "content": clean_html(desc_elem.get_text()) if desc_elem else "",
                            "url": title_elem.get('href', ''),
                            "author": clean_html(author_elem.get_text()) if author_elem else "",
                            "date": clean_html(date_elem.get_text()) if date_elem else "",
                            "crawled_at": datetime.now().isoformat()
                        })
                except Exception as e:
                    continue

            return results
        except Exception as e:
            print(f"    ❌ 검색 실패: {e}")
            return []

    def crawl(self, keyword: str, max_results: int = 500) -> List[Dict]:
        """네이버 블로그 리뷰 크롤링"""
        print(f"\n{'='*60}")
        print(f"📝 네이버 블로그 크롤링 (웹)")
        print(f"🔍 검색어: {keyword}")
        print(f"{'='*60}")

        all_reviews = []
        search_queries = [
            f"{keyword} 후기",
            f"{keyword} 리뷰",
            f"{keyword} 앱 후기",
            f"{keyword} 사용후기",
            f"{keyword} 자기성찰",
            f"{keyword} 앱 리뷰",
            f"{keyword} 어플",
            f"휴튼앱",
        ]

        for query in search_queries:
            print(f"\n  🔎 검색: '{query}'")

            for start in range(1, min(max_results, 300), 30):
                if len(all_reviews) >= max_results:
                    break

                results = self.search(query, start)
                if not results:
                    break

                for item in results:
                    # 중복 제거 (URL 기준)
                    if not any(r.get("url") == item.get("url") for r in all_reviews):
                        all_reviews.append(item)

                print(f"    ✅ {len(results)}개 수집 (총 {len(all_reviews)}개)")
                time.sleep(1)  # 요청 간격

        print(f"\n  📊 총 {len(all_reviews)}개 네이버 블로그 수집 완료")
        return all_reviews

# ==================== 네이버 카페 웹 크롤링 ====================

class NaverCafeCrawler:
    """네이버 카페 웹 크롤링"""

    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update(HEADERS)

    def search(self, keyword: str, start: int = 1) -> List[Dict]:
        """네이버 카페 검색"""
        url = "https://search.naver.com/search.naver"
        params = {
            "where": "article",
            "query": keyword,
            "start": start,
            "sm": "tab_opt",
            "nso": "so:r,p:all"
        }

        try:
            response = self.session.get(url, params=params, timeout=10)
            response.raise_for_status()
            soup = BeautifulSoup(response.text, 'html.parser')

            results = []
            posts = soup.select('li.bx')

            for post in posts:
                try:
                    title_elem = post.select_one('a.title_link')
                    desc_elem = post.select_one('div.dsc_txt')
                    info_elem = post.select_one('a.sub_txt')
                    date_elem = post.select_one('span.sub_time')

                    if title_elem:
                        results.append({
                            "platform": "naver_cafe",
                            "title": clean_html(title_elem.get_text()),
                            "content": clean_html(desc_elem.get_text()) if desc_elem else "",
                            "url": title_elem.get('href', ''),
                            "cafe_name": clean_html(info_elem.get_text()) if info_elem else "",
                            "date": clean_html(date_elem.get_text()) if date_elem else "",
                            "crawled_at": datetime.now().isoformat()
                        })
                except:
                    continue

            return results
        except Exception as e:
            print(f"    ❌ 검색 실패: {e}")
            return []

    def crawl(self, keyword: str, max_results: int = 300) -> List[Dict]:
        """네이버 카페 리뷰 크롤링"""
        print(f"\n{'='*60}")
        print(f"☕ 네이버 카페 크롤링")
        print(f"🔍 검색어: {keyword}")
        print(f"{'='*60}")

        all_reviews = []
        search_queries = [
            f"{keyword} 후기",
            f"{keyword} 리뷰",
            f"{keyword} 앱",
        ]

        for query in search_queries:
            print(f"\n  🔎 검색: '{query}'")

            for start in range(1, min(max_results, 200), 30):
                if len(all_reviews) >= max_results:
                    break

                results = self.search(query, start)
                if not results:
                    break

                for item in results:
                    if not any(r.get("url") == item.get("url") for r in all_reviews):
                        all_reviews.append(item)

                print(f"    ✅ {len(results)}개 수집 (총 {len(all_reviews)}개)")
                time.sleep(1)

        print(f"\n  📊 총 {len(all_reviews)}개 네이버 카페 수집 완료")
        return all_reviews

# ==================== 구글 플레이스토어 크롤링 ====================

class PlayStoreCrawler:
    """구글 플레이스토어 리뷰 크롤링"""

    def __init__(self):
        try:
            from google_play_scraper import Sort, reviews_all, reviews, app
            self.Sort = Sort
            self.reviews_all = reviews_all
            self.reviews_func = reviews
            self.app_func = app
            self.available = True
        except ImportError:
            print("  ⚠️  google-play-scraper 미설치")
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

    def crawl(self, app_id: str, max_results: int = 1000) -> List[Dict]:
        """플레이스토어 모든 리뷰 크롤링"""
        if not self.available:
            return []

        print(f"\n{'='*60}")
        print(f"🤖 구글 플레이스토어 크롤링")
        print(f"📱 앱 ID: {app_id}")
        print(f"{'='*60}")

        app_info = self.get_app_info(app_id)
        if app_info:
            print(f"  📱 앱 이름: {app_info['title']}")
            print(f"  ⭐ 평점: {app_info['rating']:.1f}")
            print(f"  📊 총 리뷰: {app_info['reviews_count']:,}개")

        all_reviews = []

        # 모든 리뷰 수집 시도
        print(f"\n  🔄 전체 리뷰 수집 중...")
        try:
            # reviews_all로 모든 리뷰 수집
            result = self.reviews_all(
                app_id,
                lang='ko',
                country='kr',
                sleep_milliseconds=100
            )

            for item in result[:max_results]:
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
                    "app_version": item.get("reviewCreatedVersion", ""),
                    "crawled_at": datetime.now().isoformat()
                }
                all_reviews.append(review)

            print(f"    ✅ {len(all_reviews)}개 수집 완료")

        except Exception as e:
            print(f"  ⚠️  전체 수집 실패, 페이지별 수집 시도: {e}")

            # 폴백: 페이지별 수집
            for sort_type in [self.Sort.NEWEST, self.Sort.MOST_RELEVANT]:
                try:
                    result, _ = self.reviews_func(
                        app_id, lang='ko', country='kr',
                        sort=sort_type, count=500
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
                            "crawled_at": datetime.now().isoformat()
                        }
                        key = f"{review['author']}:{review['content'][:30]}"
                        if not any(f"{r['author']}:{r['content'][:30]}" == key for r in all_reviews):
                            all_reviews.append(review)
                except:
                    pass

        print(f"\n  📊 총 {len(all_reviews)}개 플레이스토어 리뷰 수집 완료")
        return all_reviews

# ==================== 앱스토어 크롤링 (iTunes API) ====================

class AppStoreCrawler:
    """앱스토어 리뷰 크롤링 (iTunes RSS API 직접 호출)"""

    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update(HEADERS)

    def get_app_info(self, app_id: str, country: str = "kr") -> Optional[Dict]:
        """iTunes API로 앱 정보 조회"""
        url = f"https://itunes.apple.com/lookup?id={app_id}&country={country}"
        try:
            response = self.session.get(url, timeout=10)
            data = response.json()
            if data.get("resultCount", 0) > 0:
                result = data["results"][0]
                return {
                    "app_id": app_id,
                    "title": result.get("trackName", ""),
                    "developer": result.get("artistName", ""),
                    "rating": result.get("averageUserRating", 0),
                    "reviews_count": result.get("userRatingCount", 0),
                    "version": result.get("version", ""),
                    "url": result.get("trackViewUrl", "")
                }
        except Exception as e:
            print(f"  ❌ 앱 정보 조회 실패: {e}")
        return None

    def get_reviews_rss(self, app_id: str, country: str = "kr", page: int = 1) -> List[Dict]:
        """iTunes RSS로 리뷰 가져오기"""
        url = f"https://itunes.apple.com/{country}/rss/customerreviews/page={page}/id={app_id}/sortby=mostrecent/json"

        try:
            response = self.session.get(url, timeout=15)
            response.raise_for_status()
            data = response.json()

            entries = data.get("feed", {}).get("entry", [])
            if not entries:
                return []

            # 첫 번째 entry는 앱 정보일 수 있음
            reviews = []
            for entry in entries:
                # 리뷰인지 확인 (rating이 있으면 리뷰)
                if "im:rating" in entry:
                    review = {
                        "platform": "app_store",
                        "app_id": app_id,
                        "title": entry.get("title", {}).get("label", ""),
                        "content": entry.get("content", {}).get("label", ""),
                        "rating": int(entry.get("im:rating", {}).get("label", 0)),
                        "author": entry.get("author", {}).get("name", {}).get("label", ""),
                        "version": entry.get("im:version", {}).get("label", ""),
                        "vote_count": int(entry.get("im:voteCount", {}).get("label", 0)),
                        "crawled_at": datetime.now().isoformat()
                    }
                    reviews.append(review)

            return reviews
        except Exception as e:
            return []

    def crawl(self, app_id: str, country: str = "kr", max_results: int = 500) -> List[Dict]:
        """앱스토어 리뷰 크롤링"""
        print(f"\n{'='*60}")
        print(f"🍎 앱스토어 크롤링 (iTunes RSS)")
        print(f"📱 앱 ID: {app_id}")
        print(f"🌏 국가: {country}")
        print(f"{'='*60}")

        # 앱 정보 조회
        app_info = self.get_app_info(app_id, country)
        if app_info:
            print(f"  📱 앱 이름: {app_info['title']}")
            print(f"  ⭐ 평점: {app_info['rating']:.1f}")
            print(f"  📊 총 평가: {app_info['reviews_count']:,}개")

        all_reviews = []

        # 여러 국가에서 수집
        countries = [country, "us"] if country != "us" else ["us"]

        for c in countries:
            print(f"\n  🔄 {c.upper()} 리뷰 수집 중...")

            for page in range(1, 11):  # 최대 10페이지 (페이지당 ~50개)
                if len(all_reviews) >= max_results:
                    break

                reviews = self.get_reviews_rss(app_id, c, page)
                if not reviews:
                    break

                for review in reviews:
                    review["country"] = c
                    # 중복 제거
                    key = f"{review['author']}:{review['content'][:30]}"
                    if not any(f"{r['author']}:{r['content'][:30]}" == key for r in all_reviews):
                        all_reviews.append(review)

                print(f"    페이지 {page}: {len(reviews)}개 (총 {len(all_reviews)}개)")
                time.sleep(0.5)

        print(f"\n  📊 총 {len(all_reviews)}개 앱스토어 리뷰 수집 완료")
        return all_reviews

# ==================== 티스토리 크롤링 ====================

class TistoryCrawler:
    """티스토리 블로그 크롤링"""

    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update(HEADERS)

    def search(self, keyword: str, page: int = 1) -> List[Dict]:
        """다음 검색으로 티스토리 블로그 검색"""
        url = "https://search.daum.net/search"
        params = {
            "w": "blog",
            "q": keyword,
            "p": page,
            "DA": "STC"
        }

        try:
            response = self.session.get(url, params=params, timeout=10)
            response.raise_for_status()
            soup = BeautifulSoup(response.text, 'html.parser')

            results = []
            posts = soup.select('li[data-docid]')

            for post in posts:
                try:
                    title_elem = post.select_one('a.f_link_b')
                    desc_elem = post.select_one('p.f_eb.desc')
                    info_elem = post.select_one('a.f_nb.name')
                    date_elem = post.select_one('span.date')

                    if title_elem:
                        url = title_elem.get('href', '')
                        # 티스토리만 필터링
                        if 'tistory.com' in url:
                            results.append({
                                "platform": "tistory",
                                "title": clean_html(title_elem.get_text()),
                                "content": clean_html(desc_elem.get_text()) if desc_elem else "",
                                "url": url,
                                "author": clean_html(info_elem.get_text()) if info_elem else "",
                                "date": clean_html(date_elem.get_text()) if date_elem else "",
                                "crawled_at": datetime.now().isoformat()
                            })
                except:
                    continue

            return results
        except Exception as e:
            print(f"    ❌ 검색 실패: {e}")
            return []

    def crawl(self, keyword: str, max_results: int = 200) -> List[Dict]:
        """티스토리 블로그 크롤링"""
        print(f"\n{'='*60}")
        print(f"📘 티스토리 크롤링")
        print(f"🔍 검색어: {keyword}")
        print(f"{'='*60}")

        all_reviews = []
        search_queries = [
            f"{keyword} 후기",
            f"{keyword} 리뷰",
            f"{keyword} 앱",
        ]

        for query in search_queries:
            print(f"\n  🔎 검색: '{query}'")

            for page in range(1, 11):
                if len(all_reviews) >= max_results:
                    break

                results = self.search(query, page)
                if not results:
                    break

                for item in results:
                    if not any(r.get("url") == item.get("url") for r in all_reviews):
                        all_reviews.append(item)

                print(f"    페이지 {page}: {len(results)}개 (총 {len(all_reviews)}개)")
                time.sleep(1)

        print(f"\n  📊 총 {len(all_reviews)}개 티스토리 수집 완료")
        return all_reviews

# ==================== 브런치 크롤링 ====================

class BrunchCrawler:
    """브런치 글 크롤링"""

    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update(HEADERS)

    def search(self, keyword: str) -> List[Dict]:
        """브런치 검색"""
        url = f"https://brunch.co.kr/search"
        params = {"q": keyword}

        try:
            response = self.session.get(url, params=params, timeout=10)
            response.raise_for_status()
            soup = BeautifulSoup(response.text, 'html.parser')

            results = []
            posts = soup.select('li.search_item')

            for post in posts:
                try:
                    title_elem = post.select_one('strong.tit_subject')
                    desc_elem = post.select_one('span.txt_sub')
                    author_elem = post.select_one('span.txt_by')
                    link_elem = post.select_one('a.link_post')

                    if title_elem and link_elem:
                        results.append({
                            "platform": "brunch",
                            "title": clean_html(title_elem.get_text()),
                            "content": clean_html(desc_elem.get_text()) if desc_elem else "",
                            "url": "https://brunch.co.kr" + link_elem.get('href', ''),
                            "author": clean_html(author_elem.get_text()) if author_elem else "",
                            "crawled_at": datetime.now().isoformat()
                        })
                except:
                    continue

            return results
        except Exception as e:
            print(f"    ❌ 검색 실패: {e}")
            return []

    def crawl(self, keyword: str, max_results: int = 100) -> List[Dict]:
        """브런치 크롤링"""
        print(f"\n{'='*60}")
        print(f"🥯 브런치 크롤링")
        print(f"🔍 검색어: {keyword}")
        print(f"{'='*60}")

        all_reviews = []
        search_queries = [
            f"{keyword}",
            f"{keyword} 후기",
            f"{keyword} 리뷰",
        ]

        for query in search_queries:
            print(f"\n  🔎 검색: '{query}'")
            results = self.search(query)

            for item in results:
                if not any(r.get("url") == item.get("url") for r in all_reviews):
                    all_reviews.append(item)

            print(f"    ✅ {len(results)}개 수집 (총 {len(all_reviews)}개)")
            time.sleep(1)

        print(f"\n  📊 총 {len(all_reviews)}개 브런치 수집 완료")
        return all_reviews

# ==================== 통합 크롤러 ====================

class ReviewCrawler:
    """리뷰 크롤링 통합 관리자"""

    def __init__(self):
        self.naver_blog = NaverBlogCrawler()
        self.naver_cafe = NaverCafeCrawler()
        self.playstore = PlayStoreCrawler()
        self.appstore = AppStoreCrawler()
        self.tistory = TistoryCrawler()
        self.brunch = BrunchCrawler()

    def crawl_all(self, keyword: str,
                  playstore_id: str = None,
                  appstore_id: str = None,
                  max_results: int = 500) -> Dict[str, List[Dict]]:
        """모든 플랫폼에서 리뷰 크롤링"""

        print("\n" + "🚀" * 30)
        print(f"\n🎯 '{keyword}' 리뷰 크롤링 시작\n")
        print("🚀" * 30)

        results = {}
        total_count = 0

        # 1. 네이버 블로그
        print("\n" + "="*60)
        print("📌 [1/6] 네이버 블로그")
        print("="*60)
        reviews = self.naver_blog.crawl(keyword, max_results)
        results["naver_blog"] = reviews
        if reviews:
            save_results(reviews, "naver_blog", keyword)
            total_count += len(reviews)

        # 2. 네이버 카페
        print("\n" + "="*60)
        print("📌 [2/6] 네이버 카페")
        print("="*60)
        reviews = self.naver_cafe.crawl(keyword, max_results)
        results["naver_cafe"] = reviews
        if reviews:
            save_results(reviews, "naver_cafe", keyword)
            total_count += len(reviews)

        # 3. 구글 플레이스토어
        print("\n" + "="*60)
        print("📌 [3/6] 구글 플레이스토어")
        print("="*60)
        if playstore_id:
            reviews = self.playstore.crawl(playstore_id, max_results)
            results["play_store"] = reviews
            if reviews:
                save_results(reviews, "play_store", keyword)
                total_count += len(reviews)
        else:
            print("  ⏭️  건너뜀 (앱 ID 미지정)")
            results["play_store"] = []

        # 4. 앱스토어
        print("\n" + "="*60)
        print("📌 [4/6] 앱스토어")
        print("="*60)
        if appstore_id:
            reviews = self.appstore.crawl(appstore_id, max_results=max_results)
            results["app_store"] = reviews
            if reviews:
                save_results(reviews, "app_store", keyword)
                total_count += len(reviews)
        else:
            print("  ⏭️  건너뜀 (앱 ID 미지정)")
            results["app_store"] = []

        # 5. 티스토리
        print("\n" + "="*60)
        print("📌 [5/6] 티스토리")
        print("="*60)
        reviews = self.tistory.crawl(keyword, max_results // 2)
        results["tistory"] = reviews
        if reviews:
            save_results(reviews, "tistory", keyword)
            total_count += len(reviews)

        # 6. 브런치
        print("\n" + "="*60)
        print("📌 [6/6] 브런치")
        print("="*60)
        reviews = self.brunch.crawl(keyword, max_results // 3)
        results["brunch"] = reviews
        if reviews:
            save_results(reviews, "brunch", keyword)
            total_count += len(reviews)

        # 최종 요약
        self._print_summary(keyword, results, total_count)

        # 통합 파일 저장
        self._save_combined(keyword, results)

        return results

    def _print_summary(self, keyword: str, results: Dict, total: int):
        """결과 요약"""
        print("\n" + "🎉" * 30)
        print(f"\n📊 '{keyword}' 크롤링 완료!")
        print("=" * 60)

        platform_names = {
            "naver_blog": "📝 네이버 블로그",
            "naver_cafe": "☕ 네이버 카페",
            "play_store": "🤖 플레이스토어",
            "app_store": "🍎 앱스토어",
            "tistory": "📘 티스토리",
            "brunch": "🥯 브런치"
        }

        for platform, reviews in results.items():
            name = platform_names.get(platform, platform)
            count = len(reviews)

            if reviews and "rating" in reviews[0]:
                avg = sum(r.get("rating", 0) for r in reviews) / len(reviews)
                print(f"  {name}: {count}개 (평균 ⭐{avg:.1f})")
            else:
                print(f"  {name}: {count}개")

        print(f"\n  🎊 총 {total}개 리뷰/후기 수집 완료!")
        print(f"  💾 저장 위치: {OUTPUT_DIR}/")
        print("=" * 60)

    def _save_combined(self, keyword: str, results: Dict):
        """모든 결과를 통합 파일로 저장"""
        all_reviews = []
        for platform, reviews in results.items():
            all_reviews.extend(reviews)

        if all_reviews:
            os.makedirs(OUTPUT_DIR, exist_ok=True)
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"{OUTPUT_DIR}/combined_{keyword}_{timestamp}.json"

            with open(filename, 'w', encoding='utf-8') as f:
                json.dump({
                    "keyword": keyword,
                    "crawled_at": datetime.now().isoformat(),
                    "total_count": len(all_reviews),
                    "by_platform": {k: len(v) for k, v in results.items()},
                    "reviews": all_reviews
                }, f, ensure_ascii=False, indent=2)

            print(f"\n  📦 통합 파일: {filename}")

# ==================== 메인 ====================

def main():
    parser = argparse.ArgumentParser(
        description='휴튼 리뷰 크롤링 (네이버, 플레이스토어, 앱스토어, 티스토리, 브런치)',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    parser.add_argument('--keyword', default='휴튼', help='검색 키워드')
    parser.add_argument('--max-results', type=int, default=500, help='플랫폼당 최대 수집 개수')
    parser.add_argument('--all', action='store_true', help='모든 플랫폼 크롤링')
    parser.add_argument('--naver', action='store_true', help='네이버 블로그만')
    parser.add_argument('--cafe', action='store_true', help='네이버 카페만')
    parser.add_argument('--playstore', action='store_true', help='플레이스토어만')
    parser.add_argument('--appstore', action='store_true', help='앱스토어만')
    parser.add_argument('--tistory', action='store_true', help='티스토리만')
    parser.add_argument('--brunch', action='store_true', help='브런치만')
    parser.add_argument('--playstore-id', help='플레이스토어 앱 ID')
    parser.add_argument('--appstore-id', help='앱스토어 앱 ID')

    args = parser.parse_args()

    if not any([args.all, args.naver, args.cafe, args.playstore, args.appstore, args.tistory, args.brunch]):
        print("⚠️  플랫폼을 선택하세요: --all, --naver, --cafe, --playstore, --appstore, --tistory, --brunch")
        parser.print_help()
        return

    crawler = ReviewCrawler()

    if args.all:
        crawler.crawl_all(
            keyword=args.keyword,
            playstore_id=args.playstore_id,
            appstore_id=args.appstore_id,
            max_results=args.max_results
        )
    else:
        if args.naver:
            reviews = crawler.naver_blog.crawl(args.keyword, args.max_results)
            if reviews: save_results(reviews, "naver_blog", args.keyword)

        if args.cafe:
            reviews = crawler.naver_cafe.crawl(args.keyword, args.max_results)
            if reviews: save_results(reviews, "naver_cafe", args.keyword)

        if args.playstore and args.playstore_id:
            reviews = crawler.playstore.crawl(args.playstore_id, args.max_results)
            if reviews: save_results(reviews, "play_store", args.keyword)

        if args.appstore and args.appstore_id:
            reviews = crawler.appstore.crawl(args.appstore_id, max_results=args.max_results)
            if reviews: save_results(reviews, "app_store", args.keyword)

        if args.tistory:
            reviews = crawler.tistory.crawl(args.keyword, args.max_results)
            if reviews: save_results(reviews, "tistory", args.keyword)

        if args.brunch:
            reviews = crawler.brunch.crawl(args.keyword, args.max_results)
            if reviews: save_results(reviews, "brunch", args.keyword)

if __name__ == "__main__":
    main()
