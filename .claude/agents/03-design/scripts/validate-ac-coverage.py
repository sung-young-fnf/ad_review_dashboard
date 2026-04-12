#!/usr/bin/env python3
"""
Story AC ↔ Task 매핑 커버리지 검증
사용법: python validate-ac-coverage.py <story_file> <tasks_dir>
"""

import sys
import re
from pathlib import Path
from typing import Set, List, Tuple

# Color codes
RED = '\033[0;31m'
YELLOW = '\033[1;33m'
GREEN = '\033[0;32m'
NC = '\033[0m'  # No Color


def extract_story_acs(story_file: str) -> List[Tuple[str, str]]:
    """Story 파일에서 AC 추출 (ID, 설명)"""
    with open(story_file, 'r', encoding='utf-8') as f:
        content = f.read()

    acs = []

    # ### AC1: 형식
    ac_headers = re.findall(r'###\s*(AC\d+):\s*(.+)', content)
    acs.extend(ac_headers)

    # - [ ] AC1: 형식 또는 체크박스 형식
    if not acs:
        checkboxes = re.findall(r'-\s*\[[ x]\]\s*(.+)', content)
        for i, desc in enumerate(checkboxes, 1):
            acs.append((f'AC{i}', desc.strip()))

    return acs


def extract_task_referenced_acs(task_file: str) -> Set[str]:
    """Task 파일에서 참조하는 AC ID 추출"""
    with open(task_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # AC1, AC2 등 패턴 찾기
    referenced = set(re.findall(r'AC\d+', content))

    # "Story AC:" 섹션에서 추출
    ac_section = re.search(r'Story AC[s]?[:\s]+(.+?)(?:\n##|\n\n|$)', content, re.DOTALL | re.IGNORECASE)
    if ac_section:
        section_acs = re.findall(r'AC\d+', ac_section.group(1))
        referenced.update(section_acs)

    return referenced


def extract_task_keywords(task_file: str) -> Set[str]:
    """Task 파일에서 키워드 추출 (AC 매핑 휴리스틱)"""
    with open(task_file, 'r', encoding='utf-8') as f:
        content = f.read().lower()

    # 주요 키워드 추출
    keywords = set()

    # 제목에서 키워드 추출
    title_match = re.search(r'^#\s*T\d+:\s*(.+)', content, re.MULTILINE)
    if title_match:
        title_words = re.findall(r'\b\w+\b', title_match.group(1).lower())
        keywords.update(title_words)

    return keywords


def match_ac_to_task(ac_desc: str, task_keywords: Set[str]) -> bool:
    """AC 설명과 Task 키워드 매칭"""
    ac_words = set(re.findall(r'\b\w+\b', ac_desc.lower()))
    # 중요 키워드 제외 (너무 일반적인 단어)
    stop_words = {'the', 'a', 'an', 'is', 'are', 'be', 'to', 'of', 'and', 'or', 'for', 'in', 'on'}
    ac_words -= stop_words
    task_keywords -= stop_words

    # 교집합이 2개 이상이면 매칭
    overlap = ac_words & task_keywords
    return len(overlap) >= 2


def main():
    if len(sys.argv) < 3:
        print(f"사용법: {sys.argv[0]} <story_file> <tasks_dir>")
        sys.exit(1)

    story_file = sys.argv[1]
    tasks_dir = sys.argv[2]

    print("🔍 Story AC 커버리지 검증...")

    # Story AC 추출
    if not Path(story_file).exists():
        print(f"{YELLOW}⚠️ Story 파일 없음: {story_file}{NC}")
        sys.exit(0)

    story_acs = extract_story_acs(story_file)
    if not story_acs:
        print(f"{YELLOW}⚠️ Story에서 AC를 찾을 수 없음{NC}")
        sys.exit(0)

    print(f"  Story AC: {len(story_acs)}개")

    # Task 파일들에서 AC 참조 수집
    tasks_path = Path(tasks_dir)
    if not tasks_path.exists():
        print(f"{RED}❌ Tasks 디렉토리 없음: {tasks_dir}{NC}")
        sys.exit(1)

    task_files = list(tasks_path.glob('T*.md'))
    if not task_files:
        task_files = list(tasks_path.glob('**/T*.md'))

    if not task_files:
        print(f"{YELLOW}⚠️ Task 파일 없음{NC}")
        sys.exit(0)

    print(f"  Task 파일: {len(task_files)}개")

    # 각 Task에서 참조하는 AC 수집
    covered_acs = set()
    task_keywords_map = {}

    for task_file in task_files:
        referenced = extract_task_referenced_acs(str(task_file))
        covered_acs.update(referenced)
        task_keywords_map[task_file.name] = extract_task_keywords(str(task_file))

    # 명시적 참조가 없으면 휴리스틱 매칭
    story_ac_ids = {ac[0] for ac in story_acs}

    if not covered_acs:
        print("  명시적 AC 참조 없음 → 휴리스틱 매칭...")
        for ac_id, ac_desc in story_acs:
            for task_name, keywords in task_keywords_map.items():
                if match_ac_to_task(ac_desc, keywords):
                    covered_acs.add(ac_id)
                    break

    # 커버리지 계산
    missing_acs = story_ac_ids - covered_acs
    coverage = len(covered_acs & story_ac_ids) / len(story_ac_ids) if story_ac_ids else 1.0

    print("")
    print("═══════════════════════════════════════")

    if coverage >= 1.0:
        print(f"{GREEN}✅ AC 커버리지 100% ({len(story_ac_ids)}/{len(story_ac_ids)} AC){NC}")
        sys.exit(0)

    # 커버리지 미달
    print(f"{RED}🔴 P0: AC 커버리지 {coverage*100:.0f}% ({len(covered_acs & story_ac_ids)}/{len(story_ac_ids)} AC){NC}")
    print("")
    print("누락된 AC:")
    for ac_id, ac_desc in story_acs:
        if ac_id in missing_acs:
            print(f"  ❌ {ac_id}: {ac_desc}")

    print("")
    print("해결 방법:")
    print("  1. 누락된 AC에 대한 Task 추가")
    print("  2. 기존 Task에 AC 참조 명시 (Story AC: AC1, AC2)")

    sys.exit(1)


if __name__ == '__main__':
    main()
