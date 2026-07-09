'use client';

import { usePathname } from 'next/navigation';
import Link from 'next/link';
import { Film, LayoutGrid, GitCompare, LogOut } from 'lucide-react';
import { cn } from '@/lib/utils';

const NAV = [
  { href: '/videos', label: '영상 라이브러리', icon: Film },
  { href: '/workspace', label: '워크스페이스', icon: LayoutGrid },
  { href: '/compare', label: '비교 뷰', icon: GitCompare },
];

export function DynamicSidebar({ userEmail }: { userEmail?: string | null }) {
  const pathname = usePathname();

  return (
    <aside className="flex h-screen w-60 shrink-0 flex-col border-r border-border bg-card">
      <div className="flex h-14 items-center gap-2 border-b border-border px-5">
        <span className="font-display text-lg font-bold tracking-tight">advertisement</span>
      </div>

      <nav className="flex-1 space-y-1 overflow-y-auto p-3">
        {NAV.map(({ href, label, icon: Icon }) => {
          const active = pathname === href || pathname.startsWith(href + '/');
          return (
            <Link
              key={href}
              href={href}
              className={cn(
                'flex items-center gap-2.5 rounded-md px-3 py-2 text-sm transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring',
                active
                  ? 'bg-primary/10 font-medium text-primary'
                  : 'text-foreground hover:bg-muted',
              )}
            >
              <Icon className="h-4 w-4 shrink-0" />
              <span>{label}</span>
            </Link>
          );
        })}
      </nav>

      <div className="border-t border-border p-3">
        {userEmail && (
          <div className="truncate px-3 pb-2 text-sm font-medium text-muted-foreground" title={userEmail}>
            {userEmail}
          </div>
        )}
        <a
          href="/api/auth/federated-logout"
          className="flex w-full items-center gap-2.5 rounded-md px-3 py-2 text-sm text-muted-foreground transition-colors hover:bg-muted"
        >
          <LogOut className="h-4 w-4" />
          <span>로그아웃</span>
        </a>
      </div>
    </aside>
  );
}
