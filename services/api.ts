import { Platform } from 'react-native';
import type { ApiResponse, DeedJob, SseEvent } from '@/types/deed';

// Android 에뮬레이터는 10.0.2.2로 호스트 localhost에 접근
// iOS 시뮬레이터 / 웹은 localhost 직접 사용
const BASE_URL = Platform.select({
  android: 'http://10.0.2.2:8080',
  default: 'http://localhost:8080',
});

// PDF를 업로드하고 분석을 시작한 뒤 jobId를 반환합니다.
// SSE 스트림의 첫 번째 이벤트에서 jobId를 추출하고 연결을 닫습니다.
// 분석은 서버에서 비동기로 계속 진행됩니다.
export async function uploadDeed(
  fileUri: string,
  fileName: string,
  mimeType: string,
  signal?: AbortSignal,
): Promise<string> {
  const formData = new FormData();
  if (Platform.OS === 'web') {
    const blobRes = await fetch(fileUri);
    const blob = await blobRes.blob();
    formData.append('file', blob, fileName);
  } else {
    formData.append('file', {
      uri: fileUri,
      name: fileName,
      type: mimeType || 'application/pdf',
    } as unknown as Blob);
  }

  const response = await fetch(`${BASE_URL}/api/deed/analyze`, {
    method: 'POST',
    body: formData,
    signal,
  });

  if (!response.ok) {
    throw new Error(`분석 요청 실패 (${response.status})`);
  }
  if (!response.body) {
    throw new Error('SSE 스트림을 읽을 수 없습니다');
  }

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split('\n');
      buffer = lines.pop() ?? '';

      for (const line of lines) {
        const trimmed = line.trim();
        if (trimmed.startsWith('data:')) {
          const raw = trimmed.slice(5).trim();
          if (raw) {
            try {
              const event = JSON.parse(raw) as SseEvent;
              if (event.jobId) {
                return event.jobId;
              }
            } catch {
              // ignore malformed lines
            }
          }
        }
      }
    }
  } finally {
    reader.releaseLock();
  }

  throw new Error('분석 작업 ID를 받지 못했습니다');
}

export async function getJob(jobId: string): Promise<DeedJob> {
  const response = await fetch(`${BASE_URL}/api/deed/jobs/${jobId}`);

  if (!response.ok) {
    throw new Error(`조회 실패 (${response.status})`);
  }

  const json: ApiResponse<DeedJob> = await response.json();
  if (json.type !== 'success' || !json.data) {
    throw new Error(json.message ?? '응답 오류');
  }
  return json.data;
}
