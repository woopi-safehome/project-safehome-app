# core — 공통 인프라 계층

앱 전체에서 공유되는 설정, 상수, 에러, 서비스 모듈.
기능 화면(`features/`)에서 직접 의존하며, `core` 내부 모듈 간 상호 의존은 최소화한다.

> **범위**: `lib/core/**`
> **상위**: [App README](../../README.md) · **연관**: [`lib/features/README.md`](../features/README.md)
> **검증**: 파일 목록은 이 디렉토리와 1:1, API 메서드는 `api_client.dart`와 대조

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
    ├── api_client.dart        # 모든 API 호출 (SSE·업로드 포함) + apiClientProvider
    ├── auth_repository.dart   # 앱 시작 시 토큰 유효성 체크 및 자동 갱신
    ├── token_storage.dart     # flutter_secure_storage JWT 저장소
    ├── fcm_service.dart       # FCM 초기화·권한 요청·토큰 발급·포그라운드 알림
    └── logger.dart            # AppLogger (Sentry breadcrumb 연동)
```

> HTTP 클라이언트는 **`http` 패키지 하나만** 쓴다. SSE 스트리밍과 멀티파트 업로드를 같은 방식으로
> 다루기 위해서다. Dio·인터셉터 기반 자동 재시도 계층은 없다 — 401 처리는 `AuthRepository`가
> 앱 시작 시점에 한 번 수행한다.

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

`http` 패키지 기반. 앱의 **모든** API 호출이 이 클래스를 통한다.

| 메서드 | 설명 |
|--------|------|
| `login()` | `POST /api/auth/kakao` → `({accessToken, refreshToken, expiresIn, isNewUser})` |
| `registerDevice()` | `POST /api/users/devices` — FCM 토큰 등록 (upsert). **실패해도 예외를 던지지 않고 로그만 남긴다** |
| `uploadDeed()` | `POST /api/deed/upload` (multipart, `leaseType` 선택) → `jobId` |
| `streamJobEvents()` | `GET /api/deed/jobs/{jobId}/stream` → `Stream<SseEvent>` |
| `getJob()` | `GET /api/deed/jobs/{jobId}` → `DeedJob` |
| `getMyJobs()` | `GET /api/deed/jobs?page&size` → `DeedJobsPage` |
| `withdraw()` | `DELETE /api/users/me` — 회원 탈퇴 |

- 인증이 필요한 호출은 `_authHeaders()`가 `TokenStorage`에서 액세스 토큰을 읽어 `Authorization: Bearer`를 붙인다. 토큰이 없으면 헤더 없이 나간다.
- `getJob()`은 서버의 `@JsonRawValue` 때문에 `result`가 String으로 오는 경우 한 번 더 `jsonDecode`한다.
- `streamJobEvents()`는 SSE 전용 패키지 없이 직접 파싱한다. 청크가 줄 중간에서 끊길 수 있어 버퍼로 마지막 조각을 다음 청크로 이월한다.

**Provider**: `apiClientProvider` (이 파일에 정의)

### services/auth_repository.dart

앱 시작(`SplashScreen`) 시 저장된 토큰의 유효성을 확인하고 만료 시 `POST /api/auth/refresh`로 갱신한다.
정적 메서드만 있는 클래스로, 프로바이더를 거치지 않는다.

```dart
enum TokenCheckResult { authenticated, unauthenticated, networkError }
final result = await AuthRepository.checkAndRefresh();
```

분기 자체는 `SplashNotifier`가 한다 — `authenticated` → `/`, 그 외 → `/login`.
`networkError`를 별도 값으로 두는 이유는, 서버가 잠깐 죽었을 때 로그인 상태를 지우지 않기 위해서다.

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
