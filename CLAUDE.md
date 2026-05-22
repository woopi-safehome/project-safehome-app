# CLAUDE.md — project-safehome-app (Flutter)

## 빌드 & 실행

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs  # 모델 변경 시 필수

# dev 실행
flutter emulators --launch Pixel_6_API_36
flutter run --dart-define-from-file=dart_defines/dev.json

# prd 실행
flutter run -t lib/main_prd.dart --dart-define-from-file=dart_defines/prd.json

# 정적 분석
flutter analyze

# 빌드 캐시 초기화
flutter clean && flutter pub get
```

## 기술 스택

Flutter 3.29+ / Dart 3.7+, flutter_riverpod, go_router, http (SSE), freezed + json_serializable, sentry_flutter

## 핵심 규칙

- API base URL: `--dart-define=API_URL=...` / 기본값: `http://devupii.store:38080`
- 모델(`lib/models/deed.dart`) 수정 시 반드시 `build_runner` 재실행
- AppLogger 호출 시 context는 named 인수 필수: `context: {...}`

## 상세 문서

→ `lib/features/readme.md` — 기능별 구조, API 통신 흐름, 모델 타입, Android 빌드 설정
