// BFF(/api/v1/*) 호출 헬퍼 + presigned S3 업로드.
import type { Purpose } from './types';

export type ApiError = Error & { status?: number };

export async function api<T>(path: string, options?: RequestInit): Promise<T> {
  const res = await fetch(`/api/v1${path}`, {
    headers: { 'Content-Type': 'application/json', ...(options?.headers ?? {}) },
    ...options,
  });
  if (!res.ok) {
    let detail = `${res.status} ${res.statusText}`;
    try {
      const j = await res.json();
      detail = j.detail || j.error || detail;
    } catch {
      /* non-json error */
    }
    const err = new Error(detail) as ApiError;
    err.status = res.status;
    throw err;
  }
  if (res.status === 204) return undefined as T;
  return res.json() as Promise<T>;
}

export const apiGet = <T>(path: string) => api<T>(path);
export const apiPost = <T>(path: string, body: unknown) =>
  api<T>(path, { method: 'POST', body: JSON.stringify(body) });
export const apiPut = <T>(path: string, body: unknown) =>
  api<T>(path, { method: 'PUT', body: JSON.stringify(body) });
export const apiDelete = (path: string) => api<void>(path, { method: 'DELETE' });

/**
 * 프록시 업로드: 브라우저 → BFF(/api/v1/uploads) → 백엔드 → S3.
 * 버킷 CORS 불필요. 반환된 key 를 레코드 생성 API 에 전달한다.
 */
export async function uploadFile(
  file: File,
  purpose: Purpose,
  onProgress?: (pct: number) => void,
): Promise<{ key: string; file_name: string; file_size: number; content_type: string }> {
  const contentType = file.type || 'application/octet-stream';
  const fd = new FormData();
  fd.append('purpose', purpose);
  fd.append('file', file);

  const result = await new Promise<{ key: string; file_name?: string; file_size?: number; content_type?: string }>(
    (resolve, reject) => {
      const xhr = new XMLHttpRequest();
      xhr.open('POST', '/api/v1/uploads');
      // multipart boundary 는 브라우저가 자동 설정 — Content-Type 수동 지정 금지
      xhr.upload.onprogress = (e) => {
        if (e.lengthComputable && onProgress) onProgress(Math.round((e.loaded / e.total) * 100));
      };
      xhr.onload = () => {
        if (xhr.status >= 200 && xhr.status < 300) {
          try {
            resolve(JSON.parse(xhr.responseText));
          } catch {
            reject(new Error('업로드 응답 파싱 실패'));
          }
        } else {
          let msg = `업로드 실패 (${xhr.status})`;
          try {
            const j = JSON.parse(xhr.responseText);
            msg = j.detail || j.error || msg;
          } catch {
            /* non-json */
          }
          reject(new Error(msg));
        }
      };
      xhr.onerror = () => reject(new Error('업로드 네트워크 오류'));
      xhr.send(fd);
    },
  );

  return {
    key: result.key,
    file_name: result.file_name ?? file.name,
    file_size: result.file_size ?? file.size,
    content_type: result.content_type ?? contentType,
  };
}
