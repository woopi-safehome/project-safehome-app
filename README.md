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
dart run build_runner build --delete-conflicting-outputs
flutter analyze
```

실행은 `scripts/` 아래 환경별 스크립트로 한다. 환경 정의 파일을 주입해 준다.

스택과 버전은 `pubspec.yaml`, 환경 변수는 [`dart_defines/README.md`](dart_defines/README.md)가 답한다.

---

## 최초 설정 (1회)

소셜 로그인 키를 넣을 곳이 두 군데다.

| # | 위치 | 읽는 주체 |
|:-:|------|----------|
| 1 | 환경 정의 파일 (`*.json.example`을 복사해 사용) | Dart 런타임 |
| 2 | 네이티브 로컬 설정 | Gradle — 인증 리다이렉트 스킴 생성 시 |

```bash
cp dart_defines/local.json.example dart_defines/local.json   # 값 입력
```

`dart_defines/*.json`은 `.gitignore` 대상이다. 변수 목록·발급처 → [`dart_defines/README.md`](dart_defines/README.md)

---

## 작업 레시피

파일 이름이 아니라 **순서**가 중요하다.

| 하려는 일 | 순서 |
|-----------|------|
| **화면 추가** | 화면 폴더 생성 → **라우터에 등록** → 구성 규칙은 [`lib/features/README.md`](lib/features/README.md) |
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
① 업로드          → 작업 식별자를 받는다
② 진행 상황 구독   → 단계 이벤트를 받는다
③ 완료 수신        → 결과를 따로 조회하고 결과 화면으로 이동
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

빌드 도구 버전이 특정 조합으로 고정돼 있다. 일부 플러그인이 오래된 언어 버전을 선언해
최신 툴체인과 충돌하기 때문이다. 동작이 확인된 조합은 네이티브 빌드 설정 파일에 있다.

빌드가 설명되지 않는 이유로 실패하면 캐시를 지우고 의존성을 다시 받는 것부터 시도한다.

---

## 결정 이유

저장소 전체에 걸친 선택과 근거. 계층별 판단은 각 모듈 문서가 갖는다.

**진입점을 환경별로 나눴다.** 어느 환경으로 빌드하는지가 진입점에서 결정되므로,
릴리스 빌드가 개발 설정을 물고 나가는 사고를 구조적으로 막는다.
대가는 **진입점마다 초기화를 중복해서 넣어야 한다**는 것이고, 이것이 실제 함정이 된다 — [`CLAUDE.md`](CLAUDE.md) 참조.

**빌드 도구 버전을 고정했다.** 일부 플러그인이 오래된 언어 버전을 선언해 최신 툴체인과 충돌한다.
플러그인들이 따라올 때까지 유지해야 하며, 올리려면 충돌하는 플러그인을 먼저 확인한다.

**공통 위젯 자리를 비워 뒀다.** 화면 사이에 재사용이 생기기 전에 미리 추상화하지 않기로 했다.
화면 전용 위젯은 그 화면 폴더 아래 둔다.

---

## 문서 지도

| 알고 싶은 것 | 문서 |
|-------------|------|
| 공통 인프라 (ApiClient·FCM·토큰·로거) | [`lib/core/README.md`](lib/core/README.md) |
| 화면별 구조·Riverpod 패턴·FCM 흐름·모델 타입 | [`lib/features/README.md`](lib/features/README.md) |
| 환경 변수 목록·발급처 | [`dart_defines/README.md`](dart_defines/README.md) |
| AI 작업 지침 | [`CLAUDE.md`](CLAUDE.md) |
