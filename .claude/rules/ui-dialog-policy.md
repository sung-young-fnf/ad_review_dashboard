## UI Dialog Policy — Native dialog 금지 (MANDATORY)

> WHY: `window.alert/prompt/confirm` 은 (1) UX 가 1980 년대 수준 — 디자인 통일 불가, (2) 브라우저 포커스 강제 탈취로 디버깅·자동화·Playwright 테스트 차단, (3) 모바일/임베드 환경에서 동작 불일치, (4) i18n / a11y 통제 불가, (5) 여러 dialog 가 stack 되면 모달 dismiss 순서 강제로 UX 마비.
> 즉, 한 번 사용하면 운영 중 누적되어 전체 앱이 native dialog 의존 상태가 됨. 신규 서비스 시작부터 금지.

### 금지

- ❌ `window.alert(...)` / `alert(...)` 호출
- ❌ `window.confirm(...)` / `confirm(...)` 호출
- ❌ `window.prompt(...)` / `prompt(...)` 호출
- ❌ `<form onSubmit>` 안에서 native dialog 로 user input 받기

### 권장

- ✅ Headless UI / shadcn-ui `<Dialog>` 또는 자체 React 모달 컴포넌트
- ✅ `useState` 로 modal open + form input + confirm/cancel 버튼
- ✅ toast / sonner / react-hot-toast 로 비-blocking 알림 (alert 대체)
- ✅ inline 에러 + 인풋 컴포넌트로 prompt 대체 (e.g., share-link form: 만료/비번/제한 모두 한 모달의 필드)
- ✅ `<dialog>` HTML element 도 OK (modal show/showModal API) — 단 native chrome dialog 와 다른 점 명확히 (자체 디자인 가능)

### 마이그레이션 패턴 (가장 흔한 사례)

#### 1. 단순 알림 (alert 대체) → toast

```tsx
// ❌
alert('저장됨');

// ✅
import { toast } from 'sonner';  // 또는 react-hot-toast
toast.success('저장됨');
```

#### 2. 확인 (confirm 대체) → ConfirmDialog 컴포넌트

```tsx
// ❌
if (!confirm('정말 삭제할까요?')) return;
await deleteItem(id);

// ✅
const [confirming, setConfirming] = useState<{ open: boolean; id?: string }>({ open: false });
// ...
<button onClick={() => setConfirming({ open: true, id })}>삭제</button>

<ConfirmDialog
  open={confirming.open}
  title="정말 삭제할까요?"
  description="복구 불가합니다."
  confirmLabel="삭제"
  variant="danger"
  onConfirm={async () => { await deleteItem(confirming.id!); setConfirming({ open: false }); }}
  onCancel={() => setConfirming({ open: false })}
/>
```

#### 3. 입력 (prompt 대체) → Form 모달

```tsx
// ❌ (여러 prompt 연속 호출 시 사용자 포커스 탈취)
const days = prompt('만료까지 며칠?');
const password = prompt('비밀번호:');
const limit = prompt('다운로드 제한:');
// ... API 호출

// ✅ 한 모달의 필드로 통합
<ShareLinkDialog
  open={dialogOpen}
  onClose={() => setDialogOpen(false)}
  onSubmit={async ({ days, password, downloadLimit }) => {
    await createShareLink({ days, password, downloadLimit });
    toast.success('공유 링크 생성됨');
    setDialogOpen(false);
  }}
/>
```

### 공용 컴포넌트 권장 (mono-starter 표준)

신규 서비스가 알아서 만들지 않도록, 공용 패턴을 한곳에 모아라:

```
apps/{app}/frontend/src/components/ui/
├── ConfirmDialog.tsx       # 확인/취소 — variant: 'default' | 'danger'
├── FormDialog.tsx           # 일반 form 모달 (children 으로 필드 전달)
└── (toast 는 root layout 에 <Toaster /> 1회 mount)
```

각 컴포넌트는:
- 닫기 = ESC + 외부 click + X 버튼 모두 동작
- 포커스 trap (모달 안에서만 tab)
- a11y: `role="dialog"` + `aria-labelledby` + `aria-describedby`
- 키보드: Enter = confirm, ESC = cancel

### Playwright / 자동화 영향

native dialog 가 떠 있으면 `evaluate` / `click` / `navigate` 모두 차단됨 (`Tool "browser_evaluate" does not handle the modal state`). 자동 회귀 테스트가 native dialog 만나면 멈춤. custom modal 은 평범한 DOM 이라 selector 로 정상 조작 가능.

### 코드 리뷰 체크리스트

PR 제출 전 자가 점검 (`git diff` 에 추가된 라인 기준):

- [ ] `alert(` 미사용
- [ ] `confirm(` 미사용
- [ ] `prompt(` 미사용
- [ ] `window.alert` / `window.confirm` / `window.prompt` 미사용
- [ ] 새 비동기 작업 결과 알림은 toast (또는 inline status)
- [ ] 새 destructive 작업은 ConfirmDialog
- [ ] 새 multi-field input 은 FormDialog (prompt 연속 호출 패턴 금지)

### 예외

- 개발 중 임시 디버그 (`alert(JSON.stringify(...))` 같은 console.log 대용) — **commit 전 반드시 제거**
- 임시 mock 화면 (실 제품 아닌 데모 prototype) — 단 `// TODO: replace native dialog before ship` 주석 필수

### 자동 검증 (선택)

`eslint-plugin-no-restricted-globals` 또는 자체 lint rule 로 차단 가능:

```js
// .eslintrc
{
  "rules": {
    "no-alert": "error",  // alert / confirm / prompt 일괄 차단
    "no-restricted-globals": ["error", "alert", "confirm", "prompt"]
  }
}
```

### Lifecycle

- **Lifecycle**: STABLE (mono-starter 초기 규칙)
- **Confidence**: 1.0 (사용자 명시 요청 + 자동화 차단 직접 경험)
- **Last-Active**: 2026-05-18

❌ 신규 코드에 native dialog 추가 = VIOLATION
❌ "잠깐만 쓸 prompt" 명분 commit = VIOLATION (잠깐이 영구가 됨)
