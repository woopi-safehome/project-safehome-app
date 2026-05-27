# core — 공통 인프라 계층

앱 전체에서 공유되는 설정, 상수, 에러, 서비스 모듈.
기능 화면(`features/`)에서 직접 의존하며, `core` 내부 모듈 간 상호 의존은 최소화한다.

## 디렉토리 구조

```
lib/core/
├── config/
│   └── app_config.dart        # AppFlavor, apiBaseUrl, sentryDsn 중앙 관리
├── constants/
│   ├── app_colors.dart        # 브랜드 색상 팔레트
│   └── app_theme.dart         # ThemeData (Light/Dark)
├── errors/
│   └── app_exceptions.dart    # NetworkException, ApiException, ParseException
└── services/
    ├── api_client.dart        # HTTP 클라이언트 (SSE·업로드·로그인) + apiClientProvider
    ├── dio_client.dart        # Dio 클라이언트 (인증 REST) + dioClientProvider
    ├── auth_repository.dart   # 앱 시작 시 토큰 유효성 체크 및 자동 갱신
    ├── token_storage.dart     # flutter_secure_storage JWT 저장소
    ├── fcm_service.dart       # FCM 초기화·권한 요청·토큰 발급·포그라운드 알림
    └── logger.dart            # AppLogger (Sentry breadcrumb 연동)
```

## 모듈 상세

### config/app_config.dart

```dart
enum AppFlavor { dev, prd }

class AppConfig {
  static String get apiBaseUrl   // dart-define API_URL → 미설정 시 기본값
  final AppFlavor flavor
  final String sentryDsn
  final double tracesSampleRate  // prd: 0.1 / dev: 1.0
}
```

- `AppConfig.init(flavor)` — `main.dart`에서 Sentry 초기화 전 호출
- `AppConfig.instance` — 싱글톤 접근

### services/api_client.dart

`http` 패키지 기반. SSE 스트리밍·멀티파트 업로드·로그인처럼 Dio 인터셉터가 맞지 않는 케이스에 사용.

| 메서드 | 설명 |
|--------|------|
| `login()` | `POST /api/auth/kakao` → `({accessToken, refreshToken, expiresIn, isNewUser})` |
| `registerDevice()` | `POST /api/users/devices` — FCM 토큰 등록 (upsert). 실패 시 무시 |
| `uploadDeed()` | `POST /api/deed/upload` (multipart) → `jobId` |
| `streamJobEvents()` | `GET /api/deed/jobs/{jobId}/stream` → `Stream<SseEvent>` |
| `getJob()` | `GET /api/deed/jobs/{jobId}` → `DeedJob` |
| `getMyJobs()` | `GET /api/deed/jobs` → `DeedJobsPage` |

**Provider**: `apiClientProvider` (이 파일에 정의)

### services/dio_client.dart

Dio + `_AuthInterceptor` 기반. 401 응답 시 refresh token으로 자동 갱신 후 재시도.
회원탈퇴 등 일반 인증 REST 호출에 사용.

**Provider**: `dioClientProvider`

### services/auth_repository.dart

앱 시작(`SplashScreen`) 시 저장된 토큰의 유효성을 확인하고 만료 시 자동 갱신.
결과에 따라 `/home` 또는 `/login`으로 분기.

### services/token_storage.dart

`flutter_secure_storage`를 래핑. JWT access/refresh token CRUD.

```dart
await tokenStorage.saveTokens(accessToken, refreshToken);
final token = await tokenStorage.getAccessToken();
await tokenStorage.clearTokens();
```

### services/fcm_service.dart

Firebase Cloud Messaging 초기화·권한 요청·토큰 발급·포그라운드 알림·알림 탭 핸들러를 담당하는 정적 서비스.

| 메서드 | 설명 |
|--------|------|
| `initialize()` | 백그라운드 메시지 핸들러 등록 + 알림 권한 요청 + `flutter_local_notifications` 초기화 + Android 알림 채널 생성. `main()`에서 호출 |
| `getToken()` | FCM 디바이스 토큰 발급. 앱 시작/로그인 시 API 서버로 전송 |
| `setupTokenRefreshListener(onRefresh)` | Firebase 토큰 갱신 감지 → `onRefresh(token)` 콜백 실행. 인증 확인 후 `SplashNotifier`에서 호출. 기존 구독은 자동 교체 |
| `cancelTokenRefreshListener()` | 토큰 갱신 구독 해제. 로그아웃 시 `AccountNotifier`에서 호출 |
| `setupForegroundNotificationHandler({isEnabled})` | 포그라운드 상태에서 FCM 메시지 수신 시 `isEnabled()` 콜백이 true면 로컬 알림 표시. `SafeHomeApp.initState()`에서 설정 로드 후 호출 |
| `setupNotificationHandlers(router)` | 알림 탭 → `/result/:jobId` 라우팅 등록. `SafeHomeApp.initState()`에서 호출 |

**알림 탭 처리 흐름:**

```
앱 종료 상태  → getInitialMessage()   ─┐
앱 백그라운드 → onMessageOpenedApp    ─┤→ message.data['jobId'] → router.go('/result/:jobId')
```

**토큰 갱신 자동 재등록 흐름:**

```
Firebase가 새 토큰 발급 (앱 재설치·토큰 만료 등)
  → onTokenRefresh 스트림
  → setupTokenRefreshListener 콜백
  → ApiClient.registerDevice(새 토큰)
  → user_devices 업데이트
```

**포그라운드 알림 처리 흐름:**

```
앱 포그라운드 상태에서 FCM 메시지 수신
  → FirebaseMessaging.onMessage
  → isEnabled() 확인 (foregroundNotificationProvider)
  → true: flutter_local_notifications로 시스템 알림 표시
  → false: 무시
```

### services/logger.dart

```dart
AppLogger.info(tag, message, context: {'key': value});
AppLogger.error(tag, message, error: e);
```

- `context:` named 인수 필수 (positional 사용 금지)
- Sentry breadcrumb에 자동 기록

### errors/app_exceptions.dart

| 예외 | 발생 조건 |
|------|----------|
| `NetworkException` | 네트워크 연결 실패, timeout |
| `ApiException(statusCode)` | HTTP 4xx / 5xx 응답 |
| `ParseException` | JSON 파싱 실패 |
