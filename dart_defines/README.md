# dart_defines — 환경 변수 설정

Flutter는 `.env` 대신 `--dart-define-from-file`로 빌드 타임 환경 변수를 주입한다.

## 파일 구조

```
dart_defines/
├── local.json          # 로컬 개발용 (gitignore — 실제 키 포함)
├── local.json.example  # 로컬 개발 템플릿 (커밋됨)
├── dev.json            # 개발 서버용 (gitignore — 실제 키 포함)
├── dev.json.example    # 개발 서버 템플릿 (커밋됨)
├── prd.json            # 운영 환경용 (gitignore — 실제 키 포함)
└── prd.json.example    # 운영 환경 템플릿 (커밋됨)
```

> `*.json`은 실제 시크릿을 포함하므로 `.gitignore`에 등록되어 있다. `*.json.example`만 커밋된다.

## 환경별 API URL

| 환경 | `API_URL` | 설명 |
|------|-----------|------|
| `local` | `http://10.0.2.2:8080` | 에뮬레이터에서 호스트 localhost:8080 접근 |
| `dev` | `http://devupii.store:38080` | 개발 서버 |
| `prd` | `https://api.safehome.com` | 운영 서버 (배포 전 교체 필요) |

> `10.0.2.2`는 Android 에뮬레이터에서 호스트 머신의 localhost를 가리키는 주소다.
> dart-define 미주입 시 `AppConfig.apiBaseUrl`이 `http://10.0.2.2:8080`으로 폴백한다.

## 환경 변수 목록

| 변수명 | 설명 |
|--------|------|
| `API_URL` | API 서버 base URL |
| `KAKAO_NATIVE_APP_KEY` | 카카오 로그인 네이티브 앱 키 |
| `SENTRY_DSN` | Sentry 오류 추적 DSN (없으면 Sentry 비활성) |

## 초기 설정 방법

```bash
# 로컬 개발
cp dart_defines/local.json.example dart_defines/local.json
# local.json 열어서 KAKAO_NATIVE_APP_KEY 입력

# 개발 서버
cp dart_defines/dev.json.example dart_defines/dev.json
# dev.json 열어서 키 값 입력
```

## 실행 명령

```bash
# 로컬 (로컬 Spring Boot 서버 대상)
flutter run --dart-define-from-file=dart_defines/local.json

# 개발 서버
flutter run --dart-define-from-file=dart_defines/dev.json

# 운영
flutter run -t lib/main_prd.dart --dart-define-from-file=dart_defines/prd.json
```

## 키 발급처

| 변수 | 발급처 |
|------|-------|
| `KAKAO_NATIVE_APP_KEY` | [Kakao Developers](https://developers.kakao.com) → 앱 → 앱 키 → 네이티브 앱 키 |
| `SENTRY_DSN` | [Sentry](https://sentry.io) → 프로젝트 → Settings → Client Keys (DSN) |
