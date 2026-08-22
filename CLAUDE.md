# CLAUDE.md — project-safehome-app (Flutter)

**이 모듈 작업 시의 금지사항·필수 절차.**
스택·구조·실행 명령·라우트·함정 → [`README.md`](README.md)

---

## 시작 전

1. [루트 `README.md`](../README.md) — App→API 계약 (엔드포인트 스펙의 원본)
2. [`README.md`](README.md) — **작업 레시피** 표에서 건드릴 파일 순서 확인
3. `lib/core/README.md` · `lib/features/README.md`

## 필수 절차

- **`lib/models/deed.dart`를 고쳤으면 즉시 코드 생성한다.**
  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```
  빠뜨리면 `.g.dart`가 옛 스키마라 JSON 파싱에서 조용히 깨진다.
- **실행·빌드는 항상 `--dart-define-from-file`과 함께.** `scripts/{local,dev,prd}.ps1`을 쓴다. 빠뜨리면 빌드는 성공하고 카카오 로그인만 실패해 원인 파악이 어렵다.
- **카카오 키는 두 곳에 넣는다** — `dart_defines/*.json` + `android/local.properties`의 `kakaoNativeAppKey`. Gradle이 OAuth 리다이렉트 스킴을 만들 때 후자를 읽는다.
- **새 화면은 `{name}_screen.dart` + `{name}_notifier.dart` 쌍으로 만들고** `lib/app.dart`에 라우트를 등록한다. 참조 구현은 `features/upload/`.
- **API 호출은 `ApiClient`에만 추가한다.** 화면에서 `http`를 직접 부르지 않는다.
- 상태 수명에 맞는 Notifier를 고른다 — 앱 전역 `Notifier` / 화면 한정 `AutoDisposeNotifier` / jobId 파라미터 `FamilyNotifier`.

## 금지사항

- **`AppLogger`의 `context`를 positional로 넘기지 않는다.** `context: {...}` named 인수만 컴파일된다.
- **`android/build.gradle.kts`의 `languageVersion 1.9` 강제 설정을 지우지 않는다.** 구버전 플러그인(sentry_flutter 등)이 Kotlin 2.2.0과 충돌해 빌드가 깨진다.
- **생성 파일(`*.g.dart`, `*.freezed.dart`)을 직접 수정하지 않는다.**
- **`dart_defines/*.json`을 커밋하지 않는다.** 실제 키가 들어 있다. `*.json.example`만 커밋한다.
- 서버 응답 스펙을 App 쪽에서 임의로 가정하지 않는다. 루트 README의 계약을 확인한다.
