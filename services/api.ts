import { Platform } from 'react-native';
import type { ApiResponse, DeedJob, SseEvent } from '@/types/deed';
import { ApiError, NetworkError, ParseError } from '@/services/errors';
import { logger } from '@/services/logger';

const BASE_URL =
  process.env.EXPO_PUBLIC_API_URL ??
  Platform.select({
    android: 'http://10.0.2.2:8080',
    default: 'http://localhost:8080',
  });

export async function uploadDeed(
  fileUri: string,
  fileName: string,
  mimeType: string,
  signal?: AbortSignal,
  leaseType?: string,
): Promise<string> {
  const url = `${BASE_URL}/api/deed/analyze`;
  const ctx = { url, fileName, leaseType: leaseType ?? 'none' };

  logger.info('API/upload', '업로드 시작', ctx);

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

  let response: Response;
  try {
    response = await fetch(url, { method: 'POST', body: formData, signal });
  } catch (e) {
    const err = new NetworkError('Network request failed', url);
    logger.error('API/upload', '네트워크 연결 실패', err, ctx);
    throw err;
  }

  if (!response.ok) {
    const err = new ApiError(`분석 요청 실패 (${response.status})`, response.status, url);
    logger.error('API/upload', 'HTTP 오류 응답', err, { ...ctx, statusCode: response.status });
    throw err;
  }
  if (!response.body) {
    throw new ParseError('SSE 스트림을 읽을 수 없습니다');
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
                logger.info('API/upload', '업로드 성공', { ...ctx, jobId: event.jobId });
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

  throw new ParseError('분석 작업 ID를 받지 못했습니다');
}

export async function getJob(jobId: string): Promise<DeedJob> {
  const url = `${BASE_URL}/api/deed/jobs/${jobId}`;

  let response: Response;
  try {
    response = await fetch(url);
  } catch (e) {
    const err = new NetworkError('Network request failed', url);
    logger.error('API/getJob', '네트워크 연결 실패', err, { jobId, url });
    throw err;
  }

  if (!response.ok) {
    const err = new ApiError(`조회 실패 (${response.status})`, response.status, url, jobId);
    logger.error('API/getJob', 'HTTP 오류 응답', err, { jobId, url, statusCode: response.status });
    throw err;
  }

  const json: ApiResponse<DeedJob> = await response.json();
  if (json.type !== 'success' || !json.data) {
    const err = new ParseError(json.message ?? '응답 오류', jobId);
    logger.error('API/getJob', '응답 파싱 실패', err, { jobId, url });
    throw err;
  }

  return json.data;
}
