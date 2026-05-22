# App 기능 상세

## 디렉토리 구조

```
lib/
├── core/
│   ├── config/
│   │   └── app_config.dart        # AppFlavor, apiBaseUrl (중앙화된 baseUrl)
│   ├── constants/
│   │   ├── app_colors.dart
│   │   └── app_theme.dart
│   ├── errors/
│   │   └── app_exceptions.dart    # NetworkException, ApiException, ParseException
│   └── services/
│       ├── api_client.dart        # 모든 API 호출 + apiClientProvider
│       ├── dio_client.dart        # Dio + 401 자동 갱신 인터셉터 + dioClientProvider
│       ├── auth_repository.dart   # 앱 시작 시 토큰 유효성 체크 + 갱신
│       ├── token_storage.dart     # flutter_secure_storage JWT 저장
│       └── logger.dart            # Sentry breadcrumb 연동 로거
├── models/
│   └── deed.dart                  # freezed 도메인 모델 (SseEvent, DeedJob 등)
└── features/
    ├── splash/                    # 앱 시작 시 토큰 체크 → home/login 분기
    ├── login/                     # 카카오 로그인
    ├── onboarding/                # 온보딩
    ├── home/                      # 메인 화면 (업로드 CTA, 로그아웃/탈퇴 메뉴)
    ├── upload/                    # PDF 파일 선택 + 업로드
    ├── analyzing/                 # SSE 구독 + 분석 진행 화면
    ├── result/                    # 분석 결과 화면
    │   └── widgets/
    │       └── checklist_row.dart # 안전 체크리스트 행 (result 전용)
    └── my_page/                   # 분석 이력 목록
        ├── account_notifier.dart  # 로그아웃 / 회원탈퇴 상태 관리
        └── widgets/
            └── safety_badge.dart  # SAFE/CAUTION/DANGER 배지 (my_page 전용)
```

## 라우팅

```
/splash         → SplashScreen   (토큰 체크 → home/login 분기)
/login          → LoginScreen
/onboarding     → OnboardingScreen
/               → HomeScreen
/upload         → UploadScreen
/analyzing/:jobId → AnalyzingScreen
/result/:jobId  → ResultScreen
/my-page        → MyPageScreen
```

## HTTP 클라이언트 분리

| 클라이언트 | 용도 | 인증 처리 |
|-----------|------|----------|
| `ApiClient` (http 패키지) | SSE 스트리밍, 파일 업로드, 로그인 | 수동 Authorization 헤더 |
| `Dio` (dio_client.dart) | 일반 인증 REST 호출 (회원탈퇴 등) | `_AuthInterceptor` 자동 401 갱신 |

- **baseUrl**: `AppConfig.apiBaseUrl` 한 곳에서 관리
- **`apiClientProvider`**: `core/services/api_client.dart`에 정의

## API 통신 흐름

```
① POST /api/deed/upload (multipart)
     → JSON { data: { jobId } } 수신
② GET  /api/deed/jobs/{jobId}/stream (SSE)
     → SseEvent 스트리밍
     → COMPLETED 수신 시 → ③
③ GET  /api/deed/jobs/{jobId}
     → DeedJob 전체 결과 fetch → Result 화면 이동
```

- `login()`: `POST /api/auth/kakao` → Dart record 반환 (accessToken, refreshToken, expiresIn, isNewUser)
- `uploadDeed()`: `POST /api/deed/upload` → jobId 반환
- `streamJobEvents()`: `GET /jobs/{jobId}/stream` → `Stream<SseEvent>`
- `getJob()`: `GET /jobs/{jobId}` → `DeedJob` (result 필드 이중 파싱 처리)
- `getMyJobs()`: `GET /jobs` → `DeedJobsPage`

## Riverpod 패턴

- `Notifier` — `LoginNotifier`, `AccountNotifier`
- `AutoDisposeNotifier` — `UploadNotifier`, `MyPageNotifier`
- `FamilyNotifier` — `AnalyzingNotifier(jobId)`, `ResultNotifier(jobId)`
- `Provider` — `apiClientProvider` (api_client.dart), `dioClientProvider` (dio_client.dart)

## AnalyzingNotifier 동작

1. `_startSse(jobId)` — SSE 구독 시작
2. SSE 이벤트 수신 → `_scheduleStep()` (최소 1.5초 표시 게이트)
3. `COMPLETED` 수신 → `getJob()` 호출 → `state.job` 세팅 → `completed: true`
4. `FAILED` / 스트림 비정상 종료 → errorMessage 세팅
5. `retry()` — SSE 재구독

## 도메인 모델 주요 타입 (lib/models/deed.dart)

```dart
enum SafetyLevel    { safe, caution, danger }
enum JobStatus      { pending, inProgress, completed, failed }
enum AnalysisStep   { pdfParsing, llmAnalysis, postProcessing }
enum ChecklistStatus { good, caution, danger, unknown }
enum LeaseType      { jeonse, wolse }

class SseEvent  { jobId, status, step, message, timestamp }
class DeedJob   { jobId, status, fileName, fileSize, step, result }
class DeedAnalysis { isValidDeed, safetyLevel, propertyInfo, ... }
```

모델 수정 후 반드시 코드 생성:
```bash
dart run build_runner build --delete-conflicting-outputs
```

## Android 빌드 설정

- Kotlin: `2.2.0` (android/settings.gradle.kts)
- NDK: `27.1.12297006` (android/app/build.gradle.kts)
- 에뮬레이터: `Pixel_6_API_36`
- sentry_flutter 등 구버전 플러그인 호환: `android/build.gradle.kts` allprojects 블록에 languageVersion 1.9 강제 설정
- 빌드 오류 시: `flutter clean && flutter pub get`
