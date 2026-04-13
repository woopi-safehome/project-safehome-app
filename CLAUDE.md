# CLAUDE.md — project-safehome-app

This file provides guidance to Claude Code when working with this repository.

## Build & Run Commands

```bash
# 개발 서버 시작 (Expo Go / 시뮬레이터)
npm start

# Android 에뮬레이터 실행
npm run android

# iOS 시뮬레이터 실행 (macOS only)
npm run ios

# 웹 브라우저 실행
npm run web

# 린트 검사
npm run lint
```

## Tech Stack

React Native 0.81.5, Expo 54.0.31, Expo Router 6.0.21, TypeScript 5.9, React 19.1.0, React Navigation (bottom-tabs + native-stack), React Native Reanimated 4.1.1, React Native Gesture Handler

## Architecture

**Expo Router 파일 기반 라우팅.** `app/` 디렉토리 구조가 곧 URL/네비게이션 구조.

```
app/
├── _layout.tsx          # 루트 레이아웃 (Stack navigator 설정)
├── modal.tsx            # 전역 모달
├── (tabs)/              # 탭 네비게이션 그룹
│   ├── _layout.tsx      # 탭 바 설정 (아이콘, 라벨)
│   ├── index.tsx        # 홈 탭
│   └── explore.tsx      # 탐색 탭
└── upload/
    └── index.tsx        # PDF 업로드 화면
```

**컴포넌트 구조:**
```
components/
├── ui/                  # 기본 UI 컴포넌트 (플랫폼 적응형)
├── themed-text.tsx      # 테마 적용 텍스트
├── themed-view.tsx      # 테마 적용 뷰
├── parallax-scroll-view.tsx
├── haptic-tab.tsx       # 햅틱 피드백 탭
└── hello-wave.tsx
```

## Path Alias

`tsconfig.json`에서 `@/*` → 프로젝트 루트로 설정됨. 컴포넌트/훅 임포트 시 사용:
```ts
import { ThemedText } from '@/components/themed-text';
import { useColorScheme } from '@/hooks/use-color-scheme';
```

## Key Patterns

### 화면 컴포넌트
- Expo Router는 `app/` 내 파일을 자동으로 라우트로 등록
- 탭 그룹은 `(tabs)/` 폴더로 구성 (괄호 = URL에 미포함)
- 새 화면 추가 시 `app/` 하위에 파일만 생성하면 됨

### 테마
- `useColorScheme()` 훅으로 라이트/다크 모드 감지
- `ThemedText`, `ThemedView`로 테마 대응 UI 구성
- 색상 상수는 `constants/` 디렉토리 참조

### API 연동
- 백엔드 API 서버: `http://localhost:8080` (project-safehome-api)
- 환경별 베이스 URL은 `constants/` 또는 `app.json` extra 필드 관리 예정
- 업로드 기능: `expo-document-picker`로 PDF 선택 → API 전송

### 플랫폼 분기
```ts
import { Platform } from 'react-native';
Platform.OS === 'ios' | 'android' | 'web'
```
플랫폼별 파일: `component.ios.tsx`, `component.android.tsx` (Expo 자동 해석)

## Service Dependencies

- **호출 대상**: `project-safehome-api` (Spring Boot, `http://localhost:8080`)
- 핵심 기능: PDF 업로드 → 등기부등본 분석 결과 수신 (SSE 스트리밍)

## 주의사항

- `expo-document-picker`는 실제 디바이스/에뮬레이터 필요 (Expo Go에서 일부 제한)
- Android 빌드 시 `android/` 디렉토리의 Gradle 설정 필요
- `node_modules/` 변경 시 `npm install` 후 `expo start --clear`
