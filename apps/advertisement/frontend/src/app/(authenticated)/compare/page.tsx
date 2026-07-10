'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import { Play, Pause, RotateCcw, X, Plus, Film, Sparkles } from 'lucide-react';
import { apiGet } from '@/lib/api';
import type { Video, Prompt } from '@/lib/types';
import { Button } from '@/components/ui/button';
import { Modal } from '@/components/ui/modal';
import { toast } from '@/components/ui/toaster';
import { cn } from '@/lib/utils';

interface Item {
  id: string;
  kind: 'original' | 'generated';
  title: string;
  play_url: string | null;
}

// 원본 영상별로 하위 AI 영상을 묶어서 표시하기 위한 그룹
interface Group {
  video: Video;
  original: Item;
  ai: { item: Item; promptTitle: string }[];
}

const SPEEDS = [1, 0.5, 0.3];

export default function ComparePage() {
  const [cols, setCols] = useState(2);
  const [speed, setSpeed] = useState(1);
  const [slots, setSlots] = useState<(Item | null)[]>([null, null]);
  const [groups, setGroups] = useState<Group[]>([]);
  const [pickerFor, setPickerFor] = useState<number | null>(null);

  const videoRefs = useRef<(HTMLVideoElement | null)[]>([]);

  // 원본 영상 + 각 영상의 프롬프트별 AI 영상을 계층으로 로드
  useEffect(() => {
    (async () => {
      try {
        const videos = await apiGet<Video[]>('/videos');
        const gs = await Promise.all(
          videos.map(async (v) => {
            const prompts = await apiGet<Prompt[]>(`/videos/${v.id}/prompts`);
            const ai = prompts.flatMap((p) =>
              p.generated_videos.map((g) => ({
                item: { id: g.id, kind: 'generated' as const, title: g.title, play_url: g.play_url },
                promptTitle: p.title,
              })),
            );
            return {
              video: v,
              original: { id: v.id, kind: 'original' as const, title: v.title, play_url: v.play_url },
              ai,
            };
          }),
        );
        setGroups(gs);
      } catch (e) {
        toast.error(`목록 로드 실패: ${(e as Error).message}`);
      }
    })();
  }, []);

  // adjust slots when column count changes
  useEffect(() => {
    setSlots((prev) => {
      const next = prev.slice(0, cols);
      while (next.length < cols) next.push(null);
      return next;
    });
  }, [cols]);

  // apply playback speed to all loaded videos
  useEffect(() => {
    videoRefs.current.forEach((v) => {
      if (v) v.playbackRate = speed;
    });
  }, [speed, slots]);

  const setSlot = (idx: number, item: Item | null) => {
    setSlots((prev) => prev.map((s, i) => (i === idx ? item : s)));
    setPickerFor(null);
  };

  const forEachVideo = (fn: (v: HTMLVideoElement) => void) => {
    videoRefs.current.forEach((v) => v && fn(v));
  };

  const syncStart = () => {
    forEachVideo((v) => {
      v.currentTime = 0;
      v.playbackRate = speed;
    });
    // play on next tick so seeks settle
    setTimeout(() => forEachVideo((v) => void v.play().catch(() => {})), 50);
  };
  const pauseAll = () => forEachVideo((v) => v.pause());
  const restartAll = () =>
    forEachVideo((v) => {
      v.currentTime = 0;
    });

  const usedIds = useMemo(() => new Set(slots.filter(Boolean).map((s) => s!.id)), [slots]);

  return (
    <div className="mx-auto max-w-[1280px] space-y-5">
      <div>
        <h1 className="font-display text-2xl font-bold">비교 뷰</h1>
        <p className="mt-1 text-sm text-muted-foreground">여러 영상을 나란히 놓고 배속·동시 재생으로 비교하세요.</p>
      </div>

      {/* Controls */}
      <div className="flex flex-wrap items-center gap-3 rounded-xl border border-border bg-card p-3">
        <Segment
          label="열"
          options={[
            { v: 2, label: '2열' },
            { v: 3, label: '3열' },
          ]}
          value={cols}
          onChange={setCols}
        />
        <div className="h-6 w-px bg-border" />
        <Segment
          label="배속"
          options={SPEEDS.map((s) => ({ v: s, label: `${s}x` }))}
          value={speed}
          onChange={setSpeed}
        />
        <div className="ml-auto flex gap-2">
          <Button onClick={syncStart}>
            <Play className="h-4 w-4" /> 동시 시작
          </Button>
          <Button variant="secondary" onClick={pauseAll}>
            <Pause className="h-4 w-4" /> 전체 정지
          </Button>
          <Button variant="secondary" onClick={restartAll}>
            <RotateCcw className="h-4 w-4" /> 처음으로
          </Button>
        </div>
      </div>

      {/* Columns */}
      <div className={cn('grid gap-4', cols === 2 ? 'grid-cols-2' : 'grid-cols-3')}>
        {slots.map((item, idx) => (
          <div key={idx} className="flex flex-col overflow-hidden rounded-xl border border-border bg-card">
            <div className="relative bg-black">
              {item?.play_url ? (
                <video
                  ref={(el) => {
                    videoRefs.current[idx] = el;
                  }}
                  src={item.play_url}
                  controls
                  onLoadedMetadata={(e) => {
                    (e.currentTarget as HTMLVideoElement).playbackRate = speed;
                  }}
                  className="aspect-video w-full"
                />
              ) : (
                <button
                  type="button"
                  onClick={() => setPickerFor(idx)}
                  className="flex aspect-video w-full flex-col items-center justify-center gap-2 text-muted-foreground hover:text-primary"
                >
                  <Plus className="h-7 w-7" />
                  <span className="text-sm">영상 선택</span>
                </button>
              )}
            </div>
            <div className="flex items-center justify-between gap-2 p-3">
              {item ? (
                <>
                  <span className="flex min-w-0 items-center gap-1.5 text-sm">
                    {item.kind === 'original' ? (
                      <Film className="h-3.5 w-3.5 shrink-0 text-muted-foreground" />
                    ) : (
                      <Sparkles className="h-3.5 w-3.5 shrink-0 text-primary" />
                    )}
                    <span className="truncate" title={item.title}>
                      {item.title}
                    </span>
                  </span>
                  <div className="flex shrink-0 gap-1">
                    <Button variant="secondary" size="sm" onClick={() => setPickerFor(idx)}>
                      변경
                    </Button>
                    <Button variant="ghost" size="icon" aria-label="제거" onClick={() => setSlot(idx, null)}>
                      <X className="h-4 w-4" />
                    </Button>
                  </div>
                </>
              ) : (
                <span className="text-sm text-muted-foreground">열 {idx + 1} — 비어 있음</span>
              )}
            </div>
          </div>
        ))}
      </div>

      {/* Picker */}
      <Modal
        open={pickerFor !== null}
        onClose={() => setPickerFor(null)}
        title="영상 선택"
        description="원본 또는 AI 영상을 이 열에 배치합니다."
      >
        {groups.length === 0 ? (
          <p className="text-sm text-muted-foreground">선택할 영상이 없습니다.</p>
        ) : (
          <div className="max-h-96 space-y-4 overflow-y-auto">
            {groups.map((g) => {
              const usedO = usedIds.has(g.original.id);
              return (
                <div key={g.video.id}>
                  {/* 원본 (그룹 헤더 겸 선택 항목) */}
                  <button
                    type="button"
                    disabled={usedO}
                    onClick={() => pickerFor !== null && setSlot(pickerFor, g.original)}
                    className={cn(
                      'flex w-full items-center gap-2 rounded-md px-3 py-2 text-left text-sm font-medium',
                      usedO ? 'cursor-not-allowed opacity-40' : 'hover:bg-muted',
                    )}
                  >
                    <Film className="h-4 w-4 shrink-0 text-muted-foreground" />
                    <span className="truncate">{g.video.title}</span>
                    <span className="ml-auto shrink-0 text-xs text-muted-foreground">
                      원본{usedO ? ' · 사용중' : ''}
                    </span>
                  </button>

                  {/* 이 원본에서 나온 AI 영상 — 세로선 + 들여쓰기로 소속 표시 */}
                  {g.ai.length > 0 ? (
                    <div className="ml-4 mt-0.5 space-y-0.5 border-l border-border pl-3">
                      {g.ai.map(({ item, promptTitle }) => {
                        const used = usedIds.has(item.id);
                        return (
                          <button
                            key={item.id}
                            type="button"
                            disabled={used}
                            onClick={() => pickerFor !== null && setSlot(pickerFor, item)}
                            className={cn(
                              'flex w-full items-center gap-2 rounded-md px-3 py-1.5 text-left text-sm',
                              used ? 'cursor-not-allowed opacity-40' : 'hover:bg-muted',
                            )}
                          >
                            <Sparkles className="h-3.5 w-3.5 shrink-0 text-primary" />
                            <span className="max-w-[45%] truncate">{item.title}</span>
                            <span className="truncate text-xs text-muted-foreground">· {promptTitle}</span>
                            <span className="ml-auto shrink-0 text-xs text-muted-foreground">
                              AI{used ? ' · 사용중' : ''}
                            </span>
                          </button>
                        );
                      })}
                    </div>
                  ) : (
                    <div className="ml-4 border-l border-border py-1 pl-3 text-xs text-muted-foreground">
                      아직 AI 영상 없음
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </Modal>
    </div>
  );
}

function Segment<T extends number>({
  label,
  options,
  value,
  onChange,
}: {
  label: string;
  options: { v: T; label: string }[];
  value: T;
  onChange: (v: T) => void;
}) {
  return (
    <div className="flex items-center gap-2">
      <span className="text-sm text-muted-foreground">{label}</span>
      <div className="flex rounded-md border border-border p-0.5">
        {options.map((o) => (
          <button
            key={o.label}
            type="button"
            onClick={() => onChange(o.v)}
            className={cn(
              'rounded px-3 py-1 text-sm transition-colors',
              value === o.v ? 'bg-primary text-primary-foreground' : 'text-muted-foreground hover:text-foreground',
            )}
          >
            {o.label}
          </button>
        ))}
      </div>
    </div>
  );
}
