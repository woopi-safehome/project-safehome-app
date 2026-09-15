#!/usr/bin/env bash
# 이 저장소의 검증. CI 가 이 파일을 그대로 실행한다.
# 끝났다고 말하기 전에도 이것을 돌린다 — 명령이 다르면 로컬 통과가 CI 통과를 뜻하지 않는다.
set -euo pipefail
cd "$(dirname "$0")/.."
flutter pub get
# 직렬화 모델의 생성물은 커밋하지 않는다. 만들어야 분석이 실제 스키마를 보고 검사한다.
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
