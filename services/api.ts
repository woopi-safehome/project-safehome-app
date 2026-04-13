import { Platform } from 'react-native';
import { ApiResponse, DeedJob, UploadJobResponse } from '@/types/deed';

// Android 에뮬레이터는 10.0.2.2로 호스트 localhost에 접근
// iOS 시뮬레이터 / 웹은 localhost 직접 사용
const BASE_URL = Platform.select({
  android: 'http://10.0.2.2:8080',
  default: 'http://localhost:8080',
});

export async function uploadDeed(fileUri: string, fileName: string, mimeType: string): Promise<string> {
  const formData = new FormData();
  formData.append('file', {
    uri: fileUri,
    name: fileName,
    type: mimeType || 'application/pdf',
  } as unknown as Blob);

  const response = await fetch(`${BASE_URL}/api/deed/upload`, {
    method: 'POST',
    body: formData,
  });

  if (!response.ok) {
    throw new Error(`업로드 실패 (${response.status})`);
  }

  const json: ApiResponse<UploadJobResponse> = await response.json();
  if (json.type !== 'success' || !json.data?.jobId) {
    throw new Error(json.message ?? '업로드 응답 오류');
  }
  return json.data.jobId;
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
