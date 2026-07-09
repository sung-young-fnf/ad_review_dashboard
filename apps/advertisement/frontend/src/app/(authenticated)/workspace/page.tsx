'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { Plus, X, Pencil, Trash2, Sparkles, MessageSquareText, Film } from 'lucide-react';
import { apiGet, apiPost, apiPut, apiDelete, uploadFile } from '@/lib/api';
import type { Video, Prompt } from '@/lib/types';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Skeleton } from '@/components/ui/skeleton';
import { Modal } from '@/components/ui/modal';
import { FormDialog } from '@/components/ui/form-dialog';
import { ConfirmDialog } from '@/components/ui/confirm-dialog';
import { toast } from '@/components/ui/toaster';
import { cn } from '@/lib/utils';

export default function WorkspacePage() {
  const [allVideos, setAllVideos] = useState<Video[]>([]);
  const [openIds, setOpenIds] = useState<string[]>([]);
  const [activeId, setActiveId] = useState<string | null>(null);
  const [restored, setRestored] = useState(false); // 복원 완료 전엔 저장 금지(초기 [] 덮어쓰기 방지)

  const [activeVideo, setActiveVideo] = useState<Video | null>(null);
  const [prompts, setPrompts] = useState<Prompt[]>([]);
  const [loadingActive, setLoadingActive] = useState(false);

  const [pickerOpen, setPickerOpen] = useState(false);

  // prompt create/edit
  const [promptDialog, setPromptDialog] = useState<{ open: boolean; editing: Prompt | null }>({
    open: false,
    editing: null,
  });
  const [promptBusy, setPromptBusy] = useState(false);
  const [deletingPrompt, setDeletingPrompt] = useState<Prompt | null>(null);
  const promptTitleRef = useRef<HTMLInputElement>(null);
  const promptContentRef = useRef<HTMLTextAreaElement>(null);

  // generated create
  const [genFor, setGenFor] = useState<Prompt | null>(null);
  const [genBusy, setGenBusy] = useState(false);
  const [genPct, setGenPct] = useState(0);
  const [deletingGen, setDeletingGen] = useState<{ id: string; title: string } | null>(null);

  // ── initial load: all videos + 탭 복원 (URL 우선, 없으면 localStorage) ──
  useEffect(() => {
    apiGet<Video[]>('/videos')
      .then((vs) => {
        setAllVideos(vs);
        // 삭제되어 더 이상 없는 영상 탭은 정리
        const valid = new Set(vs.map((v) => v.id));
        setOpenIds((prev) => prev.filter((id) => valid.has(id)));
      })
      .catch((e) => toast.error(`영상 목록 로드 실패: ${e.message}`));

    // localStorage 로 복원한 뒤, URL 로 들어온 영상(라이브러리 클릭)은 기존 탭에 추가로 연다.
    const saved = localStorage.getItem('adv_ws_open');
    const ids = saved ? saved.split(',').filter(Boolean) : [];
    const urlIds = new URLSearchParams(window.location.search).get('ids');
    const urlList = urlIds ? urlIds.split(',').filter(Boolean) : [];
    let active: string | null;
    if (urlList.length) {
      for (const id of urlList) if (!ids.includes(id)) ids.push(id);
      active = urlList[0]; // 링크로 연 영상에 포커스
    } else {
      const savedActive = localStorage.getItem('adv_ws_active');
      active = savedActive && ids.includes(savedActive) ? savedActive : (ids[0] ?? null);
    }
    setOpenIds(ids);
    setActiveId(active);
    setRestored(true);
  }, []);

  // ── 탭 상태 유지: URL + localStorage 동기화 (복원 완료 후에만) ──
  useEffect(() => {
    if (!restored) return;
    const qs = openIds.length ? `?ids=${openIds.join(',')}` : '';
    window.history.replaceState(null, '', `/workspace${qs}`);
    localStorage.setItem('adv_ws_open', openIds.join(','));
  }, [openIds, restored]);

  useEffect(() => {
    if (!restored) return;
    localStorage.setItem('adv_ws_active', activeId ?? '');
  }, [activeId, restored]);

  const reloadActive = useCallback((videoId: string) => {
    setLoadingActive(true);
    Promise.all([apiGet<Video>(`/videos/${videoId}`), apiGet<Prompt[]>(`/videos/${videoId}/prompts`)])
      .then(([v, p]) => {
        setActiveVideo(v);
        setPrompts(p);
      })
      .catch((e) => toast.error(`불러오기 실패: ${e.message}`))
      .finally(() => setLoadingActive(false));
  }, []);

  useEffect(() => {
    if (activeId) reloadActive(activeId);
    else {
      setActiveVideo(null);
      setPrompts([]);
    }
  }, [activeId, reloadActive]);

  const openTab = (id: string) => {
    setOpenIds((prev) => (prev.includes(id) ? prev : [...prev, id]));
    setActiveId(id);
    setPickerOpen(false);
  };
  const closeTab = (id: string) => {
    setOpenIds((prev) => {
      const next = prev.filter((x) => x !== id);
      if (activeId === id) setActiveId(next[next.length - 1] ?? null);
      return next;
    });
  };

  const titleOf = (id: string) => allVideos.find((v) => v.id === id)?.title ?? '영상';

  // ── prompt handlers ──
  const loadPromptFile = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const f = e.target.files?.[0];
    if (!f) return;
    try {
      const text = await f.text();
      if (promptContentRef.current) promptContentRef.current.value = text;
      if (promptTitleRef.current && !promptTitleRef.current.value) {
        promptTitleRef.current.value = f.name.replace(/\.[^.]+$/, '');
      }
      toast.success(`"${f.name}" 내용을 불러왔습니다.`);
    } catch {
      toast.error('파일을 읽지 못했습니다.');
    } finally {
      e.target.value = '';
    }
  };

  const submitPrompt = async (form: HTMLFormElement) => {
    if (!activeId) return;
    const fd = new FormData(form);
    const title = String(fd.get('title') || '').trim();
    const content = String(fd.get('content') || '').trim();
    if (!title || !content) {
      toast.error('제목과 프롬프트 내용을 입력하세요.');
      return;
    }
    setPromptBusy(true);
    try {
      if (promptDialog.editing) {
        await apiPut<Prompt>(`/prompts/${promptDialog.editing.id}`, { title, content });
        toast.success('프롬프트가 수정되었습니다.');
      } else {
        await apiPost<Prompt>(`/videos/${activeId}/prompts`, { title, content });
        toast.success('프롬프트가 추가되었습니다.');
      }
      setPromptDialog({ open: false, editing: null });
      reloadActive(activeId);
    } catch (e) {
      toast.error(`저장 실패: ${(e as Error).message}`);
    } finally {
      setPromptBusy(false);
    }
  };

  const confirmDeletePrompt = async () => {
    if (!deletingPrompt || !activeId) return;
    try {
      await apiDelete(`/prompts/${deletingPrompt.id}`);
      toast.success('프롬프트가 삭제되었습니다.');
      setDeletingPrompt(null);
      reloadActive(activeId);
    } catch (e) {
      toast.error(`삭제 실패: ${(e as Error).message}`);
    }
  };

  // ── generated handlers ──
  const submitGenerated = async (form: HTMLFormElement) => {
    if (!genFor || !activeId) return;
    const fd = new FormData(form);
    const title = String(fd.get('title') || '').trim();
    const file = fd.get('file') as File | null;
    if (!title || !file || file.size === 0) {
      toast.error('제목과 AI 영상 파일을 입력하세요.');
      return;
    }
    setGenBusy(true);
    setGenPct(0);
    try {
      const meta = await uploadFile(file, 'generated', setGenPct);
      await apiPost(`/prompts/${genFor.id}/generated-videos`, {
        title,
        s3_key: meta.key,
        file_name: meta.file_name,
        file_size: meta.file_size,
        content_type: meta.content_type,
      });
      toast.success('AI 영상이 등록되었습니다.');
      setGenFor(null);
      reloadActive(activeId);
    } catch (e) {
      toast.error(`업로드 실패: ${(e as Error).message}`);
    } finally {
      setGenBusy(false);
    }
  };

  const confirmDeleteGen = async () => {
    if (!deletingGen || !activeId) return;
    try {
      await apiDelete(`/generated-videos/${deletingGen.id}`);
      toast.success('AI 영상이 삭제되었습니다.');
      setDeletingGen(null);
      reloadActive(activeId);
    } catch (e) {
      toast.error(`삭제 실패: ${(e as Error).message}`);
    }
  };

  const closedVideos = allVideos.filter((v) => !openIds.includes(v.id));

  return (
    <div className="mx-auto flex h-[calc(100vh-4rem)] max-w-[1280px] flex-col">
      <h1 className="font-display text-2xl font-bold">워크스페이스</h1>
      <p className="mb-4 mt-1 text-sm text-muted-foreground">
        영상을 탭으로 열어 프롬프트와 AI 영상을 관리하세요.
      </p>

      {/* Tabs */}
      <div className="flex items-center gap-1 border-b border-border">
        {openIds.map((id) => (
          <div
            key={id}
            className={cn(
              'flex items-center gap-2 border-b-2 px-3 py-2 text-sm',
              activeId === id ? 'border-primary font-medium text-primary' : 'border-transparent text-muted-foreground',
            )}
          >
            <button type="button" onClick={() => setActiveId(id)} className="max-w-[160px] truncate">
              {titleOf(id)}
            </button>
            <button type="button" aria-label="탭 닫기" onClick={() => closeTab(id)} className="hover:text-foreground">
              <X className="h-3.5 w-3.5" />
            </button>
          </div>
        ))}
        <button
          type="button"
          onClick={() => setPickerOpen(true)}
          className="flex items-center gap-1 px-3 py-2 text-sm text-muted-foreground hover:text-primary"
        >
          <Plus className="h-4 w-4" /> 영상 열기
        </button>
      </div>

      {/* Body */}
      {!activeId ? (
        <div className="flex flex-1 flex-col items-center justify-center gap-3 text-center">
          <Film className="h-8 w-8 text-muted-foreground" />
          <p className="text-sm text-muted-foreground">위 “영상 열기”로 원본 영상을 선택하세요.</p>
        </div>
      ) : loadingActive ? (
        <div className="grid flex-1 grid-cols-[380px_1fr] gap-6 pt-5">
          <Skeleton className="aspect-video w-full rounded-xl" />
          <Skeleton className="h-full rounded-xl" />
        </div>
      ) : (
        <div className="grid flex-1 grid-cols-[380px_1fr] gap-6 overflow-hidden pt-5">
          {/* Left: original player */}
          <div className="space-y-3">
            <div className="overflow-hidden rounded-xl border border-border bg-black">
              {activeVideo?.play_url ? (
                <video src={activeVideo.play_url} controls className="aspect-video w-full" />
              ) : (
                <div className="flex aspect-video items-center justify-center text-muted-foreground">
                  <Film className="h-8 w-8" />
                </div>
              )}
            </div>
            <div>
              <div className="font-medium">{activeVideo?.title}</div>
              {activeVideo?.description && (
                <p className="mt-1 text-sm text-muted-foreground">{activeVideo.description}</p>
              )}
            </div>
          </div>

          {/* Right: prompts (nested generated) */}
          <div className="flex flex-col overflow-hidden">
            <div className="mb-3 flex items-center justify-between">
              <h2 className="font-display text-lg font-semibold">프롬프트</h2>
              <Button size="sm" onClick={() => setPromptDialog({ open: true, editing: null })}>
                <Plus className="h-4 w-4" /> 프롬프트 추가
              </Button>
            </div>

            <div className="flex-1 space-y-4 overflow-y-auto pr-1">
              {prompts.length === 0 ? (
                <div className="rounded-xl border border-dashed border-border p-10 text-center text-sm text-muted-foreground">
                  아직 프롬프트가 없습니다. 이 영상의 분석 프롬프트를 추가하세요.
                </div>
              ) : (
                prompts.map((p) => (
                  <div key={p.id} className="rounded-xl border border-border bg-card">
                    <div className="flex items-start justify-between gap-3 border-b border-border p-4">
                      <div className="min-w-0">
                        <div className="flex items-center gap-2">
                          <MessageSquareText className="h-4 w-4 shrink-0 text-primary" />
                          <span className="truncate font-medium">{p.title}</span>
                        </div>
                        <p className="mt-2 whitespace-pre-wrap text-sm text-muted-foreground">{p.content}</p>
                      </div>
                      <div className="flex shrink-0 gap-1">
                        <Button
                          variant="ghost"
                          size="icon"
                          aria-label="프롬프트 수정"
                          onClick={() => setPromptDialog({ open: true, editing: p })}
                        >
                          <Pencil className="h-4 w-4" />
                        </Button>
                        <Button
                          variant="ghost"
                          size="icon"
                          aria-label="프롬프트 삭제"
                          onClick={() => setDeletingPrompt(p)}
                        >
                          <Trash2 className="h-4 w-4 text-destructive" />
                        </Button>
                      </div>
                    </div>

                    {/* nested generated videos */}
                    <div className="p-4">
                      <div className="mb-2 flex items-center justify-between">
                        <span className="flex items-center gap-1.5 text-sm font-medium text-muted-foreground">
                          <Sparkles className="h-3.5 w-3.5" /> AI 영상 ({p.generated_videos.length})
                        </span>
                        <Button variant="secondary" size="sm" onClick={() => setGenFor(p)}>
                          <Plus className="h-3.5 w-3.5" /> 등록
                        </Button>
                      </div>
                      {p.generated_videos.length === 0 ? (
                        <p className="text-sm text-muted-foreground">이 프롬프트로 만든 AI 영상을 등록하세요.</p>
                      ) : (
                        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
                          {p.generated_videos.map((g) => (
                            <div key={g.id} className="overflow-hidden rounded-lg border border-border">
                              <div className="bg-black">
                                {g.play_url ? (
                                  <video src={g.play_url} controls className="aspect-video w-full" />
                                ) : (
                                  <div className="flex aspect-video items-center justify-center text-muted-foreground">
                                    <Sparkles className="h-5 w-5" />
                                  </div>
                                )}
                              </div>
                              <div className="flex items-center justify-between gap-2 p-2">
                                <span className="truncate text-xs" title={g.title}>
                                  {g.title}
                                </span>
                                <button
                                  type="button"
                                  aria-label="AI 영상 삭제"
                                  onClick={() => setDeletingGen({ id: g.id, title: g.title })}
                                  className="shrink-0 text-muted-foreground hover:text-destructive"
                                >
                                  <Trash2 className="h-3.5 w-3.5" />
                                </button>
                              </div>
                            </div>
                          ))}
                        </div>
                      )}
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>
      )}

      {/* Picker modal */}
      <Modal open={pickerOpen} onClose={() => setPickerOpen(false)} title="영상 열기" description="탭으로 열 원본 영상을 선택하세요.">
        {closedVideos.length === 0 ? (
          <p className="text-sm text-muted-foreground">열 수 있는 영상이 없습니다.</p>
        ) : (
          <div className="max-h-80 space-y-1 overflow-y-auto">
            {closedVideos.map((v) => (
              <button
                key={v.id}
                type="button"
                onClick={() => openTab(v.id)}
                className="flex w-full items-center justify-between rounded-md px-3 py-2 text-left text-sm hover:bg-muted"
              >
                <span className="truncate">{v.title}</span>
                <span className="shrink-0 text-xs text-muted-foreground">
                  프롬프트 {v.prompt_count} · AI {v.generated_count}
                </span>
              </button>
            ))}
          </div>
        )}
      </Modal>

      {/* Prompt create/edit */}
      <FormDialog
        open={promptDialog.open}
        onClose={() => !promptBusy && setPromptDialog({ open: false, editing: null })}
        title={promptDialog.editing ? '프롬프트 수정' : '프롬프트 추가'}
        submitLabel={promptDialog.editing ? '수정' : '추가'}
        loading={promptBusy}
        onSubmit={submitPrompt}
      >
        <div>
          <Label htmlFor="p-title">제목</Label>
          <Input
            id="p-title"
            name="title"
            ref={promptTitleRef}
            data-autofocus
            defaultValue={promptDialog.editing?.title ?? ''}
            required
          />
        </div>
        <div>
          <div className="mb-1.5 flex items-center justify-between">
            <Label htmlFor="p-content" className="mb-0">
              프롬프트 내용
            </Label>
            <label className="cursor-pointer text-xs font-medium text-primary hover:underline">
              파일에서 불러오기 (.txt/.md/.json)
              <input type="file" accept=".txt,.md,.json,text/*" className="hidden" onChange={loadPromptFile} />
            </label>
          </div>
          <Textarea
            id="p-content"
            name="content"
            ref={promptContentRef}
            rows={6}
            defaultValue={promptDialog.editing?.content ?? ''}
            placeholder="직접 입력하거나, 오른쪽 위 ‘파일에서 불러오기’로 프롬프트 파일을 올리세요…"
            required
          />
        </div>
      </FormDialog>

      {/* Generated create */}
      <FormDialog
        open={!!genFor}
        onClose={() => !genBusy && setGenFor(null)}
        title="AI 영상 등록"
        description={genFor ? `프롬프트 "${genFor.title}" 로 만든 영상` : ''}
        submitLabel="등록"
        loading={genBusy}
        onSubmit={submitGenerated}
      >
        <div>
          <Label htmlFor="g-title">제목</Label>
          <Input id="g-title" name="title" data-autofocus placeholder="예: Veo3 결과 v1" required />
        </div>
        <div>
          <Label htmlFor="g-file">영상 파일</Label>
          <input
            id="g-file"
            name="file"
            type="file"
            accept="video/*"
            className="block w-full text-sm text-muted-foreground file:mr-3 file:rounded-md file:border-0 file:bg-secondary file:px-3 file:py-2 file:text-sm file:font-medium hover:file:bg-muted"
            required
          />
        </div>
        {genBusy && (
          <div className="h-2 overflow-hidden rounded-full bg-muted">
            <div className="h-full bg-primary transition-all" style={{ width: `${genPct}%` }} />
          </div>
        )}
      </FormDialog>

      <ConfirmDialog
        open={!!deletingPrompt}
        title="프롬프트를 삭제할까요?"
        description={`"${deletingPrompt?.title}" 및 하위 AI영상·S3 파일이 삭제됩니다.`}
        variant="danger"
        confirmLabel="삭제"
        onConfirm={confirmDeletePrompt}
        onCancel={() => setDeletingPrompt(null)}
      />
      <ConfirmDialog
        open={!!deletingGen}
        title="AI 영상을 삭제할까요?"
        description={`"${deletingGen?.title}" 및 S3 파일이 삭제됩니다.`}
        variant="danger"
        confirmLabel="삭제"
        onConfirm={confirmDeleteGen}
        onCancel={() => setDeletingGen(null)}
      />
    </div>
  );
}
