import { redirect } from 'next/navigation';
import { auth } from '@/lib/auth';
import { DynamicSidebar } from '@/widgets/sidebar';
import { SessionExpiry } from '@/components/session-expiry';

export default async function AuthenticatedLayout({ children }: { children: React.ReactNode }) {
  const session = await auth();

  if (!session) {
    redirect('/login');
  }

  return (
    <div className="flex min-h-screen bg-background">
      <DynamicSidebar userEmail={session.user?.email} />
      <main className="flex-1 overflow-y-auto p-8">{children}</main>
      <SessionExpiry />
    </div>
  );
}
