'use client';
import { Modal } from './modal';
import { Button } from './button';

interface FormDialogProps {
  open: boolean;
  onClose: () => void;
  title: string;
  description?: string;
  submitLabel?: string;
  loading?: boolean;
  onSubmit: (form: HTMLFormElement) => void;
  children: React.ReactNode;
}

export function FormDialog({
  open,
  onClose,
  title,
  description,
  submitLabel = '저장',
  loading = false,
  onSubmit,
  children,
}: FormDialogProps) {
  return (
    <Modal open={open} onClose={onClose} title={title} description={description}>
      <form
        onSubmit={(e) => {
          e.preventDefault();
          onSubmit(e.currentTarget);
        }}
        className="space-y-4"
      >
        {children}
        <div className="flex justify-end gap-2 pt-1">
          <Button type="button" variant="secondary" onClick={onClose} disabled={loading}>
            취소
          </Button>
          <Button type="submit" disabled={loading}>
            {loading ? '처리 중…' : submitLabel}
          </Button>
        </div>
      </form>
    </Modal>
  );
}
