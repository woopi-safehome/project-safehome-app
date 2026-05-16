# CLAUDE.md — project-safehome-app (Flutter)

## 기술 스택

| 항목 | 기술 |
|------|------|
| 언어 | Dart 3.7+ |
| 프레임워크 | Flutter 3.29+ |
| 상태 관리 | flutter_riverpod (Notifier / FamilyNotifier) |
| 라우팅 | go_router |
| HTTP | http (SSE 스트리밍 포함), dio (인증 인터셉터) |
| 인증 | kakao_flutter_sdk_user, flutter_secure_storage |
| 파일 선택 | file_picker |
| 모델 코드 생성 | freezed + json_serializable |
| 에러 트래킹 | sentry_flutter |
| 플랫폼 | Android, iOS |

## 디렉토리 구조

```
lib/
├── main.dart                      # dev 진입점: AppFlavor.dev + Sentry(debug=true)
├── main_prd.dart                  # prd 진입점: AppFlavor.prd + Sentry
├── app.dart                       # SafeHomeApp + GoRouter 설정
├── core/
│   ├── config/
│   │   └── app_config.dart        # AppFlavor(dev/prd), sentryDsn, tracesSampleRate
│   ├── constants/
│   │   ├── app_colors.dart        # 색상 상수 (primary, safe/caution/danger 등)
│   │   └── app_theme.dart         # ThemeData (light/dark)
│   ├── errors/
│   │   └── app_exceptions.dart    # NetworkException, ApiException, ParseException
│   └── services/
│       ├── api_client.dart        # uploadDeed() + getJob() API 호출
│       └── logger.dart            # Sentry breadcrumb 연동 로거
├── models/
│   └── deed.dart                  # freezed 도메인 모델 (DeedJob, DeedAnalysis 등)
├── features/
│   ├── home/
│   │   └── home_screen.dart
│   ├── upload/
│   │   ├── upload_notifier.dart   # 파일 선택, 업로드 상태 관리
│   │   └── upload_screen.dart
│   ├── analyzing/
│   │   ├── analyzing_notifier.dart  # 2초 폴링, Timer.periodic
│   │   └── analyzing_screen.dart   # 펄스 애니메이션 + 상태 메시지
│   └── result/
│       ├── result_notifier.dart
│       └── result_screen.dart      # 스크롤 결과 화면 (모든 분석 섹션)
└── widgets/
    ├── safety_badge.dart           # SAFE/CAUTION/DANGER 배지
    ├── card_section.dart           # 카드 섹션 공통 레이아웃
    ├── info_row.dart               # 레이블-값 행
    ├── checklist_row.dart          # 체크리스트 항목 (상태 배지)
    └── lease_check_item_row.dart   # 임대 분석 항목 (우선순위 배지)
```

## 라우팅 구조

```
/               → HomeScreen
/upload         → UploadScreen
/analyzing/:jobId → AnalyzingScreen
/result/:jobId  → ResultScreen
```

## 빌드 및 실행 명령어

```bash
# 의존성 설치
flutter pub get

# 코드 생성 (freezed 모델 변경 시 필수)
dart run build_runner build --delete-conflicting-outputs

# 에뮬레이터 실행
flutter emulators --launch Pixel_6_API_36

# ── dev 환경 ──────────────────────────────────────────────────
# 개발 실행 (dart_defines/dev.json 사용 권장)
flutter run --dart-define-from-file=dart_defines/dev.json

# API 서버 URL 추가 지정 시
flutter run --dart-define-from-file=dart_defines/dev.json \
            --dart-define=API_URL=http://devupii.store:38080

# dev APK 빌드
flutter build apk --debug \
  --dart-define-from-file=dart_defines/dev.json

# ── prd 환경 ──────────────────────────────────────────────────
# prd 실행 (진입점: main_prd.dart = AppFlavor.prd)
flutter run -t lib/main_prd.dart \
  --dart-define-from-file=dart_defines/prd.json

# prd APK 빌드
flutter build apk --release \
  -t lib/main_prd.dart \
  --dart-define-from-file=dart_defines/prd.json

# ── 공통 ──────────────────────────────────────────────────────
# 정적 분석
flutter analyze

# 빌드 캐시 초기화 (빌드 오류 시)
flutter clean && flutter pub get
```

## Android 빌드 설정

- Kotlin 버전: `2.2.0` (`android/settings.gradle.kts`)
- NDK 버전: `27.1.12297006` (`android/app/build.gradle.kts`)
- 에뮬레이터: `Pixel_6_API_36` (API 36, x86_64)

> **Kotlin 버전 주의사항**: 플러그인(sentry_flutter 등)이 languageVersion 1.6을 사용하므로,
> `android/build.gradle.kts`에 `allprojects` 블록으로 최소 languageVersion을 1.9로 강제 설정함.
> Kotlin 버전을 변경할 때는 이 설정도 함께 확인할 것.

## 환경 변수

### dart_defines/dev.json (--dart-define-from-file, Git 제외)

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `KAKAO_NATIVE_APP_KEY` | — | **필수** — 카카오 디벨로퍼스 Native 앱 키 |
| `SENTRY_DSN` | 빈 문자열 | 미설정 시 Sentry 비활성화 |
| `API_URL` | 자동 감지 | Android 에뮬레이터: `10.0.2.2:8080`, 기타: `localhost:8080` |

템플릿: `dart_defines/dev.json.example` 참고

### android/local.properties (Git 제외)

| 키 | 설명 |
|----|------|
| `kakaoNativeAppKey` | AndroidManifest OAuth 스킴 주입용 (dart_defines와 동일한 값) |

> `APP_ENV` 는 더 이상 사용하지 않음. 환경은 진입점(`main.dart` / `main_prd.dart`)으로 결정됨.

## 환경별 동작 차이

| 항목 | dev (`main.dart`) | prd (`main_prd.dart`) |
|------|-------------------|----------------------|
| `AppFlavor` | `dev` | `prd` |
| Sentry `environment` | `"dev"` | `"prd"` |
| `tracesSampleRate` | `1.0` (전체 트레이싱) | `0.1` (10% 샘플링) |
| `options.debug` | `true` (Sentry 로그 출력) | `false` |
| `AppLogger.info` 출력 | 항상 출력 | release 빌드 시 출력 안 함 |

## 아키텍처 패턴

### Riverpod 상태 관리
- `Notifier` (단순 상태): `UploadNotifier`
- `FamilyNotifier` (파라미터 있는 상태): `AnalyzingNotifier(jobId)`, `ResultNotifier(jobId)`
- `Provider` (단순 의존성): `apiClientProvider`

### API 통신
- **업로드**: `POST /api/deed/analyze` (multipart) → SSE 스트림에서 `jobId` 추출
- **폴링**: `GET /api/deed/jobs/{jobId}` 2초 간격 반복 → COMPLETED 시 Result 화면 이동
- Spring Boot의 `@JsonRawValue` result 필드 처리: `api_client.dart`에서 이중 파싱

### 코드 생성
- `lib/models/deed.dart` 수정 후 반드시 `build_runner` 재실행
- 생성 파일: `deed.freezed.dart`, `deed.g.dart` (git에 포함)

## 도메인 모델 주요 타입

```dart
enum SafetyLevel { safe, caution, danger }
enum JobStatus { pending, inProgress, completed, failed }
enum AnalysisStep { pdfParsing, llmAnalysis, postProcessing }
enum ChecklistStatus { good, caution, danger, unknown }
enum LeaseType { jeonse, wolse }

class DeedJob { jobId, status, fileName, fileSize, step, result }
class DeedAnalysis { isValidDeed, safetyLevel, propertyInfo, ownershipInfo, ... }
```

## 서비스 의존성

- Spring Boot API: `http://localhost:8080` (또는 `--dart-define=API_URL=...`)
- AI API (Flask): API 서버를 통해 간접 호출 (앱에서 직접 호출 없음)
