#!/usr/bin/env python3
"""
OpenAPI 스키마 내보내기 스크립트

FastAPI 앱에서 OpenAPI 3.0+ 스키마를 추출하여 JSON 파일로 저장합니다.
Frontend에서 타입 생성에 사용됩니다.

Usage:
    cd apps/s3gate/backend
    uv run python scripts/export-openapi.py
"""

import json
import sys
from pathlib import Path

backend_dir = Path(__file__).parent.parent
sys.path.insert(0, str(backend_dir / "src"))

OUTPUT_PATH = backend_dir / "openapi.json"


def export_openapi_schema() -> None:
    print("Exporting OpenAPI schema...")

    from s3gate.main import app

    schema = app.openapi()

    with open(OUTPUT_PATH, "w") as f:
        json.dump(schema, f, indent=2, ensure_ascii=False)

    paths_count = len(schema.get("paths", {}))
    schemas_count = len(schema.get("components", {}).get("schemas", {}))

    print(f"✅ OpenAPI schema exported")
    print(f"  Paths: {paths_count}")
    print(f"  Schemas: {schemas_count}")
    print(f"  Output: {OUTPUT_PATH}")


if __name__ == "__main__":
    export_openapi_schema()
