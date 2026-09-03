# SafeHome App

등기부등본 AI 분석 서비스의 **Flutter 모바일 앱** (Android / iOS).
카카오 로그인 → PDF 업로드 → SSE로 분석 진행 구독 → 결과 확인 → 분석 이력 관리.

> **범위**: `project-safehome-app/**`
> **연관**: [API README](../project-safehome-api/README.md) — App→API 계약의 원본 (워크스페이스에 함께 있을 때만 유효한 링크)
> **여기 없는 것**: 파일·클래스 이름과 정확한 버전 — 코드와 `pubspec.yaml`이 답한다.

---

## TL;DR

소셜 로그인 → 문서 업로드 → 진행 상황 실시간 구독 → 결과 확인 → 이력 관리.

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # 직렬화 모델 변경 시 필수
flutter analyze
```

**실행은 환경 정의 파일을 주입하는 스크립트로 한다** (`scripts/` 아래 환경별로 있다).
직접 실행하면 키가 빈 값으로 컴파일되어 **빌드는 성공하고 로그인만 실패한다.**

스택과 버전은 `pubspec.yaml`, 환경 변수는 [`dart_defines/README.md`](dart_defines/README.md)가 답한다.

---

## 최초 설정 (1회)

키 파일 2개를 **각각** 채워야 한다. 하나만 채우면 빌드는 되는데 로그인에서 실패한다.

| # | 파일 | 이유 |
|:-:|------|------|
| 1 | `dart_defines/{local,dev,prd}.json` | Dart 런타임이 읽는 값. `*.json.example`을 복사해 사용 |
| 2 | `android/local.properties` 의 `kakaoNativeAppKey=...` | **Gradle이 OAuth 리다이렉트 스킴을 만들 때 직접 읽는다.** dart-define으로는 전달되지 않는다 |

```bash
cp dart_defines/local.json.example dart_defines/local.json   # 값 입력
```

`dart_defines/*.json`은 `.gitignore` 대상이다. 변수 목록·발급처 → [`dart_defines/README.md`](dart_defines/README.md)

---

## 작업 레시피

파일 이름이 아니라 **순서**가 중요하다.

| 하려는 일 | 순서 |
|-----------|------|
| **화면 추가** | 화면 + 상태를 짝으로 생성 → **라우터에 등록** → [`lib/features/README.md`](lib/features/README.md) |
| **서버 응답 필드 추가** | 직렬화 모델 → **코드 생성 재실행** → 통신 계층 → 사용하는 화면 |
| **새 서버 호출 추가** | 통신 계층에 추가 → 해당 화면의 상태 → [`lib/core/README.md`](lib/core/README.md) |
| **에러 처리 추가** | 예외 타입 정의 → 호출부 |
| **테마·색상 변경** | 색상 상수 → 테마 정의 |
| **푸시 동작 변경** | 푸시 서비스 → 앱 위젯의 등록부 |

참조할 구현이 필요하면 이미 만들어진 화면 폴더 중 하나를 본다.

---

## 구조

```
lib/
├── main.dart / main_prd.dart   # 진입점 (flavor만 다름)
├── app.dart                    # MaterialApp.router + GoRouter 라우트 정의 + FCM 핸들러 등록
├── core/                       # 공통 인프라 → lib/core/README.md
│   ├── config/ constants/ errors/ services/
├── models/deed.dart            # freezed 도메인 모델 (+ .freezed.dart / .g.dart 생성물)
├── features/                   # 화면별 Notifier + Screen → lib/features/README.md
└── widgets/                    # 공통 위젯 (현재 비어 있음)
```

---

## 화면 구성

로그인 전(스플래시·로그인·온보딩)과 로그인 후(홈·업로드·분석중·결과·마이페이지)로 나뉜다.
**스플래시가 초기 경로**이며, 저장된 토큰을 확인해 로그인 화면과 홈으로 분기한다.

라우트 경로와 화면의 대응은 라우터 정의가 답한다. 화면별 상태 관리 → [`lib/features/README.md`](lib/features/README.md)

---

## API 통신

엔드포인트 스펙의 원본은 **서버 저장소 README의 "App→API 계약" 절**이다.
이 문서는 클라이언트가 어떻게 부르는지만 적는다. 형식이 의심스러우면 그쪽을 확인한다.
클라이언트 구현은 `ApiClient` 하나에 모여 있다.

```
① POST /api/deed/upload        → jobId
② GET  /api/deed/jobs/{id}/stream (SSE) → SseEvent 스트림
③ COMPLETED 수신 → GET /api/deed/jobs/{id} → DeedJob → /result/:jobId 이동
```

메서드별 매핑·프로바이더 → [`lib/core/README.md`](lib/core/README.md)

---

## 환경 / 플레이버

| 플레이버 | 진입점 | 정의 파일 | API 대상 |
|---------|-------|----------|---------|
| local | `main.dart` | `dart_defines/local.json` | `http://10.0.2.2:8080` (에뮬레이터→호스트) |
| dev | `main.dart` | `dart_defines/dev.json` | `http://devupii.store:38080` |
| prd | `main_prd.dart` | `dart_defines/prd.json` | 운영 서버 |

`API_URL` 미주입 시 `AppConfig.apiBaseUrl`이 `http://10.0.2.2:8080`으로 폴백한다.
실기기에서는 `--dart-define=API_URL=http://<서버IP>:8080`으로 덮어쓴다.

Sentry `tracesSampleRate`: prd `0.1` / 그 외 `1.0` (`AppConfig.init`).

---

## 빌드

디버그·릴리스 모두 **환경 정의 파일 주입이 필수**다. 릴리스는 운영 진입점을 지정한다.
정확한 명령은 `scripts/` 아래 환경별 스크립트가 갖고 있다.

### 네이티브 빌드 설정

빌드 도구 버전이 특정 조합으로 고정돼 있다. **일부 플러그인이 최신 툴체인과 충돌**하기 때문이며,
불필요해 보인다고 이 고정을 풀면 빌드가 깨진다.

빌드가 설명되지 않는 이유로 실패하면 캐시를 지우고 의존성을 다시 받는 것부터 시도한다.

---

## 함정 & 결정 이유

| 함정 | 내용 |
|------|------|
| **진입점마다 초기화가 필요** | 진입점이 여러 개인데 초기화가 한쪽에만 있으면, 그 빌드에서만 로그인·푸시가 조용히 죽는다 |
| **소셜 로그인 키는 두 곳에** | 런타임이 읽는 정의 파일과, 네이티브 빌드가 인증 리다이렉트를 만들 때 읽는 설정. 한 곳만 채우면 빌드는 되고 로그인에서 실패한다 |
| **모델 수정 후 코드 생성** | 빠뜨리면 생성물이 옛 스키마로 남아 JSON 해석이 조용히 깨진다 |
| **분석 결과의 이중 해석** | 서버가 JSON 원본으로 내려주므로 문자열로 들어오는 경우 한 번 더 해석한다 |
| **스트리밍은 직접 파싱** | 전용 라이브러리 없이 처리한다. 데이터 조각이 줄 중간에서 끊길 수 있어 이월 버퍼가 있다. 건드리면 간헐적으로 이벤트를 잃는다 |
| **정의 파일 주입 누락** | 빌드는 성공하고 로그인만 실패해 원인을 찾기 어렵다. 스크립트를 쓴다 |
| **자동 토큰 갱신이 없다** | 갱신은 앱 시작 시 한 번뿐이다. 사용 중 만료되면 그 요청은 실패하며, 화면이 감당해야 한다 |
| **공통 위젯 폴더는 비어 있다** | 자리만 만들어 뒀다. 화면 전용 위젯은 그 화면 폴더 아래 둔다 |

---

## 문서 지도

| 알고 싶은 것 | 문서 |
|-------------|------|
| 공통 인프라 (ApiClient·FCM·토큰·로거) | [`lib/core/README.md`](lib/core/README.md) |
| 화면별 구조·Riverpod 패턴·FCM 흐름·모델 타입 | [`lib/features/README.md`](lib/features/README.md) |
| 환경 변수 목록·발급처 | [`dart_defines/README.md`](dart_defines/README.md) |
| AI 작업 지침 | [`CLAUDE.md`](CLAUDE.md) |
