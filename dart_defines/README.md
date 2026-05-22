# dart_defines — 환경 변수 설정

Flutter는 `.env` 대신 `--dart-define-from-file`로 빌드 타임 환경 변수를 주입한다.

## 파일 구조

```
dart_defines/
├── dev.json          # 개발 환경 (gitignore — 실제 키 포함)
├── dev.json.example  # 개발 환경 템플릿 (커밋됨)
├── prd.json          # 운영 환경 (gitignore — 실제 키 포함)
└── prd.json.example  # 운영 환경 템플릿 (커밋됨)
```

> `dev.json`, `prd.json`은 실제 시크릿을 포함하므로 `.gitignore`에 등록되어 있다.

## 환경 변수 목록

| 변수명 | 설명 | dev 기본값 | prd |
|--------|------|-----------|-----|
| `API_URL` | API 서버 base URL | `http://10.0.2.2:8080` | `https://api.safehome.com` |
| `KAKAO_NATIVE_APP_KEY` | 카카오 로그인 네이티브 앱 키 | 발급 필요 | 발급 필요 |
| `SENTRY_DSN` | Sentry 오류 추적 DSN | 발급 필요 (없으면 Sentry 비활성) | 발급 필요 |

## 코드에서 읽는 방법

```dart
// lib/core/config/app_config.dart
static const _apiUrl = String.fromEnvironment('API_URL', defaultValue: '');
static const _sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');
```

미주입 시 `API_URL`은 `AppConfig.apiBaseUrl`의 하드코딩 기본값(`http://devupii.store:38080`)으로 폴백.

## 초기 설정 방법

```bash
cp dart_defines/dev.json.example dart_defines/dev.json
# dev.json 열어서 키 값 입력
```

## 실행 명령

```bash
# 개발
flutter run --dart-define-from-file=dart_defines/dev.json

# 운영
flutter run -t lib/main_prd.dart --dart-define-from-file=dart_defines/prd.json
```

## 키 발급처

| 변수 | 발급처 |
|------|-------|
| `KAKAO_NATIVE_APP_KEY` | [Kakao Developers](https://developers.kakao.com) → 앱 → 앱 키 → 네이티브 앱 키 |
| `SENTRY_DSN` | [Sentry](https://sentry.io) → 프로젝트 → Settings → Client Keys (DSN) |
| `API_URL` | 서버 배포 주소 (에뮬레이터는 `10.0.2.2`가 호스트 localhost) |
