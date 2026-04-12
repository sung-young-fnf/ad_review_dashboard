#!/bin/bash
# Next.js API Proxy 패턴 검증
# Backend에 있는 HTTP 메서드가 Frontend proxy에도 있는지 확인
# 사용법: ./validate-nextjs-proxy.sh

set -euo pipefail

WORKSPACE_ROOT="$(git rev-parse --show-toplevel)"

# Color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "🔍 Next.js API Proxy 패턴 검증 시작..."

# 1. 변경된 파일 목록
CHANGED_FILES=$(git diff --name-only HEAD~1 2>/dev/null || git diff --cached --name-only)

if [ -z "$CHANGED_FILES" ]; then
  echo "⚠️ 변경된 파일 없음"
  exit 0
fi

ISSUES=()

# 2. Backend Controller 분석
echo "📋 Backend Controller 분석..."

CONTROLLER_FILES=$(echo "$CHANGED_FILES" | grep -E "backend.*\.controller\.ts$" || true)

if [ -z "$CONTROLLER_FILES" ]; then
  echo "✅ 변경된 Controller 파일 없음"
  exit 0
fi

declare -A BACKEND_ENDPOINTS

while IFS= read -r controller_file; do
  if [ -f "$controller_file" ]; then
    echo "  분석: $controller_file"

    # @Controller 경로 추출
    controller_path=$(grep "@Controller" "$controller_file" | sed "s/@Controller('\(.*\)')/\1/" | tr -d "'" | tr -d '"' || true)

    # HTTP 메서드 데코레이터 추출
    methods=$(grep -E "@(Get|Post|Put|Delete|Patch)" "$controller_file" || true)

    while IFS= read -r method_line; do
      if [[ $method_line =~ @(Get|Post|Put|Delete|Patch)(\([\'\"]([^\'\"]*)[\'\"]\))? ]]; then
        http_method="${BASH_REMATCH[1]}"
        endpoint_path="${BASH_REMATCH[3]}"

        # 전체 경로 생성
        if [ -z "$endpoint_path" ]; then
          full_path="/$controller_path"
        else
          full_path="/$controller_path/$endpoint_path"
        fi

        # 정규화
        full_path=$(echo "$full_path" | sed 's#//#/#g' | sed 's#/$##')

        BACKEND_ENDPOINTS["$full_path"]+="$http_method "
        echo "    - $http_method $full_path"
      fi
    done <<< "$methods"
  fi
done <<< "$CONTROLLER_FILES"

# 3. Frontend API Proxy 확인
echo ""
echo "🔍 Frontend API Proxy 확인..."

# Backend Controller와 매칭되는 Frontend proxy 경로 찾기
for endpoint in "${!BACKEND_ENDPOINTS[@]}"; do
  methods="${BACKEND_ENDPOINTS[$endpoint]}"

  # /api/services/[id] 형태로 변환
  proxy_pattern=$(echo "$endpoint" | sed 's#/api/##' | sed 's#:\([a-zA-Z_]*\)#[\\1]#g')

  # Frontend proxy 파일 찾기
  proxy_file=$(find apps/*/frontend/src/app/api -path "*$proxy_pattern/route.ts" 2>/dev/null | head -1 || true)

  if [ -z "$proxy_file" ]; then
    # Proxy 파일 자체가 없음 (경고만)
    ISSUES+=("🟡 P1: Frontend proxy 파일 없음: $endpoint")
    continue
  fi

  echo "  확인: $proxy_file"

  # Frontend proxy에 있는 HTTP 메서드 확인
  frontend_methods=$(grep -E "export async function (GET|POST|PUT|DELETE|PATCH)" "$proxy_file" | \
                     sed 's/export async function \([A-Z]*\).*/\1/' || true)

  # Backend에는 있지만 Frontend에 없는 메서드 찾기
  for method in $methods; do
    method_upper=$(echo "$method" | tr '[:lower:]' '[:upper:]')

    if ! echo "$frontend_methods" | grep -q "$method_upper"; then
      ISSUES+=("🟡 P1: $proxy_file - $method_upper 메서드 누락 (Backend에는 있음)")

      # 과거 사례 검색
      past_case=$(git log --all --oneline --grep="proxy.*$method_upper\|API.*누락" -- "$proxy_file" -5 | head -1 || true)
      if [ -n "$past_case" ]; then
        ISSUES+=("   과거 사례: $past_case")
      fi
    fi
  done
done

# 4. 결과 출력
echo ""
echo "═══════════════════════════════════════"
if [ ${#ISSUES[@]} -eq 0 ]; then
  echo -e "${GREEN}✅ Next.js Proxy 패턴 검증 완료 - 문제 없음${NC}"
  exit 0
else
  echo -e "${YELLOW}⚠️ 문제 발견 (${#ISSUES[@]}개):${NC}"
  printf '%s\n' "${ISSUES[@]}"
  echo ""
  echo "권장: Frontend proxy에 누락된 메서드 추가"
  exit 1
fi
