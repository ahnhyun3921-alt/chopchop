# Claude API 설정 가이드

## 1. Anthropic API 키 발급

### 1.1 Anthropic Console 접속
1. [Anthropic Console](https://console.anthropic.com/) 접속
2. 계정 생성 또는 로그인
3. Settings > API Keys 이동

### 1.2 API 키 생성
1. "Create Key" 클릭
2. 키 이름 입력: `SafeEat-Production`
3. API 키 복사 (한 번만 표시됨!)
4. 안전한 곳에 저장

### 1.3 크레딧 확인
- Settings > Billing에서 크레딧 잔액 확인
- 무료 크레딧으로 시작 가능
- 프로덕션 사용 시 결제 수단 등록 필요

## 2. 사용할 모델

SafeEat 앱에서는 **Claude 3.5 Haiku** 모델을 사용합니다:
- 모델 ID: `claude-3-5-haiku-20241022`
- 특징: 빠른 응답 속도, 저렴한 비용
- 용도: 메뉴 → 재료 분석, 알러지 확률 계산

### 가격 (2026년 1월 기준)
- Input: $0.80 per million tokens
- Output: $4.00 per million tokens

메뉴 1개 분석 시 예상 비용: 약 $0.001 ~ $0.002

## 3. .env 파일에 API 키 추가

`/home/user/chopchop/.env` 파일에 추가:

```bash
# Claude API Key (Anthropic)
CLAUDE_API_KEY=sk-ant-api03-xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

## 4. API 사용 예시

### 4.1 메뉴 → 재료 분석
```
Input: "까르보나라 파스타"
Output: {
  "ingredients": ["파스타면 (밀)", "베이컨 (돼지고기)", "달걀", "파마산 치즈 (우유)", "후추", "소금"],
  "allergens": ["밀", "돼지고기", "달걀", "우유"]
}
```

### 4.2 알러지 포함 확률 계산
```
Input:
- 메뉴: "까르보나라 파스타"
- 제한 성분: ["우유"]

Output: {
  "safe": false,
  "probability": 5,  // 우유 미포함 가능성 5%
  "reason": "파마산 치즈는 필수 재료로 우유가 포함됩니다",
  "tags": ["우유 포함 가능성 95%"]
}
```

## 5. API 호출 최적화

### 5.1 배치 처리
- 한 번에 여러 메뉴를 분석하여 API 호출 횟수 감소
- 예: 10개 메뉴를 1번의 API 호출로 처리

### 5.2 캐싱
- Firestore에 분석 결과 저장
- 동일한 메뉴는 재분석하지 않음
- 캐시 키: 메뉴명 + 식당ID

### 5.3 에러 처리
- Rate limit 초과 시 재시도 로직
- Timeout 설정 (30초)
- 네트워크 에러 시 로컬 캐시 사용

## 6. 보안

### 6.1 API 키 보호
- ❌ 절대 코드에 직접 하드코딩하지 말 것
- ❌ Git에 커밋하지 말 것
- ✅ 환경 변수 또는 Xcode Config 파일 사용
- ✅ .gitignore에 .env 추가

### 6.2 프록시 서버 (권장)
프로덕션 환경에서는 iOS 앱에서 직접 API 키를 사용하지 말고,
자체 백엔드 서버를 통해 Claude API 호출:

```
iOS App → Your Server → Claude API
```

이유:
- API 키 노출 방지
- 사용량 모니터링
- 비용 관리
- Rate limiting

## 7. 사용량 모니터링

### 7.1 Anthropic Console
- Console > Usage에서 실시간 사용량 확인
- 일별/월별 통계 확인
- 예산 초과 알림 설정

### 7.2 앱 내 로깅
```swift
print("[Claude API] Menu analysis: \(menuName)")
print("[Claude API] Tokens used - Input: \(inputTokens), Output: \(outputTokens)")
print("[Claude API] Estimated cost: $\(cost)")
```

## 8. 다음 단계

1. API 키 발급 완료
2. .env 파일에 키 저장
3. ClaudeAPIService 코드 작성
4. 메뉴 분석 로직 구현
5. 테스트 및 검증

## 9. 참고 자료

- [Anthropic API Documentation](https://docs.anthropic.com/claude/reference/getting-started-with-the-api)
- [Claude 3.5 Haiku Model Card](https://www.anthropic.com/claude/haiku)
- [API Pricing](https://www.anthropic.com/pricing)
