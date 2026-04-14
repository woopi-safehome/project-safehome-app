# SafeHome App

등기부등본 PDF를 업로드하면 AI가 권리 관계를 분석하고 안전 등급을 제공하는 모바일/웹 클라이언트입니다.

## 기술 스택

| 항목 | 버전 |
|------|------|
| React Native | 0.81.5 |
| Expo | 54.0.31 |
| Expo Router | 6.0.21 |
| TypeScript | 5.9 |
| React | 19.1.0 |

## 사전 준비

- Node.js 18+
- npm

API 서버(`project-safehome-api`, 포트 8080)가 먼저 실행되어 있어야 합니다.

## 로컬 실행 방법

### 의존성 설치

```bash
npm install
```

### 웹 브라우저 (가장 간단)

```bash
npm run web
```

브라우저에서 `http://localhost:8081`로 접속합니다.

### Expo Go (실제 기기)

```bash
npm start
```

스마트폰에 [Expo Go](https://expo.dev/go) 앱을 설치한 뒤 QR 코드를 스캔합니다.

### Android 에뮬레이터

```bash
npm run android
```

Android Studio와 에뮬레이터가 설치되어 있어야 합니다.
에뮬레이터에서는 `localhost` 대신 `10.0.2.2`로 API 서버에 접근합니다 (자동 처리됨).

> iOS 시뮬레이터는 macOS 전용입니다.

## 전체 실행 순서

```bash
# 1. AI API 서버 (Flask, 포트 5000) — 반드시 먼저 시작
cd project-safehome-ai-api
python app.py

# 2. API 서버 (Spring Boot, 포트 8080)
cd project-safehome-api
./gradlew bootRun

# 3. App (Expo, 포트 8081)
cd project-safehome-app
npm run web
```

## 호출 흐름

```
App (8081)
  └─ POST /api/deed/analyze  (PDF 업로드 → SSE 스트리밍 수신)
       └─ API (8080)
            └─ POST /api/deed/analyze  (AI 분석 요청)
                 └─ AI API (5000)  →  OpenAI GPT
```

분석 진행 상황은 SSE 이벤트로 실시간 수신되며, 완료 시 결과 화면으로 자동 이동합니다.

## 화면 구성

| 화면 | 경로 | 설명 |
|------|------|------|
| 홈 | `/` | 서비스 소개 및 업로드 진입 |
| 업로드 | `/upload` | PDF 파일 선택 및 분석 시작 |
| 결과 | `/result/{jobId}` | 안전 등급 및 분석 결과 표시 |

## 주의사항

- **실행 순서**: AI API → API 서버 → App 순서로 시작해야 합니다.
- **웹 브라우저**: `expo-document-picker`가 웹에서 blob URL을 반환하므로, `services/api.ts`에서 `Platform.OS === 'web'` 분기로 Blob 변환 처리를 합니다.
- **CORS**: API 서버에 CORS 설정이 포함되어 있어 `localhost:8081` → `localhost:8080` 크로스 오리진 요청이 허용됩니다.
- **node_modules 변경 후**: `npm install && expo start --clear`로 캐시를 초기화하세요.
