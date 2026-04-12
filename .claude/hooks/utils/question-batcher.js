#!/usr/bin/env node
/**
 * Question Batching System
 *
 * AskUserQuestion MCP tool의 4개 질문 제약 조건을 준수하면서
 * 사용자에게 가장 중요한 질문만 선별하여 제시
 *
 * YAGNI 원칙:
 * - 복잡한 질문 템플릿 금지 (간단한 if-else로 시작)
 * - 4개 카테고리만 (Epic 범위, 기술, 우선순위, 위험도)
 * - Graceful Degradation (실패 시 워크플로우 계속)
 *
 * 패턴 재사용:
 * - ambiguity-detector.ts의 AmbiguityAnalysis 활용
 * - AskUserQuestion MCP tool 표준 스키마
 */
// ============================================
// Core Functions
// ============================================
/**
 * 우선순위 기반 질문 배치 생성
 * 최대 4개 질문으로 제한, 카테고리별 중복 제거
 */
export function batchQuestions(analysis, maxQuestions = 4) {
    // Step 1: 분석 결과 기반 질문 생성
    const questions = [];
    // Epic 범위 질문 (complexity 높으면 필수)
    if (analysis.epicComplexity.estimatedStories > 3 ||
        analysis.ambiguousKeywords.length > 0) {
        questions.push({
            id: 'q1',
            question: '이 작업은 새로운 기능 추가인가요, 기존 기능 개선인가요?',
            category: 'epic_scope',
            priority: 'high',
        });
    }
    // 기술 스택 질문 (도메인 불명확하면 필요)
    if (analysis.triggers.riskLevel === 'HIGH' || analysis.triggers.riskLevel === 'CRITICAL') {
        questions.push({
            id: 'q2',
            question: '어떤 영역의 작업인가요? (예: API, UI, DB, 인증 등)',
            category: 'tech_stack',
            priority: 'high',
        });
    }
    // 우선순위 질문 (Story 3개 이상 예상 시)
    if (analysis.epicComplexity.estimatedStories >= 3) {
        questions.push({
            id: 'q3',
            question: '어떤 Story를 먼저 구현하시겠어요?',
            category: 'priority',
            priority: 'medium',
        });
    }
    // 위험도 질문 (dependencies 많으면 필요)
    if (analysis.epicComplexity.dependencies > 2) {
        questions.push({
            id: 'q4',
            question: '이 작업에 외부 시스템 연동이나 DB 마이그레이션이 포함되나요?',
            category: 'risk',
            priority: 'medium',
        });
    }
    // Step 2: 우선순위 정렬
    const sorted = questions.sort((a, b) => {
        const priorityOrder = { high: 0, medium: 1, low: 2 };
        return priorityOrder[a.priority] - priorityOrder[b.priority];
    });
    // Step 3: 최대 개수 제한
    const selected = sorted.slice(0, maxQuestions);
    // Step 4: 카테고리별 중복 제거
    const deduped = deduplicateByCategory(selected);
    return {
        questions: deduped.map((q, i) => ({ ...q, id: `q${i + 1}` })),
        shouldAsk: deduped.length > 0,
        totalCount: deduped.length,
    };
}
/**
 * 카테고리별 중복 제거
 * 같은 카테고리에서 첫 번째 질문만 유지
 */
function deduplicateByCategory(questions) {
    const seen = new Set();
    return questions.filter((q) => {
        if (seen.has(q.category))
            return false;
        seen.add(q.category);
        return true;
    });
}
/**
 * 질문을 번호 매겨서 포맷팅
 * AskUserQuestion MCP tool에 전달할 형식
 */
export function formatBatchedQuestions(batch) {
    if (!batch.shouldAsk)
        return '';
    const lines = [
        '🤔 다음 정보가 필요합니다:',
        '',
        ...batch.questions.map((q, i) => `${i + 1}. ${q.question}`),
        '',
        '위 질문에 답변해주시면 더 정확한 작업이 가능합니다.',
    ];
    return lines.join('\n');
}
/**
 * 사용자 응답 파싱
 * "1. 답변", "2. 답변" 형식 지원
 */
export function parseUserResponse(response, questions) {
    const answers = new Map();
    // "1. 답변", "2. 답변" 형식 파싱
    const lines = response.split('\n');
    questions.forEach((q, index) => {
        const pattern = new RegExp(`^${index + 1}\\.?\\s*(.+)`);
        const match = lines.find((line) => pattern.test(line));
        if (match) {
            const answer = match.replace(pattern, '$1').trim();
            answers.set(q.category, answer);
        }
    });
    return answers;
}
/**
 * 사용자 답변으로 분석 결과 보강
 * confidence 점수 증가 및 복잡도 조정
 */
export function enhanceAnalysisWithAnswers(analysis, answers) {
    let enhancedConfidence = analysis.confidence;
    // 각 답변마다 confidence +5-10% 증가
    answers.forEach((answer, category) => {
        if (category === 'epic_scope') {
            enhancedConfidence += 10;
            // "새로운 기능"이면 Story 수 증가
            if (answer.includes('새로운') || answer.includes('추가')) {
                analysis.epicComplexity.estimatedStories += 1;
            }
        }
        else if (category === 'tech_stack') {
            enhancedConfidence += 8;
            // DB/UI/API 키워드로 dependencies 조정
            if (answer.includes('DB') || answer.includes('API')) {
                analysis.epicComplexity.dependencies += 1;
            }
        }
        else if (category === 'priority') {
            enhancedConfidence += 5;
        }
        else if (category === 'risk') {
            enhancedConfidence += 7;
            // "외부 시스템" 언급 시 위험도 상향
            if (answer.includes('외부') || answer.includes('마이그레이션')) {
                analysis.triggers.riskLevel = 'HIGH';
            }
        }
    });
    return {
        ...analysis,
        confidence: Math.min(enhancedConfidence, 100), // 최대 100%
    };
}
// ============================================
// CLI Entry Point (테스트용)
// ============================================
/**
 * 테스트 실행 방법:
 * npx ts-node .claude/utils/question-batcher.ts
 */
export async function runTest() {
    // 테스트용 더미 분석 결과
    const testAnalysis = {
        confidence: 60,
        epicComplexity: {
            estimatedStories: 4,
            estimatedFiles: 8,
            dependencies: 3,
        },
        triggers: {
            shouldAskQuestions: true,
            reason: 'High complexity and ambiguous keywords detected',
            riskLevel: 'HIGH',
        },
        ambiguousKeywords: ['개선', '확장', '최적화'],
    };
    console.log('=== Question Batching Test ===\n');
    const batch = batchQuestions(testAnalysis);
    console.log('Generated Questions:', batch.totalCount);
    console.log('Should Ask:', batch.shouldAsk);
    console.log('\nFormatted Output:');
    console.log(formatBatchedQuestions(batch));
    // 테스트용 사용자 응답 시뮬레이션
    const testResponse = `1. 새로운 기능 추가
2. API 및 DB
3. UI Story부터
4. 외부 시스템 연동 있음`;
    console.log('\n=== Response Parsing Test ===\n');
    const answers = parseUserResponse(testResponse, batch.questions);
    console.log('Parsed Answers:', Object.fromEntries(answers));
    const enhanced = enhanceAnalysisWithAnswers(testAnalysis, answers);
    console.log('\nEnhanced Confidence:', enhanced.confidence);
    console.log('Updated Risk Level:', enhanced.triggers.riskLevel);
}
