'use client';

import { useEffect, useState } from 'react';
import { Modal } from '@/components/ui/modal';
import { Button } from '@/components/ui/button';

/**
 * 세션 만료 감지 패널.
 * api.ts 가 401 응답 시 'adv:auth-expired' 이벤트를 발행하면 모달을 띄우고,
 * 확인을 누르면 앱 세션을 정리하고 SSO 로그인 페이지로 이동한다.
 */
export function SessionExpiry() {
  const [open, setOpen] = useState(false);

  useEffect(() => {
    const onExpired = () => setOpen(true);
    window.addEventListener('adv:auth-expired', onExpired);
    return () => window.removeEventListener('adv:auth-expired', onExpired);
  }, []);

  return (
    <Modal
      open={open}
      onClose={() => {}} // 강제 재로그인 — 임의 닫기 불가
      title="세션이 만료되었습니다"
      description="보안을 위해 다시 로그인해 주세요."
      className="max-w-md"
    >
      <div className="flex justify-end">
        <Button
          data-autofocus
          onClick={() => {
            window.location.href = '/api/auth/federated-logout';
          }}
        >
          확인
        </Button>
      </div>
    </Modal>
  );
}
