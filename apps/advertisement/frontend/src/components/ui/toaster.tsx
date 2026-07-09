'use client';
import { Toaster as SonnerToaster, toast } from 'sonner';

export { toast };

export function Toaster() {
  return (
    <SonnerToaster
      position="top-right"
      richColors
      closeButton
      toastOptions={{ style: { fontFamily: 'DM Sans, sans-serif' } }}
    />
  );
}
