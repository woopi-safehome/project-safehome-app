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

---

## 실행

### Android 에뮬레이터

```bash
# 사용 가능한 에뮬레이터 목록 확인
flutter emulators

# 에뮬레이터 실행 (부팅까지 약 30초~1분 소요)
flutter emulators --launch Pixel_6_API_36

# 에뮬레이터 부팅 완료 후 앱 실행
flutter run
```

> Android 에뮬레이터는 API URL이 자동으로 `http://10.0.2.2:8080` 으로 설정됩니다.

> **처음 에뮬레이터 연결 시**: 에뮬레이터 화면에 "USB 디버깅 허용" 다이얼로그가 뜨면 "항상 허용" 체크 후 "허용" 탭

### 실제 기기 (Android / iOS)

```bash
# 연결된 기기 확인
flutter devices

# 앱 실행 (API 서버 IP 직접 지정 필요)
flutter run --dart-define=API_URL=http://<서버IP>:8080
```

### 개발 서버 사용

```bash
flutter run --dart-define=API_URL=http://devupii.store:38080
```

---

## 빌드

```bash
# 디버그 APK
flutter build apk --debug

# 릴리즈 APK
flutter build apk --release

# 정적 분석
flutter analyze
```

---

## 환경 변수 (`--dart-define`)

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `API_URL` | 자동 감지 | 백엔드 API URL (Android 에뮬레이터: `10.0.2.2:8080`, 나머지: `localhost:8080`) |
| `SENTRY_DSN` | 빈 문자열 | Sentry DSN (미설정 시 비활성화) |
| `APP_ENV` | `dev` | Sentry 환경 레이블 |

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
