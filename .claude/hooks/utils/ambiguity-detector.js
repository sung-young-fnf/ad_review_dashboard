#!/usr/bin/env node
/**
 * Ambiguity Detection Engine
 *
 * YAGNI 원칙: 간단한 키워드 매칭으로 시작
 * - ML 모델, 자연어 처리 등 복잡한 기능은 나중에
 * - 80% 정확도면 충분
 *
 * 패턴 재사용:
 * - risk-detector.sh의 키워드 카테고리 분류
 * - user-prompt-submit.ts의 인텐트 분석 로직
 */
// ============================================
// Keyword Mappings (재사용: risk-detector.sh)
// ============================================
const CLEAR_KEYWORDS = [
    '버그 수정',
    'bug fix',
    'API 추가',
    'add API',
    'endpoint',
    '화면 추가',
    'add screen',
    'component',
    'UI 개선',
    'refactor',
];
const AMBIGUOUS_KEYWORDS = [
    '개선',
    'improve',
    '최적화',
    'optimize',
    '확장',
    'extend',
    '업데이트',
    'update',
    '수정',
    'modify',
];
const EPIC_LEVEL_KEYWORDS = [
    '새로운 시스템',
    'new system',
    '플랫폼',
    'platform',
    '아키텍처',
    'architecture',
    '대규모',
    'large-scale',
    '인증 시스템',
    'auth system',
];
const DB_KEYWORDS = [
    'schema',
    'migration',
    'database',
    'Alembic',
    'Prisma',
    'DDL',
    'ALTER TABLE',
    '스키마',
    '마이그레이션',
    'DB',
];
const COMPLEXITY_INDICATORS = {
    db_ui_api: ['DB', 'UI', 'API'],
    integration: ['통합', '연동', 'integration', 'connect'],
    multi_feature: ['여러', 'multiple', '다수', 'various'],
};
// ============================================
// Confidence Calculation
// ============================================
function calculateConfidence(prompt, analysis) {
    let score = 100;
    // 1. 명확한 키워드 매칭 (+10점 per match)
    const clearMatches = CLEAR_KEYWORDS.filter((kw) => prompt.toLowerCase().includes(kw.toLowerCase()));
    score += clearMatches.length * 10;
    // 2. 모호한 키워드 페널티 (-20점 per match)
    const ambiguousMatches = AMBIGUOUS_KEYWORDS.filter((kw) => prompt.toLowerCase().includes(kw.toLowerCase()));
    score -= ambiguousMatches.length * 20;
    // 3. Intent 명확성 (+20점)
    if (analysis.intent && analysis.intent !== 'unknown') {
        score += 20;
    }
    else {
        score -= 30;
    }
    // 4. Domain 명확성 (+20점)
    if (analysis.domain && analysis.domain !== 'general') {
        score += 20;
    }
    else {
        score -= 30;
    }
    // 5. Epic 수준 키워드 감지 (-10점, 복잡도 높음)
    const epicMatches = EPIC_LEVEL_KEYWORDS.filter((kw) => prompt.toLowerCase().includes(kw.toLowerCase()));
    if (epicMatches.length > 0) {
        score -= 10; // Epic은 질문이 더 필요
    }
    return Math.max(0, Math.min(100, score));
}
// ============================================
// Epic Complexity Estimation
// ============================================
function estimateEpicComplexity(prompt) {
    let stories = 2; // 기본값
    let files = 5;
    let dependencies = 1;
    // DB + UI + API 복합 패턴
    const hasDB = DB_KEYWORDS.some((kw) => prompt.toLowerCase().includes(kw.toLowerCase()));
    const hasUI = ['UI', '화면', 'screen', 'component'].some((kw) => prompt.toLowerCase().includes(kw.toLowerCase()));
    const hasAPI = ['API', 'endpoint', 'route'].some((kw) => prompt.toLowerCase().includes(kw.toLowerCase()));
    if (hasDB && hasUI && hasAPI) {
        stories = 4;
        files = 10;
        dependencies = 5;
    }
    else if ((hasDB && hasUI) || (hasDB && hasAPI) || (hasUI && hasAPI)) {
        stories = 3;
        files = 7;
        dependencies = 3;
    }
    // Epic 수준 키워드
    const epicMatches = EPIC_LEVEL_KEYWORDS.filter((kw) => prompt.toLowerCase().includes(kw.toLowerCase()));
    if (epicMatches.length > 0) {
        stories += 2;
        files += 5;
        dependencies += 3;
    }
    // 통합/연동 키워드
    const integrationMatches = COMPLEXITY_INDICATORS.integration.filter((kw) => prompt.toLowerCase().includes(kw.toLowerCase()));
    if (integrationMatches.length > 0) {
        dependencies += 5;
    }
    return { estimatedStories: stories, estimatedFiles: files, dependencies };
}
// ============================================
// Ambiguous Keywords Extraction
// ============================================
function extractAmbiguousKeywords(prompt) {
    const found = [];
    // 모호한 키워드
    AMBIGUOUS_KEYWORDS.forEach((kw) => {
        if (prompt.toLowerCase().includes(kw.toLowerCase())) {
            found.push(kw);
        }
    });
    // 지시어 모호성 패턴
    const vaguePatterns = [
        { regex: /그거|그것|저것|이거/g, label: '불명확한 지시어' },
        { regex: /좀|조금|약간/g, label: '애매한 수량 표현' },
        { regex: /뭔가|어떤|무언가/g, label: '불확실한 표현' },
    ];
    vaguePatterns.forEach(({ regex, label }) => {
        if (regex.test(prompt)) {
            found.push(label);
        }
    });
    return Array.from(new Set(found)); // 중복 제거
}
// ============================================
// Risk Level Detection
// ============================================
function detectRiskLevel(prompt, complexity) {
    // DB 키워드 3개 이상 = HIGH
    const dbMatches = DB_KEYWORDS.filter((kw) => prompt.toLowerCase().includes(kw.toLowerCase())).length;
    if (dbMatches >= 3) {
        return 'HIGH';
    }
    // Epic 수준 + 높은 복잡도
    const epicMatches = EPIC_LEVEL_KEYWORDS.filter((kw) => prompt.toLowerCase().includes(kw.toLowerCase())).length;
    if (epicMatches > 0 && complexity.estimatedStories >= 4) {
        return 'HIGH';
    }
    // 의존성 5개 이상
    if (complexity.dependencies >= 5) {
        return 'MEDIUM';
    }
    // 파일 변경 10개 이상
    if (complexity.estimatedFiles >= 10) {
        return 'MEDIUM';
    }
    return 'LOW';
}
// ============================================
// Main Detection Function
// ============================================
export function detectAmbiguity(prompt, analysis) {
    const confidence = calculateConfidence(prompt, analysis);
    const ambiguousKeywords = extractAmbiguousKeywords(prompt);
    const epicComplexity = estimateEpicComplexity(prompt);
    const riskLevel = detectRiskLevel(prompt, epicComplexity);
    const shouldAskQuestions = confidence < 60 || riskLevel === 'HIGH' || riskLevel === 'CRITICAL';
    let reason = '명확한 요청';
    if (confidence < 60) {
        reason = `신뢰도 낮음 (${confidence}%)`;
    }
    else if (riskLevel === 'HIGH' || riskLevel === 'CRITICAL') {
        reason = `높은 위험도 (${riskLevel})`;
    }
    return {
        confidence,
        epicComplexity,
        triggers: {
            shouldAskQuestions,
            reason,
            riskLevel,
        },
        ambiguousKeywords,
    };
}
// ============================================
// CLI Support
// ============================================
// CLI detection (CommonJS-compatible)
const isMainModule = typeof process !== 'undefined' && process.argv && process.argv[1] && process.argv[1].includes('ambiguity-detector');
if (isMainModule) {
    const prompt = process.argv[2];
    if (!prompt) {
        console.error('Usage: ambiguity-detector.ts <prompt>');
        process.exit(1);
    }
    // Mock analysis for CLI (keyword-based inference)
    const lowerPrompt = prompt.toLowerCase();
    let intent = 'unknown';
    let domain = 'general';
    // Intent 추론
    if (lowerPrompt.includes('추가') || lowerPrompt.includes('add'))
        intent = 'create';
    else if (lowerPrompt.includes('수정') || lowerPrompt.includes('modify') || lowerPrompt.includes('fix'))
        intent = 'modify';
    else if (lowerPrompt.includes('버그') || lowerPrompt.includes('bug') || lowerPrompt.includes('에러'))
        intent = 'debug';
    // Domain 추론
    if (lowerPrompt.includes('api') || lowerPrompt.includes('endpoint'))
        domain = 'api';
    else if (lowerPrompt.includes('ui') || lowerPrompt.includes('화면') || lowerPrompt.includes('screen'))
        domain = 'ui';
    else if (lowerPrompt.includes('db') || lowerPrompt.includes('schema') || lowerPrompt.includes('database'))
        domain = 'db';
    else if (lowerPrompt.includes('auth') || lowerPrompt.includes('인증'))
        domain = 'auth';
    const mockAnalysis = {
        keywords: prompt.split(' ').slice(0, 5),
        intent,
        domain,
    };
    const result = detectAmbiguity(prompt, mockAnalysis);
    console.log(JSON.stringify(result, null, 2));
}
