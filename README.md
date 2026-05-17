# SafeHome App (Flutter)

등기부등본 AI 분석 모바일 앱 — React Native에서 Flutter로 전환된 프로젝트입니다.

## 기술 스택

| 항목 | 기술 |
|------|------|
| 언어 | Dart 3.7+ |
| 프레임워크 | Flutter 3.29+ |
| 상태 관리 | flutter_riverpod |
| 라우팅 | go_router |
| HTTP | http (SSE 스트리밍 포함) |
| 파일 선택 | file_picker |
| 모델 코드 생성 | freezed + json_serializable |
| 에러 트래킹 | sentry_flutter |
| 플랫폼 | Android, iOS |

## 서비스 의존성

이 앱은 아래 서비스가 함께 실행되어야 합니다.

```
[App] Flutter
  ↓  POST /api/deed/analyze (multipart + SSE)
[API] Spring Boot  (http://localhost:8080)
  ↓  POST /api/deed/analyze
[AI API] Flask     (http://localhost:5000)
```

---

## 개발 환경 설정 (최초 1회)

### 1. 의존성 설치

```bash
flutter pub get
```

### 2. freezed 코드 생성

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 3. 환경 변수 파일 설정 (**필수**)

카카오 로그인 등 핵심 기능이 환경 변수에 의존합니다. **이 파일 없이 실행하면 카카오 SDK 초기화가 실패합니다.**

```bash
# 템플릿 복사
cp dart_defines/dev.json.example dart_defines/dev.json
```

`dart_defines/dev.json`을 열어 값을 채워주세요.

```json
{
  "KAKAO_NATIVE_APP_KEY": "카카오 디벨로퍼스 Native 앱 키",
  "SENTRY_DSN": "",
  "API_URL": ""
}
```

> `dart_defines/dev.json`은 `.gitignore`에 포함되어 있어 커밋되지 않습니다.

### 4. Android `local.properties` 설정 (**필수**)

카카오 OAuth 리다이렉트 스킴은 Gradle이 `local.properties`에서 직접 읽습니다.  
`dart_defines/dev.json`과 **동일한 값**을 아래에도 추가해야 합니다.

`android/local.properties`:
```
kakaoNativeAppKey=카카오_네이티브_앱_키
```

---

## 실행

> **주의**: `flutter run` / `flutter build` 시 반드시 `--dart-define-from-file` 옵션을 붙여야 합니다.  
> 이 옵션이 없으면 카카오 키가 빈 문자열로 컴파일되어 로그인이 동작하지 않습니다.

### Android 에뮬레이터

```bash
# 사용 가능한 에뮬레이터 목록 확인
flutter emulators

# 에뮬레이터 실행 (부팅까지 약 30초~1분 소요)
flutter emulators --launch Pixel_6_API_36

# 에뮬레이터 부팅 완료 후 앱 실행
flutter run --dart-define-from-file=dart_defines/dev.json
```

> Android 에뮬레이터는 API URL이 자동으로 `http://10.0.2.2:8080` 으로 설정됩니다.

> **처음 에뮬레이터 연결 시**: 에뮬레이터 화면에 "USB 디버깅 허용" 다이얼로그가 뜨면 "항상 허용" 체크 후 "허용" 탭

### 실제 기기 (Android / iOS)

```bash
# 연결된 기기 확인
flutter devices

# 앱 실행 (API 서버 IP 직접 지정 필요)
flutter run --dart-define-from-file=dart_defines/dev.json \
            --dart-define=API_URL=http://<서버IP>:8080
```

### 개발 서버 사용

```bash
flutter run --dart-define-from-file=dart_defines/dev.json \
            --dart-define=API_URL=http://devupii.store:38080
```

### VS Code 설정 (권장)

매번 옵션을 타이핑하지 않으려면 `.vscode/launch.json`에 등록해두세요.

```json
{
  "configurations": [
    {
      "name": "dev",
      "request": "launch",
      "type": "dart",
      "args": ["--dart-define-from-file=dart_defines/dev.json"]
    }
  ]
}
```

---

## 빌드

```bash
# 디버그 APK (dev)
flutter build apk --debug --dart-define-from-file=dart_defines/dev.json

# 릴리즈 APK (prd)
flutter build apk --release -t lib/main_prd.dart --dart-define-from-file=dart_defines/prd.json

# 정적 분석
flutter analyze
```

---

## 환경 변수

환경 변수는 `dart_defines/dev.json` (또는 `prd.json`) 파일로 관리됩니다.  
`--dart-define-from-file` 옵션으로 주입되며, 런타임이 아닌 **컴파일 타임**에 결정됩니다.

| 변수 | 필수 | 설명 |
|------|------|------|
| `KAKAO_NATIVE_APP_KEY` | **필수** | 카카오 디벨로퍼스 Native 앱 키 — 미설정 시 로그인 불가 |
| `API_URL` | 선택 | 백엔드 API URL (미설정 시 자동 감지: Android 에뮬레이터 `10.0.2.2:8080`, 기타 `localhost:8080`) |
| `SENTRY_DSN` | 선택 | Sentry DSN (미설정 시 에러 트래킹 비활성화) |

---

## 화면 구성

| 화면 | 경로 | 설명 |
|------|------|------|
| 홈 | `/` | 서비스 소개 및 분석 시작 |
| 업로드 | `/upload` | PDF 파일 선택 + 임대 유형 선택 |
| 분석 중 | `/analyzing/:jobId` | AI 분석 진행 중 (펄스 애니메이션 + 폴링) |
| 결과 | `/result/:jobId` | 종합 분석 결과 표시 |

---

## 프로젝트 구조

```
lib/
├── main.dart              # 진입점
├── app.dart               # 앱 + 라우터
├── core/                  # 공통 인프라 (색상, 테마, API, 에러)
├── models/deed.dart       # 등기부등본 도메인 모델 (freezed)
├── features/              # 화면별 Notifier + Screen
└── widgets/               # 공통 위젯
```

자세한 아키텍처 가이드는 [CLAUDE.md](./CLAUDE.md)를 참조하세요.
