import { Platform } from 'react-native';
import type { ApiResponse, DeedJob, SseEvent } from '@/types/deed';

const BASE_URL =
  process.env.EXPO_PUBLIC_API_URL ??
  Platform.select({
    android: 'http://10.0.2.2:8080',
    default: 'http://localhost:8080',
  });

// PDF를 업로드하고 분석을 시작한 뒤 jobId를 반환합니다.
// SSE 스트림의 첫 번째 이벤트에서 jobId를 추출합니다.
// 분석은 서버에서 비동기로 계속 진행됩니다.
export async function uploadDeed(
  fileUri: string,
  fileName: string,
  mimeType: string,
  signal?: AbortSignal,
  leaseType?: string,
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
  if (leaseType) {
    formData.append('leaseType', leaseType);
  }

  // 웹: fetch ReadableStream 사용
  if (Platform.OS === 'web') {
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

  // 네이티브: XHR onprogress로 SSE 스트리밍 처리
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.open('POST', `${BASE_URL}/api/deed/analyze`);

    let buffer = '';
    let resolved = false;

    signal?.addEventListener('abort', () => {
      xhr.abort();
      reject(new Error('요청이 취소되었습니다'));
    });

    const parseBuffer = () => {
      if (!xhr.responseText) return;

      const lines = xhr.responseText.split('\n');
      for (const line of lines) {
        const trimmed = line.trim();
        if (trimmed.startsWith('data:')) {
          const raw = trimmed.slice(5).trim();
          if (raw) {
            try {
              const event = JSON.parse(raw) as SseEvent;
              if (event.jobId && !resolved) {
                resolved = true;
                resolve(event.jobId);
                return;
              }
            } catch {
              // ignore malformed lines
            }
          }
        }
      }
    };

    xhr.onreadystatechange = () => {
      if (xhr.readyState === 3 || xhr.readyState === 4) {
        parseBuffer();
      }
    };

    xhr.onerror = () => reject(new Error('Network request failed'));
    xhr.ontimeout = () => reject(new Error('요청 시간이 초과되었습니다'));
    xhr.onload = () => {
      if (!resolved) {
        reject(new Error('분석 작업 ID를 받지 못했습니다'));
      }
    };

    xhr.send(formData);
  });
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
