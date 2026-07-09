'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Film, MessageSquareText, Sparkles, Search, Upload, Trash2, Plus } from 'lucide-react';
import { apiGet, apiPost, apiDelete, uploadFile, type ApiError } from '@/lib/api';
import type { Video } from '@/lib/types';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Skeleton } from '@/components/ui/skeleton';
import { FormDialog } from '@/components/ui/form-dialog';
import { ConfirmDialog } from '@/components/ui/confirm-dialog';
import { toast } from '@/components/ui/toaster';

function formatBytes(n: number | null): string {
  if (!n) return '';
  const u = ['B', 'KB', 'MB', 'GB'];
  let i = 0;
  let v = n;
  while (v >= 1024 && i < u.length - 1) {
    v /= 1024;
    i++;
  }
  return `${v.toFixed(v < 10 && i > 0 ? 1 : 0)}${u[i]}`;
}

export default function VideosPage() {
  const router = useRouter();
  const [videos, setVideos] = useState<Video[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');

  const [uploadOpen, setUploadOpen] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [pct, setPct] = useState(0);

  const [deleting, setDeleting] = useState<Video | null>(null);
  const [deleteBusy, setDeleteBusy] = useState(false);

  const load = () => {
    setLoading(true);
    apiGet<Video[]>('/videos')
      .then(setVideos)
      .catch((e) => toast.error(`목록 로드 실패: ${e.message}`))
      .finally(() => setLoading(false));
  };
  useEffect(load, []);

  const filtered = videos.filter((v) => v.title.toLowerCase().includes(search.toLowerCase()));
  const stats = {
    videos: videos.length,
    prompts: videos.reduce((s, v) => s + v.prompt_count, 0),
    generated: videos.reduce((s, v) => s + v.generated_count, 0),
  };

  const handleUpload = async (form: HTMLFormElement) => {
    const fd = new FormData(form);
    const title = String(fd.get('title') || '').trim();
    const description = String(fd.get('description') || '').trim();
    const file = fd.get('file') as File | null;
    if (!title || !file || file.size === 0) {
      toast.error('제목과 영상 파일을 입력하세요.');
      return;
    }
    setUploading(true);
    setPct(0);
    try {
      const meta = await uploadFile(file, 'original', setPct);
      await apiPost<Video>('/videos', {
        title,
        description: description || null,
        s3_key: meta.key,
        file_name: meta.file_name,
        file_size: meta.file_size,
        content_type: meta.content_type,
      });
      toast.success('영상이 등록되었습니다.');
      setUploadOpen(false);
      load();
    } catch (e) {
      toast.error(`업로드 실패: ${(e as Error).message}`);
    } finally {
      setUploading(false);
    }
  };

  const handleDelete = async () => {
    if (!deleting) return;
    const target = deleting;
    setDeleteBusy(true);
    try {
      await apiDelete(`/videos/${target.id}`);
      toast.success('삭제되었습니다.');
      setVideos((prev) => prev.filter((v) => v.id !== target.id));
      setDeleting(null);
    } catch (e) {
      const err = e as ApiError;
      if (err.status === 404) {
        // 이미 DB 에 없는 유령 카드 — 목록에서 제거하고 최신 상태로 재동기화
        toast.message('이미 삭제된 영상입니다. 목록을 새로고침합니다.');
        setVideos((prev) => prev.filter((v) => v.id !== target.id));
        setDeleting(null);
        load();
      } else {
        toast.error(`삭제 실패: ${err.message}`);
      }
    } finally {
      setDeleteBusy(false);
    }
  };

  return (
    <div className="mx-auto max-w-[1280px] space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="font-display text-2xl font-bold">영상 라이브러리</h1>
          <p className="mt-1 text-sm text-muted-foreground">원본 영상을 등록하고 분석·비교를 시작하세요.</p>
        </div>
        <Button onClick={() => setUploadOpen(true)}>
          <Upload className="h-4 w-4" /> 영상 업로드
        </Button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-3 gap-4">
        {[
          { label: '원본 영상', value: stats.videos, icon: Film },
          { label: '프롬프트', value: stats.prompts, icon: MessageSquareText },
          { label: 'AI 영상', value: stats.generated, icon: Sparkles },
        ].map(({ label, value, icon: Icon }) => (
          <div key={label} className="rounded-xl border border-border bg-card p-5">
            <div className="flex items-center gap-2 text-sm text-muted-foreground">
              <Icon className="h-4 w-4" />
              {label}
            </div>
            <div className="mt-1 font-display text-3xl font-bold">{value}</div>
          </div>
        ))}
      </div>

      {/* Search */}
      <div className="relative max-w-md">
        <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
        <Input
          className="pl-10"
          placeholder="제목으로 검색…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>

      {/* Grid */}
      {loading ? (
        <div className="grid grid-cols-2 gap-5 lg:grid-cols-3">
          {[0, 1, 2].map((i) => (
            <Skeleton key={i} className="h-64 rounded-xl" />
          ))}
        </div>
      ) : filtered.length === 0 ? (
        <div className="rounded-xl border border-dashed border-border p-16 text-center">
          <Film className="mx-auto h-8 w-8 text-muted-foreground" />
          <p className="mt-3 text-sm text-muted-foreground">
            {search ? '검색 결과가 없습니다.' : '아직 등록된 영상이 없습니다. 첫 영상을 업로드하세요.'}
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-2 gap-5 lg:grid-cols-3">
          {filtered.map((v) => (
            <div
              key={v.id}
              className="group flex flex-col overflow-hidden rounded-xl border border-border bg-card transition-all hover:-translate-y-0.5 hover:shadow-card"
            >
              <button
                type="button"
                onClick={() => router.push(`/workspace?ids=${v.id}`)}
                className="block aspect-video w-full bg-black/90 text-left"
              >
                {v.play_url ? (
                  <video src={v.play_url} preload="metadata" muted className="h-full w-full object-contain" />
                ) : (
                  <div className="flex h-full items-center justify-center text-muted-foreground">
                    <Film className="h-8 w-8" />
                  </div>
                )}
              </button>
              <div className="flex flex-1 flex-col gap-3 p-4">
                <button
                  type="button"
                  onClick={() => router.push(`/workspace?ids=${v.id}`)}
                  className="text-left"
                >
                  <div className="truncate font-medium" title={v.title}>
                    {v.title}
                  </div>
                  {v.description && (
                    <div className="mt-0.5 line-clamp-2 text-sm text-muted-foreground">{v.description}</div>
                  )}
                </button>
                <div className="mt-auto flex items-center justify-between">
                  <div className="flex gap-1.5">
                    <span className="inline-flex items-center gap-1 rounded-full bg-secondary px-2 py-0.5 text-xs text-secondary-foreground">
                      <MessageSquareText className="h-3 w-3" /> {v.prompt_count}
                    </span>
                    <span className="inline-flex items-center gap-1 rounded-full bg-secondary px-2 py-0.5 text-xs text-secondary-foreground">
                      <Sparkles className="h-3 w-3" /> {v.generated_count}
                    </span>
                    {v.file_size ? (
                      <span className="inline-flex items-center rounded-full px-2 py-0.5 text-xs text-muted-foreground">
                        {formatBytes(v.file_size)}
                      </span>
                    ) : null}
                  </div>
                  <Button
                    variant="destructive"
                    size="icon"
                    aria-label="삭제"
                    onClick={() => setDeleting(v)}
                  >
                    <Trash2 className="h-4 w-4" />
                  </Button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Upload dialog */}
      <FormDialog
        open={uploadOpen}
        onClose={() => !uploading && setUploadOpen(false)}
        title="원본 영상 업로드"
        description="영상 파일을 S3에 업로드하고 라이브러리에 등록합니다."
        submitLabel="업로드"
        loading={uploading}
        onSubmit={handleUpload}
      >
        <div>
          <Label htmlFor="title">제목</Label>
          <Input id="title" name="title" placeholder="예: 봄 캠페인 광고 A" data-autofocus required />
        </div>
        <div>
          <Label htmlFor="description">설명 (선택)</Label>
          <Textarea id="description" name="description" rows={2} placeholder="메모…" />
        </div>
        <div>
          <Label htmlFor="file">영상 파일</Label>
          <input
            id="file"
            name="file"
            type="file"
            accept="video/*"
            className="block w-full text-sm text-muted-foreground file:mr-3 file:rounded-md file:border-0 file:bg-secondary file:px-3 file:py-2 file:text-sm file:font-medium hover:file:bg-muted"
            required
          />
        </div>
        {uploading && (
          <div className="h-2 overflow-hidden rounded-full bg-muted">
            <div className="h-full bg-primary transition-all" style={{ width: `${pct}%` }} />
          </div>
        )}
      </FormDialog>

      {/* Delete confirm */}
      <ConfirmDialog
        open={!!deleting}
        title="영상을 삭제할까요?"
        description={`"${deleting?.title}" 및 하위 프롬프트·AI영상·S3 파일이 모두 삭제됩니다. 복구 불가.`}
        variant="danger"
        confirmLabel="삭제"
        loading={deleteBusy}
        onConfirm={handleDelete}
        onCancel={() => setDeleting(null)}
      />
    </div>
  );
}
