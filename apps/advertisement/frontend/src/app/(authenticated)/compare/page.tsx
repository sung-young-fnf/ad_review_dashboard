'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import { Play, Pause, RotateCcw, X, Plus, Film, Sparkles } from 'lucide-react';
import { apiGet } from '@/lib/api';
import type { Video, GeneratedVideo } from '@/lib/types';
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

const SPEEDS = [1, 0.5, 0.3];

export default function ComparePage() {
  const [cols, setCols] = useState(2);
  const [speed, setSpeed] = useState(1);
  const [slots, setSlots] = useState<(Item | null)[]>([null, null]);
  const [items, setItems] = useState<Item[]>([]);
  const [pickerFor, setPickerFor] = useState<number | null>(null);

  const videoRefs = useRef<(HTMLVideoElement | null)[]>([]);

  // load selectable items (originals + generated)
  useEffect(() => {
    Promise.all([apiGet<Video[]>('/videos'), apiGet<GeneratedVideo[]>('/generated-videos')])
      .then(([videos, gens]) => {
        const merged: Item[] = [
          ...videos.map((v) => ({ id: v.id, kind: 'original' as const, title: v.title, play_url: v.play_url })),
          ...gens.map((g) => ({ id: g.id, kind: 'generated' as const, title: g.title, play_url: g.play_url })),
        ];
        setItems(merged);
      })
      .catch((e) => toast.error(`목록 로드 실패: ${e.message}`));
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
        {items.length === 0 ? (
          <p className="text-sm text-muted-foreground">선택할 영상이 없습니다.</p>
        ) : (
          <div className="max-h-96 space-y-1 overflow-y-auto">
            {items.map((it) => {
              const used = usedIds.has(it.id);
              return (
                <button
                  key={`${it.kind}-${it.id}`}
                  type="button"
                  disabled={used}
                  onClick={() => pickerFor !== null && setSlot(pickerFor, it)}
                  className={cn(
                    'flex w-full items-center gap-2 rounded-md px-3 py-2 text-left text-sm',
                    used ? 'cursor-not-allowed opacity-40' : 'hover:bg-muted',
                  )}
                >
                  {it.kind === 'original' ? (
                    <Film className="h-4 w-4 shrink-0 text-muted-foreground" />
                  ) : (
                    <Sparkles className="h-4 w-4 shrink-0 text-primary" />
                  )}
                  <span className="truncate">{it.title}</span>
                  <span className="ml-auto shrink-0 text-xs text-muted-foreground">
                    {it.kind === 'original' ? '원본' : 'AI'}
                    {used ? ' · 사용중' : ''}
                  </span>
                </button>
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
