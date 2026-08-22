# SafeHome App

등기부등본 AI 분석 서비스의 **Flutter 모바일 앱** (Android / iOS).
카카오 로그인 → PDF 업로드 → SSE로 분석 진행 구독 → 결과 확인 → 분석 이력 관리.

> **범위**: `project-safehome-app/**`
> **연관**: [루트 README](../README.md) (App→API 계약) · [API README](../project-safehome-api/README.md)
> **검증**: 라우트는 `lib/app.dart`, API 호출은 `lib/core/services/api_client.dart`와 대조

---

## TL;DR

| 항목 | 값 |
|------|-----|
| 스택 | Flutter / Dart SDK `^3.7.2` |
| 상태 관리 | `flutter_riverpod` ^2.6.1 (Notifier 계열) |
| 라우팅 | `go_router` ^14.0.0 — 초기 경로 `/splash` |
| HTTP | `http` ^1.2.2 (SSE 스트리밍 직접 파싱) |
| 모델 | `freezed` + `json_serializable` → **수정 후 코드 생성 필수** |
| 인증 / 저장 | `kakao_flutter_sdk_user`, `flutter_secure_storage`, `shared_preferences` |
| 푸시 | `firebase_messaging` + `flutter_local_notifications` |
| 진입점 | `lib/main.dart` (dev) · `lib/main_prd.dart` (prd) → `lib/app.dart` |

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # 모델 변경 시 필수

./scripts/local.ps1     # 로컬 API 대상   (dart_defines/local.json)
./scripts/dev.ps1       # 개발 서버 대상  (dart_defines/dev.json)
./scripts/prd.ps1       # 운영           (main_prd.dart + prd.json)

flutter analyze
flutter clean && flutter pub get    # 빌드 오류 시
```

> **`--dart-define-from-file` 없이 실행하면 카카오 키가 빈 문자열로 컴파일되어 로그인이 동작하지 않는다.** 스크립트를 쓰는 이유다.

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

| 하려는 일 | 건드릴 파일 (순서대로) |
|-----------|----------------------|
| **화면 추가** | `lib/features/{name}/{name}_screen.dart` + `{name}_notifier.dart` → `lib/app.dart` 라우트 등록 → [`lib/features/README.md`](lib/features/README.md) |
| **API 필드 추가** | `lib/models/deed.dart` → **`build_runner` 재실행** → `lib/core/services/api_client.dart` → 사용 화면 |
| **새 API 호출 추가** | `api_client.dart`에 메서드 → 해당 Notifier → [`lib/core/README.md`](lib/core/README.md) API 표 |
| **에러 처리 추가** | `lib/core/errors/app_exceptions.dart` → 호출부 |
| **테마·색상 변경** | `lib/core/constants/app_colors.dart` → `app_theme.dart` |
| **푸시 동작 변경** | `lib/core/services/fcm_service.dart` → `lib/app.dart` `initState` 등록부 |

참조 구현은 `features/upload/` (Notifier + Screen 쌍의 표준 형태).

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

## 화면 / 라우트

| 라우트 | 화면 | 역할 |
|--------|------|------|
| `/splash` | `SplashScreen` | **초기 경로.** 토큰 유효성 검사 → `/` 또는 `/login` 분기 |
| `/login` | `LoginScreen` | 카카오 로그인 |
| `/onboarding` | `OnboardingScreen` | 최초 사용자 안내 |
| `/` | `HomeScreen` | 분석 시작 CTA + 설정(포그라운드 알림 토글) |
| `/upload` | `UploadScreen` | PDF 선택 + 임대차 유형(전세/월세) 선택 |
| `/analyzing/:jobId` | `AnalyzingScreen` | SSE 구독, 단계별 진행 표시 |
| `/result/:jobId` | `ResultScreen` | 안전 등급·체크리스트·권고사항 |
| `/my-page` | `MyPageScreen` | 분석 이력 목록, 로그아웃, 회원 탈퇴 |

전 화면 페이드 전환(`_fadePage`, 220ms). 화면별 상태 관리 상세 → [`lib/features/README.md`](lib/features/README.md)

---

## API 통신

엔드포인트 스펙은 [루트 README의 App→API 계약](../README.md#-app--api)이 원본이다. 클라이언트 구현은 `ApiClient` 하나에 모여 있다.

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

```bash
flutter build apk --debug   --dart-define-from-file=dart_defines/dev.json
flutter build apk --release -t lib/main_prd.dart --dart-define-from-file=dart_defines/prd.json
```

### Android 설정 (동작 확인된 조합)

| 항목 | 값 | 위치 |
|------|-----|------|
| Kotlin | `2.2.0` | `android/settings.gradle.kts` |
| NDK | `27.1.12297006` | `android/app/build.gradle.kts` |
| languageVersion 강제 | `1.9` | `android/build.gradle.kts` `allprojects` 블록 |
| 에뮬레이터 | `Pixel_6_API_36` | — |

`languageVersion 1.9` 강제는 `sentry_flutter` 등 구버전 플러그인이 languageVersion 1.6을 선언해 Kotlin 2.2.0과 충돌하기 때문이다. 지우면 빌드가 깨진다.

---

## 함정 & 결정 이유

| 함정 | 내용 |
|------|------|
| **`main_prd.dart` 초기화 누락** | `main.dart`와 달리 `Firebase.initializeApp()` / `FcmService.initialize()` / `KakaoSdk.init()`을 호출하지 않는다. 현재 운영 빌드에서 로그인·푸시가 동작하지 않는다 — 수정 필요 |
| **카카오 키를 두 곳에 넣어야 함** | dart-define과 `android/local.properties` 양쪽. Gradle이 리다이렉트 스킴을 만들 때 후자를 읽는다 |
| **`build_runner` 재실행** | `lib/models/deed.dart` 수정 후 실행하지 않으면 `.g.dart`가 옛 스키마라 파싱에서 조용히 깨진다 |
| **`result` 이중 파싱** | 서버가 `@JsonRawValue`로 내려주므로 `getJob()`에서 String이면 한 번 더 `jsonDecode`한다 |
| **`AppLogger` context는 named** | `AppLogger.info(tag, msg, context: {...})`. positional로 넘기면 컴파일 에러 |
| **SSE는 직접 파싱** | 전용 패키지 없이 `http.Client.send()` → `utf8.decoder` → `data:` 라인 추출. 청크가 줄 중간에서 끊길 수 있어 버퍼로 마지막 조각을 이월한다 |
| **`--dart-define-from-file` 누락** | 빌드는 성공하고 로그인만 실패한다. 원인 파악이 어려우니 스크립트를 쓸 것 |
| **`lib/widgets/`는 비어 있음** | 공통 위젯 자리로 만들어 뒀다. 화면 전용 위젯은 `features/{name}/widgets/`에 둔다 |

---

## 문서 지도

| 알고 싶은 것 | 문서 |
|-------------|------|
| 공통 인프라 (ApiClient·FCM·토큰·로거) | [`lib/core/README.md`](lib/core/README.md) |
| 화면별 구조·Riverpod 패턴·FCM 흐름·모델 타입 | [`lib/features/README.md`](lib/features/README.md) |
| 환경 변수 목록·발급처 | [`dart_defines/README.md`](dart_defines/README.md) |
| AI 작업 지침 | [`CLAUDE.md`](CLAUDE.md) |
