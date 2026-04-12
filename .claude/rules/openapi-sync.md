## OpenAPI 타입 동기화 (Backend DTO 변경 시 필수)

### FastAPI
```bash
cd apps/{app}/backend
uv run python scripts/export-openapi.py
cd ../frontend
pnpm generate:api
```

### NestJS (서버 실행 중이어야 함)
```bash
cd apps/{app}/backend
./scripts/export-openapi.sh
cd ../frontend
pnpm generate:api
```

### Frontend에서 타입 사용
```typescript
import type { components } from '@/types/generated/api';
type CreateExampleDto = components['schemas']['CreateExampleDto'];
```

❌ Backend DTO 변경 후 openapi.json 미갱신 = VIOLATION
❌ Frontend에서 수동 타입 정의 (generated 타입 존재 시) = VIOLATION
