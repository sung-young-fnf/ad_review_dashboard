#!/usr/bin/env python3
"""
Task 의존성 순환 검증 및 최적 순서 제안
사용법: python validate-task-deps.py <tasks_dir>
"""

import sys
import re
from pathlib import Path
from typing import Dict, List, Set, Tuple

# Color codes
RED = '\033[0;31m'
YELLOW = '\033[1;33m'
GREEN = '\033[0;32m'
NC = '\033[0m'  # No Color


def extract_task_id(file_path: str) -> str:
    """Task 파일에서 Task ID 추출"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Task ID: T101 형식 찾기
    match = re.search(r'Task ID:\s*(T\d+)', content)
    if match:
        return match.group(1)

    # # T101: 형식
    match = re.search(r'^#\s*(T\d+)', content, re.MULTILINE)
    if match:
        return match.group(1)

    # 파일명에서 추출 (T101_*.md)
    filename = Path(file_path).name
    match = re.search(r'(T\d+)', filename)
    if match:
        return match.group(1)

    return Path(file_path).stem


def extract_dependencies(file_path: str) -> List[str]:
    """Task 파일에서 의존성 추출"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Dependencies 섹션 찾기
    deps_patterns = [
        r'## Dependencies\n(.*?)(?:\n##|\n\n\n|$)',
        r'\*\*Dependencies\*\*[:\s]+(.*?)(?:\n##|\n\n|$)',
        r'의존성[:\s]+(.*?)(?:\n##|\n\n|$)',
    ]

    for pattern in deps_patterns:
        deps_section = re.search(pattern, content, re.DOTALL | re.IGNORECASE)
        if deps_section:
            deps_text = deps_section.group(1)
            deps = re.findall(r'T\d+', deps_text)
            return list(set(deps))  # 중복 제거

    # 본문에서 "Requires: T101" 패턴 찾기
    requires = re.findall(r'Requires?[:\s]+T\d+', content, re.IGNORECASE)
    if requires:
        deps = []
        for req in requires:
            match = re.search(r'T\d+', req)
            if match:
                deps.append(match.group(0))
        return list(set(deps))

    return []


def build_dependency_graph(tasks_dir: str) -> Dict[str, List[str]]:
    """의존성 그래프 구성"""
    tasks_path = Path(tasks_dir)

    if not tasks_path.exists():
        print(f"❌ Tasks 디렉토리 없음: {tasks_dir}")
        sys.exit(1)

    graph = {}
    task_files = list(tasks_path.glob('T*.md'))

    if not task_files:
        task_files = list(tasks_path.glob('**/T*.md'))

    for task_file in sorted(task_files):
        task_id = extract_task_id(str(task_file))
        deps = extract_dependencies(str(task_file))
        graph[task_id] = deps

    return graph


def detect_cycle(graph: Dict[str, List[str]], node: str, visited: Set[str], stack: Set[str]) -> Tuple[bool, List[str]]:
    """DFS로 순환 의존성 검증"""
    visited.add(node)
    stack.add(node)

    for dep in graph.get(node, []):
        # 의존하는 Task가 존재하는지 확인
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
        tasks_dir = '.'
    else:
        tasks_dir = sys.argv[1]

    print("🔍 Task 의존성 검증...")

    # 의존성 그래프 구성
    graph = build_dependency_graph(tasks_dir)

    if not graph:
        print(f"{YELLOW}⚠️ Task 파일 없음{NC}")
        sys.exit(0)

    print(f"  발견: {len(graph)}개 Task")

    # 순환 의존성 검증
    visited = set()
    has_any_cycle = False

    for task in sorted(graph.keys()):
        if task not in visited:
            has_cycle, cycle_path = detect_cycle(graph, task, visited, set())
            if has_cycle:
                print(f"{RED}❌ P0: 순환 의존성 발견!{NC}")
                print(f"  경로: {' → '.join(cycle_path)}")
                has_any_cycle = True

    if has_any_cycle:
        print("")
        print("해결 방법:")
        print("  1. 의존성 재구성 (순환 끊기)")
        print("  2. Task 병합 (순환하는 Task를 하나로)")
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

    # 병렬 실행 가능한 Task 찾기
    parallel_groups = []
    remaining = set(order)
    completed = set()

    while remaining:
        # 현재 단계에서 실행 가능한 Task (의존성이 모두 완료됨)
        current_phase = []
        for task in sorted(remaining):
            deps = graph.get(task, [])
            if all(dep in completed for dep in deps):
                current_phase.append(task)

        if not current_phase:
            # 순환이 없으면 여기에 도달하지 않음
            break

        parallel_groups.append(current_phase)
        for task in current_phase:
            remaining.remove(task)
            completed.add(task)

    if len(parallel_groups) > 1:
        print("🚀 병렬 실행 가능한 그룹:")
        for i, group in enumerate(parallel_groups, 1):
            print(f"  Phase {i}: {', '.join(group)}")
        print("")


if __name__ == '__main__':
    main()
