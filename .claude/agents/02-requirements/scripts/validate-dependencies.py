#!/usr/bin/env python3
"""
Story 의존성 순환 검증 및 최적 순서 제안
사용법: python validate-dependencies.py <epic_dir>
"""

import sys
import re
import glob
from pathlib import Path
from typing import Dict, List, Set, Tuple

# Color codes
RED = '\033[0;31m'
YELLOW = '\033[1;33m'
GREEN = '\033[0;32m'
NC = '\033[0m'  # No Color


def extract_story_id(file_path: str) -> str:
    """Story 파일에서 Story ID 추출"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Story ID: S01 형식 찾기
    match = re.search(r'Story ID:\s*(S\d+)', content)
    if match:
        return match.group(1)

    # 파일명에서 추출 (S01_*.md)
    filename = Path(file_path).name
    match = re.search(r'(S\d+)', filename)
    if match:
        return match.group(1)

    return Path(file_path).stem


def extract_dependencies(file_path: str) -> List[str]:
    """Story 파일에서 의존성 추출"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Dependencies 섹션 찾기
    deps_section = re.search(r'## Dependencies\n(.*?)\n##', content, re.DOTALL)
    if not deps_section:
        return []

    # S01, S02 형식의 의존성 찾기
    deps_text = deps_section.group(1)
    deps = re.findall(r'S\d+', deps_text)

    return list(set(deps))  # 중복 제거


def build_dependency_graph(epic_dir: str) -> Dict[str, List[str]]:
    """의존성 그래프 구성"""
    stories_dir = Path(epic_dir) / 'stories'

    if not stories_dir.exists():
        print(f"❌ Stories 디렉토리 없음: {stories_dir}")
        sys.exit(1)

    graph = {}

    for story_file in sorted(stories_dir.glob('*.md')):
        story_id = extract_story_id(str(story_file))
        deps = extract_dependencies(str(story_file))
        graph[story_id] = deps

    return graph


def detect_cycle(graph: Dict[str, List[str]], node: str, visited: Set[str], stack: Set[str]) -> Tuple[bool, List[str]]:
    """DFS로 순환 의존성 검증"""
    visited.add(node)
    stack.add(node)

    for dep in graph.get(node, []):
        # 의존하는 Story가 존재하는지 확인
        if dep not in graph:
            print(f"{RED}❌ P0: {node} - 존재하지 않는 의존성: {dep}{NC}")
            return True, [node, dep]

        if dep not in visited:
            has_cycle, cycle_path = detect_cycle(graph, dep, visited, stack)
            if has_cycle:
                return True, [node] + cycle_path
        elif dep in stack:
            # 순환 발견!
            return True, [node, dep]

    stack.remove(node)
    return False, []


def topological_sort(graph: Dict[str, List[str]]) -> List[str]:
    """위상 정렬로 최적 실행 순서 제안"""
    in_degree = {node: 0 for node in graph}

    # in-degree 계산
    for node in graph:
        for dep in graph[node]:
            if dep in in_degree:
                in_degree[dep] += 1

    # in-degree가 0인 노드부터 시작
    queue = [node for node in graph if in_degree[node] == 0]
    result = []

    while queue:
        # 정렬하여 일관성 유지
        queue.sort()
        node = queue.pop(0)
        result.append(node)

        # 이 노드에 의존하는 노드들의 in-degree 감소
        for other_node in graph:
            if node in graph[other_node]:
                in_degree[other_node] -= 1
                if in_degree[other_node] == 0:
                    queue.append(other_node)

    return result


def main():
    if len(sys.argv) < 2:
        epic_dir = '.'
    else:
        epic_dir = sys.argv[1]

    print("🔍 Story 의존성 검증...")

    # 의존성 그래프 구성
    graph = build_dependency_graph(epic_dir)

    if not graph:
        print(f"{YELLOW}⚠️ Story 파일 없음{NC}")
        sys.exit(0)

    print(f"  발견: {len(graph)}개 Story")

    # 순환 의존성 검증
    visited = set()
    has_any_cycle = False

    for story in sorted(graph.keys()):
        if story not in visited:
            has_cycle, cycle_path = detect_cycle(graph, story, visited, set())
            if has_cycle:
                print(f"{RED}❌ P0: 순환 의존성 발견!{NC}")
                print(f"  경로: {' → '.join(cycle_path)}")
                has_any_cycle = True

    if has_any_cycle:
        print("")
        print("해결 방법:")
        print("  1. 의존성 재구성 (순환 끊기)")
        print("  2. Story 병합 (순환하는 Story를 하나로)")
        sys.exit(1)

    # 최적 순서 제안
    order = topological_sort(graph)

    print("")
    print("═══════════════════════════════════════")
    print(f"{GREEN}✅ 의존성 검증 완료 - 순환 없음{NC}")
    print("")
    print("💡 권장 실행 순서:")
    print(f"  {' → '.join(order)}")
    print("")

    # 병렬 실행 가능한 Story 찾기
    parallel_groups = []
    current_group = [order[0]] if order else []

    for i in range(1, len(order)):
        story = order[i]
        deps = graph[story]

        # 현재 그룹의 모든 Story가 이 Story의 의존성에 없으면 병렬 가능
        if not any(s in deps for s in current_group):
            current_group.append(story)
        else:
            parallel_groups.append(current_group)
            current_group = [story]

    if current_group:
        parallel_groups.append(current_group)

    if len(parallel_groups) > 1:
        print("🚀 병렬 실행 가능한 그룹:")
        for i, group in enumerate(parallel_groups, 1):
            print(f"  Phase {i}: {', '.join(group)}")
        print("")


if __name__ == '__main__':
    main()
