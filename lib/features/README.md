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
│       ├── auth_repository.dart   # 앱 시작 시 토큰 유효성 체크 + 갱신
│       ├── fcm_service.dart       # FCM 초기화, 토큰 발급, 알림 탭 핸들러
│       ├── token_storage.dart     # flutter_secure_storage JWT 저장
│       └── logger.dart            # Sentry breadcrumb 연동 로거
├── models/
│   └── deed.dart                  # freezed 도메인 모델 (SseEvent, DeedJob 등)
└── features/
    ├── splash/                    # 앱 시작 시 토큰 체크 → home/login 분기
    ├── login/                     # 카카오 로그인
    ├── onboarding/                # 온보딩
    ├── home/                      # 메인 화면 (업로드 CTA)
    ├── upload/                    # PDF 파일 선택 + 업로드
    ├── analyzing/                 # SSE 구독 + 분석 진행 화면
    ├── result/                    # 분석 결과 화면
    │   └── widgets/
    │       └── checklist_row.dart # 안전 체크리스트 행
    └── my_page/                   # 분석 이력 목록 + 계정 관리
        ├── account_notifier.dart  # 로그아웃 / 회원탈퇴 상태 관리
        └── widgets/
            └── safety_badge.dart  # SAFE/CAUTION/DANGER 배지
```

## 라우팅

```
/splash           → SplashScreen   (토큰 체크 → home/login 분기)
/login            → LoginScreen
/onboarding       → OnboardingScreen
/                 → HomeScreen
/upload           → UploadScreen
/analyzing/:jobId → AnalyzingScreen
/result/:jobId    → ResultScreen
/my-page          → MyPageScreen
```

## API 통신 흐름

`ApiClient` (http 패키지) 하나로 모든 API 통신을 담당한다.

| 메서드 | 엔드포인트 | 설명 |
|--------|-----------|------|
| `login()` | `POST /api/auth/kakao` | 카카오 액세스 토큰 → JWT 발급 |
| `registerDevice()` | `POST /api/users/devices` | FCM 토큰 서버 등록 (upsert) |
| `uploadDeed()` | `POST /api/deed/upload` | PDF 업로드 → jobId 반환 |
| `streamJobEvents()` | `GET /api/deed/jobs/{jobId}/stream` | SSE → `Stream<SseEvent>` |
| `getJob()` | `GET /api/deed/jobs/{jobId}` | 분석 결과 조회 |
| `getMyJobs()` | `GET /api/deed/jobs` | 이력 목록 페이징 |
| `withdraw()` | `DELETE /api/users/me` | 회원탈퇴 |

```
① POST /api/deed/upload (multipart)
     → JSON { data: { jobId } } 수신
② GET  /api/deed/jobs/{jobId}/stream (SSE)
     → SseEvent 스트리밍
     → COMPLETED 수신 시 → ③
③ GET  /api/deed/jobs/{jobId}
     → DeedJob 전체 결과 fetch → Result 화면 이동
```

> `result` 필드는 `@JsonRawValue`로 String 직렬화되므로 `getJob()` 내부에서 이중 파싱 처리.

## FCM 푸시 알림 흐름

### 디바이스 등록
```
앱 시작 (SplashNotifier.checkAuth — 토큰 유효)
로그인 성공 (LoginNotifier.loginWithKakao)
  ↓ FcmService.getToken()
  ↓ ApiClient.registerDevice(fcmToken)
  → POST /api/users/devices → user_devices 테이블 upsert
```

### 분석 완료 알림
```
API 서버 분석 완료 (AnalysisAsyncProcessor — COMPLETED)
  ↓ user_devices에서 userId로 FCM 토큰 목록 조회
  ↓ POST http://pigeon/api/messages/send (토큰별 호출)
  ↓ project-pigeon → Firebase FCM 발송
  → 디바이스 시스템 알림 표시
```

### 알림 탭 처리
```
사용자가 알림 탭
  ↓ FcmService.setupNotificationHandlers (SafeHomeApp.initState에서 등록)
  ├── 앱 종료 상태: getInitialMessage()
  └── 앱 백그라운드: onMessageOpenedApp
  ↓ message.data['jobId'] 추출
  → router.go('/result/:jobId')
```

## Riverpod 패턴

| Notifier 유형 | 사용 기준 | 예시 |
|--------------|----------|------|
| `Notifier` | 앱 생명주기 동안 유지 | LoginNotifier, AccountNotifier |
| `AutoDisposeNotifier` | 화면 이탈 시 자동 해제 | UploadNotifier, MyPageNotifier |
| `FamilyNotifier<State, String>` | jobId 파라미터 필요 | AnalyzingNotifier, ResultNotifier |

## AnalyzingNotifier 동작

1. `_startSse(jobId)` — SSE 구독 시작, 초기 표시 단계: `pdfParsing`
2. SSE 이벤트 수신 → `_scheduleStep()` (최소 1.5초 표시 게이트, 큐 기반)
3. `COMPLETED` 수신 → `getJob()` 호출 → `state.job` 세팅 → `completed: true`
4. `FAILED` / 스트림 비정상 종료 → `errorMessage` 세팅
5. `retry()` — 상태 초기화 후 SSE 재구독

## 도메인 모델 주요 타입 (lib/models/deed.dart)

```dart
enum SafetyLevel     { safe, caution, danger }
enum JobStatus       { pending, inProgress, completed, failed }
enum AnalysisStep    { pdfParsing, llmAnalysis, postProcessing }
enum ChecklistStatus { good, caution, danger, unknown }
enum LeaseType       { jeonse, wolse }

class SseEvent    { jobId, status, step, message, timestamp }
class DeedJob     { jobId, status, fileName, fileSize, step, result }
class DeedAnalysis { isValidDeed, safetyLevel, propertyInfo, checklist, ... }
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
