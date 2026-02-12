#!/usr/bin/env python3
"""
메뉴 알러지 분석 웹 테스트 도구
실행: python menu_web.py
브라우저: http://localhost:5000
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import urllib.parse
import requests
import os

API_KEY = os.environ.get("CLAUDE_API_KEY", "")
MODEL = "claude-3-haiku-20240307"
PORT = 5000

HTML_PAGE = """
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🍽️ 메뉴 알러지 분석</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
        }
        h1 {
            color: white;
            text-align: center;
            margin-bottom: 30px;
            font-size: 2em;
        }
        .card {
            background: white;
            border-radius: 20px;
            padding: 30px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            margin-bottom: 20px;
        }
        label {
            display: block;
            font-weight: 600;
            margin-bottom: 8px;
            color: #333;
        }
        input, textarea {
            width: 100%;
            padding: 15px;
            border: 2px solid #e0e0e0;
            border-radius: 12px;
            font-size: 16px;
            margin-bottom: 20px;
            transition: border-color 0.3s;
        }
        input:focus, textarea:focus {
            outline: none;
            border-color: #667eea;
        }
        button {
            width: 100%;
            padding: 15px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            border-radius: 12px;
            font-size: 18px;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        button:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 20px rgba(102, 126, 234, 0.4);
        }
        button:disabled {
            background: #ccc;
            cursor: not-allowed;
            transform: none;
        }
        .result {
            margin-top: 20px;
            display: none;
        }
        .result.show { display: block; }
        .result-header {
            font-size: 1.5em;
            font-weight: 700;
            margin-bottom: 20px;
            color: #333;
        }
        .ingredient-item {
            display: flex;
            align-items: center;
            padding: 15px;
            background: #f8f9fa;
            border-radius: 12px;
            margin-bottom: 10px;
        }
        .prob-bar {
            flex: 1;
            height: 8px;
            background: #e0e0e0;
            border-radius: 4px;
            margin: 0 15px;
            overflow: hidden;
        }
        .prob-fill {
            height: 100%;
            border-radius: 4px;
            transition: width 0.5s ease;
        }
        .danger { background: #ff4757; }
        .warning { background: #ffa502; }
        .safe { background: #2ed573; }
        .prob-text {
            font-weight: 700;
            min-width: 50px;
            text-align: right;
        }
        .ingredient-name {
            min-width: 80px;
            font-weight: 600;
        }
        .reason {
            font-size: 0.9em;
            color: #666;
            margin-top: 5px;
            padding-left: 95px;
        }
        .overall {
            padding: 20px;
            border-radius: 12px;
            text-align: center;
            font-size: 1.2em;
            font-weight: 600;
            margin-top: 20px;
        }
        .overall.safe-result {
            background: #d4edda;
            color: #155724;
        }
        .overall.danger-result {
            background: #f8d7da;
            color: #721c24;
        }
        .recommendation {
            margin-top: 15px;
            padding: 15px;
            background: #e7f3ff;
            border-radius: 12px;
            color: #0056b3;
        }
        .loading {
            text-align: center;
            padding: 40px;
            display: none;
        }
        .loading.show { display: block; }
        .spinner {
            width: 50px;
            height: 50px;
            border: 4px solid #f3f3f3;
            border-top: 4px solid #667eea;
            border-radius: 50%;
            animation: spin 1s linear infinite;
            margin: 0 auto 20px;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        .examples {
            margin-top: 10px;
            font-size: 0.85em;
            color: #666;
        }
        .examples span {
            background: #f0f0f0;
            padding: 3px 8px;
            border-radius: 4px;
            margin-right: 5px;
            cursor: pointer;
        }
        .examples span:hover {
            background: #e0e0e0;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🍽️ 메뉴 알러지 분석</h1>

        <div class="card">
            <label>메뉴 이름</label>
            <input type="text" id="menu" placeholder="예: 크림파스타, 김치찌개, 불고기버거">
            <div class="examples">
                예시:
                <span onclick="setMenu('크림파스타')">크림파스타</span>
                <span onclick="setMenu('김치찌개')">김치찌개</span>
                <span onclick="setMenu('새우볶음밥')">새우볶음밥</span>
            </div>

            <label style="margin-top: 20px;">제한 성분 (쉼표로 구분)</label>
            <input type="text" id="restrictions" placeholder="예: 우유, 밀, 새우, 땅콩">
            <div class="examples">
                예시:
                <span onclick="setRestrictions('우유, 밀')">우유, 밀</span>
                <span onclick="setRestrictions('새우, 갑각류')">새우, 갑각류</span>
                <span onclick="setRestrictions('돼지고기, 쇠고기')">돼지고기, 쇠고기</span>
            </div>

            <button onclick="analyze()" id="analyzeBtn" style="margin-top: 20px;">🔍 분석하기</button>
        </div>

        <div class="card loading" id="loading">
            <div class="spinner"></div>
            <p>AI가 분석 중입니다...</p>
        </div>

        <div class="card result" id="result">
            <div class="result-header" id="resultHeader"></div>
            <div id="ingredientList"></div>
            <div class="overall" id="overall"></div>
            <div class="recommendation" id="recommendation"></div>
        </div>
    </div>

    <script>
        function setMenu(value) {
            document.getElementById('menu').value = value;
        }
        function setRestrictions(value) {
            document.getElementById('restrictions').value = value;
        }

        async function analyze() {
            const menu = document.getElementById('menu').value.trim();
            const restrictions = document.getElementById('restrictions').value.trim();

            if (!menu || !restrictions) {
                alert('메뉴와 제한 성분을 모두 입력해주세요.');
                return;
            }

            const btn = document.getElementById('analyzeBtn');
            const loading = document.getElementById('loading');
            const result = document.getElementById('result');

            btn.disabled = true;
            loading.classList.add('show');
            result.classList.remove('show');

            try {
                const response = await fetch('/analyze', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ menu, restrictions })
                });

                const data = await response.json();

                if (data.error) {
                    alert('오류: ' + data.error);
                    return;
                }

                displayResult(data);
            } catch (error) {
                alert('오류가 발생했습니다: ' + error);
            } finally {
                btn.disabled = false;
                loading.classList.remove('show');
            }
        }

        function displayResult(data) {
            const result = document.getElementById('result');
            const header = document.getElementById('resultHeader');
            const list = document.getElementById('ingredientList');
            const overall = document.getElementById('overall');
            const rec = document.getElementById('recommendation');

            header.textContent = '🍽️ ' + data.menu + ' 분석 결과';

            list.innerHTML = '';
            data.results.forEach(item => {
                const prob = item.probability;
                let colorClass = prob >= 70 ? 'danger' : prob >= 30 ? 'warning' : 'safe';
                let emoji = prob >= 70 ? '🔴' : prob >= 30 ? '🟡' : '🟢';

                list.innerHTML += `
                    <div class="ingredient-item">
                        <span class="ingredient-name">${emoji} ${item.ingredient}</span>
                        <div class="prob-bar">
                            <div class="prob-fill ${colorClass}" style="width: ${prob}%"></div>
                        </div>
                        <span class="prob-text">${prob}%</span>
                    </div>
                    <div class="reason">└ ${item.reason}</div>
                `;
            });

            if (data.overall_safe) {
                overall.className = 'overall safe-result';
                overall.innerHTML = '✅ 안전하게 드실 수 있습니다!';
            } else {
                overall.className = 'overall danger-result';
                overall.innerHTML = '⚠️ 주의가 필요합니다!';
            }

            if (data.recommendation) {
                rec.style.display = 'block';
                rec.innerHTML = '💡 ' + data.recommendation;
            } else {
                rec.style.display = 'none';
            }

            result.classList.add('show');
        }
    </script>
</body>
</html>
"""

def analyze_menu(menu_name: str, restrictions: list) -> dict:
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
  "recommendation": "추천 또는 주의사항"
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

    if "```json" in text:
        text = text.split("```json")[1].split("```")[0]
    elif "```" in text:
        text = text.split("```")[1].split("```")[0]

    return json.loads(text.strip())


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.end_headers()
        self.wfile.write(HTML_PAGE.encode('utf-8'))

    def do_POST(self):
        if self.path == '/analyze':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            data = json.loads(post_data.decode('utf-8'))

            menu = data.get('menu', '')
            restrictions = [r.strip() for r in data.get('restrictions', '').split(',')]

            try:
                result = analyze_menu(menu, restrictions)
                response = json.dumps(result, ensure_ascii=False)
            except Exception as e:
                response = json.dumps({"error": str(e)}, ensure_ascii=False)

            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.end_headers()
            self.wfile.write(response.encode('utf-8'))

    def log_message(self, format, *args):
        pass  # 로그 숨김


if __name__ == '__main__':
    if not API_KEY:
        print("⚠️  CLAUDE_API_KEY 환경변수를 설정하세요:")
        print("   export CLAUDE_API_KEY='sk-ant-...'")
        exit(1)

    print(f"""
╔════════════════════════════════════════════╗
║  🍽️  메뉴 알러지 분석 웹 테스트 도구       ║
╠════════════════════════════════════════════╣
║  브라우저에서 열기:                         ║
║  👉 http://localhost:{PORT}                 ║
║                                            ║
║  종료: Ctrl+C                              ║
╚════════════════════════════════════════════╝
""")

    server = HTTPServer(('0.0.0.0', PORT), Handler)
    server.serve_forever()
