#!/usr/bin/env npx tsx

/**
 * Epic Dependency Graph Validator
 *
 * Stop Event Hook: Epic 간 의존성 검증
 * - 순환 의존성 감지 (DFS Cycle Detection)
 * - 블로킹 체인 분석
 * - Critical Path 계산
 */

import * as fs from 'fs-extra';
import * as path from 'path';

// Project root
const PROJECT_ROOT = process.env.CLAUDE_PROJECT_DIR || process.cwd();
const STATE_FILE = path.join(PROJECT_ROOT, 'docs', '.state', 'PROJECT_STATE.json');

interface Epic {
  id: string;
  title: string;
  status: string;
  dependencies?: string[];
  blockedBy?: string[];
}

// DFS Cycle Detection
function detectCycles(
  epicId: string,
  graph: Map<string, string[]>,
  visited: Set<string>,
  recStack: Set<string>,
  cycles: string[][]
): void {
  visited.add(epicId);
  recStack.add(epicId);

  const neighbors = graph.get(epicId) || [];

  for (const neighbor of neighbors) {
    if (!visited.has(neighbor)) {
      detectCycles(neighbor, graph, visited, recStack, cycles);
    } else if (recStack.has(neighbor)) {
      // Cycle detected
      const cycle = Array.from(recStack);
      const cycleStart = cycle.indexOf(neighbor);
      cycles.push([...cycle.slice(cycleStart), neighbor]);
    }
  }

  recStack.delete(epicId);
}

// Find all cycles in dependency graph
function findAllCycles(graph: Map<string, string[]>): string[][] {
  const visited = new Set<string>();
  const cycles: string[][] = [];

  for (const epicId of graph.keys()) {
    if (!visited.has(epicId)) {
      detectCycles(epicId, graph, visited, new Set(), cycles);
    }
  }

  return cycles;
}

// Find blocking chains (BLOCKED Epics)
function findBlockingChains(epics: Map<string, Epic>): {
  blockedEpic: string;
  chain: string[];
}[] {
  const chains: { blockedEpic: string; chain: string[] }[] = [];

  for (const [epicId, epic] of epics) {
    if (epic.status === 'BLOCKED') {
      const chain: string[] = [epicId];
      let current = epicId;

      // Follow blockedBy chain
      while (true) {
        const currentEpic = epics.get(current);
        if (!currentEpic || !currentEpic.blockedBy || currentEpic.blockedBy.length === 0) {
          break;
        }

        const blocker = currentEpic.blockedBy[0];
        if (chain.includes(blocker)) {
          // Circular reference
          break;
        }

        chain.push(blocker);
        current = blocker;
      }

      if (chain.length > 1) {
        chains.push({ blockedEpic: epicId, chain });
      }
    }
  }

  return chains;
}

// Calculate Critical Path (longest path to completion)
function calculateCriticalPath(epics: Map<string, Epic>): {
  path: string[];
  days: number;
} | null {
  // Simplified: assume each Epic takes same time
  // Real implementation would use Epic.estimatedDays

  const graph = new Map<string, string[]>();
  for (const [epicId, epic] of epics) {
    if (epic.dependencies && epic.dependencies.length > 0) {
      graph.set(epicId, epic.dependencies);
    }
  }

  // Find longest path using DFS
  let longestPath: string[] = [];

  function dfs(epicId: string, path: string[]): void {
    const newPath = [...path, epicId];

    const deps = graph.get(epicId) || [];
    if (deps.length === 0) {
      // Leaf node
      if (newPath.length > longestPath.length) {
        longestPath = newPath;
      }
    } else {
      for (const dep of deps) {
        dfs(dep, newPath);
      }
    }
  }

  for (const epicId of epics.keys()) {
    dfs(epicId, []);
  }

  return {
    path: longestPath.reverse(),
    days: longestPath.length * 5, // Assume 5 days per Epic
  };
}

// Main logic
async function main() {
  // Check if STATE file exists
  if (!(await fs.pathExists(STATE_FILE))) {
    console.log('No PROJECT_STATE.json found. Skipping dependency validation.');
    process.exit(0);
  }

  let state: any;
  try {
    state = await fs.readJson(STATE_FILE);
  } catch (e) {
    console.error('Failed to parse PROJECT_STATE.json');
    process.exit(0);
  }

  const epics = new Map<string, Epic>();

  // Load Epics
  for (const [epicId, epicData] of Object.entries(state.epics || {})) {
    epics.set(epicId, {
      id: epicId,
      ...(epicData as any),
    });
  }

  if (epics.size === 0) {
    console.log('No Epics found. Skipping dependency validation.');
    process.exit(0);
  }

  // Build dependency graph
  const depGraph = new Map<string, string[]>();
  for (const [epicId, epic] of epics) {
    if (epic.dependencies && epic.dependencies.length > 0) {
      depGraph.set(epicId, epic.dependencies);
    }
  }

  // 1. Detect cycles
  const cycles = findAllCycles(depGraph);

  // 2. Find blocking chains
  const blockingChains = findBlockingChains(epics);

  // 3. Calculate critical path
  const criticalPath = calculateCriticalPath(epics);

  // Output results
  console.log(`
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Epic Dependency Analysis Complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Total Epics: ${epics.size}
`);

  if (cycles.length > 0) {
    console.log(`❌ CIRCULAR DEPENDENCIES DETECTED (${cycles.length}):
`);
    cycles.forEach((cycle, i) => {
      console.log(`  ${i + 1}. ${cycle.join(' → ')}`);
    });
    console.log('');
  } else {
    console.log('✅ No circular dependencies\n');
  }

  if (blockingChains.length > 0) {
    console.log(`⚠️  BLOCKING CHAINS DETECTED (${blockingChains.length}):
`);
    blockingChains.forEach((bc, i) => {
      const chain = bc.chain.map(id => {
        const epic = epics.get(id);
        return `${id} (${epic?.status || 'UNKNOWN'})`;
      }).join(' ← ');
      console.log(`  ${i + 1}. ${chain}`);
    });
    console.log('');
  }

  if (criticalPath && criticalPath.path.length > 0) {
    console.log(`📈 Critical Path (${criticalPath.days} days):
`);
    const pathStr = criticalPath.path.map(id => {
      const epic = epics.get(id);
      return `${id}: ${epic?.title || 'Unknown'}`;
    }).join('\n   → ');
    console.log(`   ${pathStr}`);
    console.log('');
  }

  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  process.exit(0);
}

main();
