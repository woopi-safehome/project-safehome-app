import { Platform } from 'react-native';
import type { ApiResponse, DeedJob, SseEvent } from '@/types/deed';

// Android 에뮬레이터는 10.0.2.2로 호스트 localhost에 접근
// iOS 시뮬레이터 / 웹은 localhost 직접 사용
const BASE_URL = Platform.select({
  android: 'http://10.0.2.2:8080',
  default: 'http://localhost:8080',
});

export async function analyzeDeed(
  fileUri: string,
  fileName: string,
  mimeType: string,
  onEvent: (event: SseEvent) => void,
  signal?: AbortSignal,
): Promise<void> {
  const formData = new FormData();
  if (Platform.OS === 'web') {
    // 웹에서는 blob URL을 실제 Blob으로 변환해서 추가해야 함
    // { uri, name, type } 객체는 브라우저에서 [object Object]로 직렬화됨
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
              onEvent(JSON.parse(raw) as SseEvent);
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
