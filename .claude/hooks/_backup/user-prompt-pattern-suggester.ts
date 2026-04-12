#!/usr/bin/env npx tsx

/**
 * User Prompt Pattern Suggester
 *
 * Showcase 패턴: skill-activation-prompt.ts 참조
 * 사용자 프롬프트 분석 → 과거 Epic 패턴 매칭 → Story 템플릿 주입
 */

import * as fs from 'fs-extra';
import * as path from 'path';

// Project root
const PROJECT_ROOT = process.env.CLAUDE_PROJECT_DIR || process.cwd();
const STATE_FILE = path.join(PROJECT_ROOT, 'docs', '.state', 'PROJECT_STATE.json');

// Pattern 정의
interface PatternDefinition {
  name: string;
  keywords: string[];
  intentPatterns: RegExp[];
  storyTemplate: string[];
  epicExamples?: string[];  // 유사한 과거 Epic IDs
}

const PATTERNS: PatternDefinition[] = [
  {
    name: 'CRUD',
    keywords: ['추가', '생성', '관리', '목록', '등록', 'CRUD', '게시판', '댓글', '팀', '파일'],
    intentPatterns: [
      /(.+)\s+(추가|생성|관리|등록)/,
      /(.+)\s+시스템/,
      /(.+)\s+기능/,
    ],
    storyTemplate: [
      'S01: DB Schema + Backend API',
      'S02: UI List/Table Component',
      'S03: Form Component (Create/Update)',
      'S04: Real-time Updates / Pagination',
    ],
  },
  {
    name: 'Admin Dashboard',
    keywords: ['관리자', '대시보드', '통계', '모니터링', 'admin', 'dashboard'],
    intentPatterns: [
      /관리자\s+(.+)/,
      /(.+)\s+대시보드/,
      /(.+)\s+통계/,
    ],
    storyTemplate: [
      'S01: Admin Table Component',
      'S02: Filter & Search UI',
      'S03: Bulk Actions (Delete/Update)',
      'S04: Pagination & Sorting',
    ],
  },
  {
    name: 'Authentication',
    keywords: ['로그인', '인증', '권한', '회원가입', '사용자', 'auth', 'login', 'signup'],
    intentPatterns: [
      /(.+)\s+(로그인|인증|권한)/,
      /회원가입/,
      /(사용자|유저)\s+관리/,
    ],
    storyTemplate: [
      'S01: JWT Token System',
      'S02: Auth Middleware & Guards',
      'S03: Login/Signup UI',
      'S04: Session Management',
    ],
  },
  {
    name: 'Integration',
    keywords: ['연동', '통합', 'API', '외부', '서비스', 'integration'],
    intentPatterns: [
      /(.+)\s+(연동|통합)/,
      /외부\s+(.+)/,
      /(.+)\s+API\s+(.+)/,
    ],
    storyTemplate: [
      'S01: External API Client',
      'S02: Data Transformation Layer',
      'S03: Error Handling & Retry',
      'S04: Integration Testing',
    ],
  },
];

// Main logic
async function main() {
  // Read stdin
  const stdinBuffer: Buffer[] = [];
  for await (const chunk of process.stdin) {
    stdinBuffer.push(chunk);
  }

  const input = Buffer.concat(stdinBuffer).toString('utf-8');
  let hookData: any;

  try {
    hookData = JSON.parse(input);
  } catch (e) {
    console.error('Failed to parse stdin as JSON');
    process.exit(0);
  }

  const userPrompt = hookData.prompt || '';

  if (!userPrompt) {
    process.exit(0);
  }

  // Analyze prompt
  const matchedPatterns: {
    pattern: PatternDefinition;
    score: number;
    matchedKeywords: string[];
  }[] = [];

  for (const pattern of PATTERNS) {
    let score = 0;
    const matchedKeywords: string[] = [];

    // Keyword matching
    for (const keyword of pattern.keywords) {
      if (userPrompt.includes(keyword)) {
        score += 10;
        matchedKeywords.push(keyword);
      }
    }

    // Intent pattern matching
    for (const intentRegex of pattern.intentPatterns) {
      if (intentRegex.test(userPrompt)) {
        score += 20;
      }
    }

    if (score > 0) {
      matchedPatterns.push({ pattern, score, matchedKeywords });
    }
  }

  // Sort by score
  matchedPatterns.sort((a, b) => b.score - a.score);

  // If no patterns matched, exit silently
  if (matchedPatterns.length === 0) {
    process.exit(0);
  }

  // Get top pattern
  const topMatch = matchedPatterns[0];

  // Load past Epic examples (optional)
  let pastEpicInfo = '';
  if (await fs.pathExists(STATE_FILE)) {
    try {
      const state = await fs.readJson(STATE_FILE);
      const completedEpics = Object.entries(state.epics || {})
        .filter(([, epic]: [string, any]) => epic.status === 'COMPLETED')
        .slice(0, 3);

      if (completedEpics.length > 0) {
        pastEpicInfo = `\n📚 Similar completed Epics in your project:\n`;
        completedEpics.forEach(([id, epic]: [string, any]) => {
          pastEpicInfo += `  - ${id}: ${epic.title}\n`;
        });
      }
    } catch (e) {
      // Ignore errors
    }
  }

  // Output suggestion to stdout (injected to Claude)
  console.log(`
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎯 ${topMatch.pattern.name} PATTERN DETECTED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 Matched keywords: ${topMatch.matchedKeywords.join(', ')}
📊 Confidence: ${topMatch.score > 30 ? 'High' : topMatch.score > 15 ? 'Medium' : 'Low'}

💡 Suggested Story Structure:
${topMatch.pattern.storyTemplate.map((s, i) => `  ${i + 1}. ${s}`).join('\n')}${pastEpicInfo}

🚀 RECOMMENDATION:
This pattern matches the ${topMatch.pattern.name} workflow. Consider using story-creator with this structure.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
`);

  process.exit(0);
}

main();
