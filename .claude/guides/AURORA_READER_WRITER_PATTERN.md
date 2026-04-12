# Aurora Reader/Writer 분리 패턴 (CQRS Lite)

> 읽기 집중 워크로드에서 Aurora Reader Cluster를 활용한 DB 레벨 분리

## 언제 사용하는가?

- 읽기/쓰기 비율이 80:20 이상일 때
- Redis 캐시 도입 전 단계로 DB 레벨 분리 먼저 적용
- 600+ 동시 사용자 규모에서 Writer DB 병목 발생 시

## 환경변수 설정

```bash
# Writer (기존 - 변경 없음)
DATABASE_URL=postgresql+asyncpg://user:pass@writer-endpoint:5432/mcp_orch

# Reader (추가)
DB_READER_HOST=your-cluster.cluster-ro-xxxxx.region.rds.amazonaws.com
# 또는 전체 URL
DATABASE_READER_URL=postgresql+asyncpg://user:pass@reader-endpoint:5432/mcp_orch
```

## Dependency 함수

| 함수 | 타입 | 용도 | DB 연결 |
|------|------|------|---------|
| `get_read_session()` | Async | 읽기 전용 | Aurora Reader |
| `get_write_session()` | Async | 쓰기 작업 | Aurora Writer |
| `get_read_db()` | Sync | 읽기 전용 | Aurora Reader |
| `get_write_db()` | Sync | 쓰기 작업 | Aurora Writer |
| `get_db()` | Sync | 하위 호환 | Writer |
| `get_session()` | Async | 하위 호환 | Writer |

## 전환 규칙

### ✅ Reader로 전환 (get_read_db / get_read_session)

```python
# 순수 읽기 API
@router.get("/servers")
async def list_servers(db: Session = Depends(get_read_db)):
    return service.list_servers(db)

@router.get("/servers/{id}")
async def get_server(id: str, db: Session = Depends(get_read_db)):
    return service.get_server(db, id)
```

### ❌ Writer 유지 (get_db / get_session)

```python
# 쓰기 작업
@router.post("/servers")
async def create_server(data: ServerCreate, db: Session = Depends(get_db)):
    return service.create_server(db, data)

# 읽기 후 쓰기 (트랜잭션 필요)
@router.patch("/servers/{id}/approve")
async def approve_server(id: str, db: Session = Depends(get_db)):
    server = service.get_server(db, id)  # 읽기
    server.status = "approved"           # 쓰기
    db.commit()
    return server
```

## 변경 범위

| 레이어 | 변경 여부 | 설명 |
|--------|----------|------|
| API Router | ✅ 변경 | Depends 함수만 변경 |
| Service Class | ❌ 유지 | 내부 로직 변경 없음 |
| Repository | ❌ 유지 | DB 세션은 외부에서 주입 |
| Model | ❌ 유지 | 변경 없음 |

## 모니터링

### application_name으로 트래픽 구분

```sql
-- PostgreSQL에서 연결 확인
SELECT application_name, count(*)
FROM pg_stat_activity
WHERE datname = 'mcp_orch'
GROUP BY application_name;

-- 결과
-- mcp-orch         : Writer 연결
-- mcp-orch-reader  : Reader 연결
```

### Datadog 대시보드 쿼리

```
avg:postgresql.connections{application_name:mcp-orch-reader} by {host}
avg:postgresql.connections{application_name:mcp-orch} by {host}
```

## 하위 호환성

- `DATABASE_READER_URL` 미설정 시 자동으로 `DATABASE_URL` 사용
- 기존 `get_db()`, `get_session()` 동작 변경 없음
- 점진적 배포 가능 (환경변수만 추가하면 활성화)

## 관련 파일

- **database.py**: `/apps/mcp-orbit/backend/src/mcp_orch/database.py`
- **Epic**: `docs/epics/EP025_aurora-reader-cluster-separation/`

## Phase 2: Redis 캐시 (부하 증가 시)

Reader만으로 부족할 경우 Redis 캐시 레이어 추가:

```python
# 캐시 우선, 없으면 Reader DB 조회
async def get_servers_cached(db = Depends(get_read_db)):
    cached = await redis.get("marketplace:servers")
    if cached:
        return json.loads(cached)

    servers = service.list_servers(db)
    await redis.setex("marketplace:servers", 300, json.dumps(servers))
    return servers
```
