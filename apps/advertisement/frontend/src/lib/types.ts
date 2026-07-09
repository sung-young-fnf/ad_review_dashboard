// Backend 응답(snake_case)과 1:1 매칭 — 매핑 없이 그대로 사용.

export interface GeneratedVideo {
  id: string;
  prompt_id: string;
  title: string;
  s3_key: string;
  file_name: string | null;
  file_size: number | null;
  content_type: string | null;
  created_at: string;
  play_url: string | null;
}

export interface Prompt {
  id: string;
  video_id: string;
  title: string;
  content: string;
  created_at: string;
  generated_videos: GeneratedVideo[];
}

export interface Video {
  id: string;
  title: string;
  description: string | null;
  s3_key: string;
  file_name: string | null;
  file_size: number | null;
  content_type: string | null;
  duration_sec: number | null;
  created_at: string;
  prompt_count: number;
  generated_count: number;
  play_url: string | null;
}

export type Purpose = 'original' | 'generated';
