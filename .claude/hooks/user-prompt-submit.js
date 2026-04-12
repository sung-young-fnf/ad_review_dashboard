#!/usr/bin/env node
import { readFileSync, existsSync, writeFileSync, mkdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
// okr2 Project Patterns
const OKR2_PROJECT_PATTERNS = {
    auth_system: {
        tech_stack: "NextAuth.js + JWT + Bearer Token",
        db_schema: "sparknote",
        security: "OWASP Authentication Guidelines"
    },
    api_development: {
        pattern: "Next.js App Router + Proxy Pattern",
        auth_header: "session.backendToken",
        impersonation: "X-Impersonate-User header"
    },
    ui_components: {
        framework: "React 18 + TypeScript + Tailwind",
        state_management: "useState + useEffect (primitive deps only)",
        hooks: "Custom hooks with useMemo stabilization"
    },
    database: {
        schema: "sparknote",
        prohibition: "NO PostgreSQL ENUM types",
        alternative: "VARCHAR + TypeScript literal types"
    }
};
// Agent Expertise Map
const AGENT_EXPERTISE_MAP = {
    'epic-creator': {
        specialties: ["MVP design", "user stories", "auth systems"],
        confidence_domains: ["auth", "business_logic", "system_design"]
    },
    'story-creator': {
        specialties: ["API design", "UI components", "data flow"],
        confidence_domains: ["api", "ui", "crud", "integration"]
    },
    'code-writer': {
        specialties: ["React implementation", "API routes", "DB schema"],
        confidence_domains: ["react", "nextjs", "typescript", "prisma"]
    },
    'error-fixer': {
        specialties: ["debugging", "runtime errors", "performance"],
        confidence_domains: ["error_handling", "optimization", "troubleshooting"]
    },
    'commit-manager': {
        specialties: ["git operations", "commit messages", "version control"],
        confidence_domains: ["git", "commit", "push", "branch"]
    }
};
function analyzeUserIntent(userInput) {
    const input = userInput.toLowerCase();
    // Extract keywords
    const keywords = input.split(/\s+/).filter(word => word.length > 2);
    // Classify intent
    let intent_type = 'modify';
    if (input.includes('새로운') || input.includes('추가') || input.includes('생성')) {
        intent_type = 'create';
    }
    else if (input.includes('수정') || input.includes('변경') || input.includes('개선')) {
        intent_type = 'modify';
    }
    else if (input.includes('디버그') || input.includes('에러') || input.includes('버그')) {
        intent_type = 'debug';
    }
    else if (input.includes('분석') || input.includes('확인') || input.includes('검토')) {
        intent_type = 'analyze';
    }
    else if (input.includes('삭제') || input.includes('제거')) {
        intent_type = 'delete';
    }
    else if (input.includes('커밋') || input.includes('푸시') || input.includes('commit') || input.includes('push')) {
        intent_type = 'commit';
    }
    // Assess complexity
    let complexity = 'story';
    if (input.includes('시스템') || input.includes('플랫폼') || input.includes('아키텍처')) {
        complexity = 'epic';
    }
    else if (input.includes('긴급') || input.includes('핫픽스') || input.includes('다운')) {
        complexity = 'hotfix';
    }
    else if (input.includes('스키마') || input.includes('마이그레이션') || input.includes('db')) {
        complexity = 'db';
    }
    else if (input.includes('버그') || input.includes('수정') && input.length < 50) {
        complexity = 'task';
    }
    else if (input.includes('커밋') || input.includes('푸시') || input.includes('commit') || input.includes('push')) {
        complexity = 'commit';
    }
    // Identify domain
    let domain = 'api';
    if (input.includes('인증') || input.includes('로그인') || input.includes('사용자')) {
        domain = 'auth';
    }
    else if (input.includes('화면') || input.includes('컴포넌트') || input.includes('ui')) {
        domain = 'ui';
    }
    else if (input.includes('db') || input.includes('데이터베이스') || input.includes('스키마')) {
        domain = 'db';
    }
    else if (input.includes('테스트') || input.includes('검증')) {
        domain = 'test';
    }
    else if (input.includes('배포') || input.includes('빌드')) {
        domain = 'deployment';
    }
    // Extract tech indicators
    const tech_indicators = [];
    if (input.includes('react'))
        tech_indicators.push('react');
    if (input.includes('typescript') || input.includes('ts'))
        tech_indicators.push('typescript');
    if (input.includes('nextjs') || input.includes('next'))
        tech_indicators.push('nextjs');
    if (input.includes('api'))
        tech_indicators.push('api');
    if (input.includes('prisma'))
        tech_indicators.push('prisma');
    return {
        keywords,
        intent_type,
        complexity,
        domain,
        tech_indicators
    };
}
function selectOptimalAgent(intent) {
    // Agent selection logic based on complexity and domain
    let selectedAgent = 'story-creator';
    let confidence = 85;
    let reasoning = '';
    if (intent.complexity === 'commit' || intent.intent_type === 'commit') {
        selectedAgent = 'commit-manager';
        confidence = 98;
        reasoning = 'Git commit/push operations require commit-manager';
    }
    else if (intent.complexity === 'epic') {
        selectedAgent = 'epic-creator';
        confidence = 95;
        reasoning = 'Complex system design requires comprehensive Epic planning';
    }
    else if (intent.complexity === 'hotfix') {
        selectedAgent = 'error-fixer';
        confidence = 98;
        reasoning = 'Emergency situation requires immediate error fixing';
    }
    else if (intent.complexity === 'db') {
        selectedAgent = 'db-code-writer';
        confidence = 92;
        reasoning = 'Database operations require specialized DB agent';
    }
    else if (intent.intent_type === 'debug') {
        selectedAgent = 'error-fixer';
        confidence = 88;
        reasoning = 'Debugging requires error analysis and fixing expertise';
    }
    else if (intent.domain === 'auth') {
        selectedAgent = 'epic-creator';
        confidence = 93;
        reasoning = 'Authentication system requires comprehensive MVP design';
    }
    else if (intent.domain === 'ui' && intent.intent_type === 'create') {
        selectedAgent = 'story-creator';
        confidence = 90;
        reasoning = 'UI component creation fits Story-level implementation';
    }
    else if (intent.complexity === 'task') {
        selectedAgent = 'task-planner';
        confidence = 87;
        reasoning = 'Simple modifications work well with Task-level planning';
    }
    const agentInfo = AGENT_EXPERTISE_MAP[selectedAgent];
    return {
        agent: selectedAgent,
        confidence,
        reasoning,
        specialties: agentInfo?.specialties || [],
        confidence_domains: agentInfo?.confidence_domains || []
    };
}
function generateContextInjection(intent, recommendation) {
    const domainUpper = intent.domain.toUpperCase();
    const intentUpper = intent.intent_type.toUpperCase();
    let output = '';
    output += '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n';
    output += '🧠 CLAUDE CONTEXT INJECTION\n';
    output += '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n';
    output += `🎯 ${domainUpper} ${intentUpper} DETECTED\n\n`;
    output += `📋 Recommended Agent: ${recommendation.agent}\n`;
    output += `   Expertise: ${recommendation.specialties.join(', ')}\n`;
    output += `   Confidence: ${recommendation.confidence}% (${recommendation.reasoning})\n\n`;
    // Domain-specific context
    if (intent.domain === 'auth') {
        output += '🔧 okr2 Technical Context:\n';
        output += `   - ${OKR2_PROJECT_PATTERNS.auth_system.tech_stack}\n`;
        output += `   - PostgreSQL ${OKR2_PROJECT_PATTERNS.database.schema} schema (${OKR2_PROJECT_PATTERNS.database.prohibition})\n`;
        output += `   - ${OKR2_PROJECT_PATTERNS.api_development.auth_header} authentication (NOT accessToken)\n`;
        output += `   - ${OKR2_PROJECT_PATTERNS.api_development.impersonation} for admin features\n\n`;
        output += '⚠️ Critical Warnings:\n';
        output += `   - ${OKR2_PROJECT_PATTERNS.database.prohibition}: Use ${OKR2_PROJECT_PATTERNS.database.alternative}\n`;
        output += `   - ${OKR2_PROJECT_PATTERNS.auth_system.security} compliance required\n`;
        output += '   - Admin impersonation pattern mandatory for all auth endpoints\n\n';
    }
    else if (intent.domain === 'ui') {
        output += '🔧 okr2 Technical Context:\n';
        output += `   - ${OKR2_PROJECT_PATTERNS.ui_components.framework}\n`;
        output += `   - ${OKR2_PROJECT_PATTERNS.api_development.pattern}\n`;
        output += `   - PostgreSQL ${OKR2_PROJECT_PATTERNS.database.schema} schema with proper relations\n\n`;
        output += '⚠️ Critical Warnings:\n';
        output += '   - 405 Error Prevention: Implement ALL required HTTP methods\n';
        output += '   - 404 Error Prevention: Nested routes need separate directories\n';
        output += '   - React Hook Dependencies: Use primitive values only\n';
        output += `   - DB Schema Prefix: All queries must use ${OKR2_PROJECT_PATTERNS.database.schema}.table_name\n\n`;
    }
    else if (intent.domain === 'api') {
        output += '🔧 okr2 Technical Context:\n';
        output += `   - ${OKR2_PROJECT_PATTERNS.api_development.pattern}\n`;
        output += '   - NestJS backend with JWT authentication\n';
        output += '   - Proxy pattern with environment variable fallbacks\n';
        output += '   - Admin impersonation support\n\n';
        output += '⚠️ Critical Warnings:\n';
        output += '   - Environment Variables: API_BASE_URL || BACKEND_URL || NEXT_PUBLIC_BACKEND_URL\n';
        output += `   - Authentication: Bearer token from ${OKR2_PROJECT_PATTERNS.api_development.auth_header}\n`;
        output += '   - Error Handling: Comprehensive try-catch with user-friendly messages\n';
        output += '   - Method Support: All HTTP methods that frontend will call\n\n';
    }
    else if (intent.domain === 'db') {
        output += '🔧 okr2 Technical Context:\n';
        output += `   - PostgreSQL ${OKR2_PROJECT_PATTERNS.database.schema} schema (MANDATORY prefix)\n`;
        output += `   - ${OKR2_PROJECT_PATTERNS.database.prohibition} - ${OKR2_PROJECT_PATTERNS.database.alternative}\n`;
        output += '   - Prisma ORM with schema validation\n';
        output += '   - Alembic migrations for schema changes\n\n';
        output += '⚠️ Critical Warnings:\n';
        output += `   - ALL SQL queries MUST use ${OKR2_PROJECT_PATTERNS.database.schema}.table_name prefix\n`;
        output += `   - ${OKR2_PROJECT_PATTERNS.database.prohibition} (변경 불가능성, 마이그레이션 위험)\n`;
        output += '   - Transaction safety for all data modifications\n';
        output += '   - Parameterized queries for SQL injection prevention\n\n';
    }
    output += '💡 Quality Checkpoints:\n';
    if (intent.tech_indicators.includes('react')) {
        output += '   - React Hook dependency array validation\n';
    }
    output += '   - API error handling completeness\n';
    output += `   - Database schema prefix compliance (${OKR2_PROJECT_PATTERNS.database.schema}.)\n`;
    output += '   - Authentication flow security validation\n\n';
    // Workflow prediction
    if (intent.complexity === 'epic') {
        output += '📋 Predicted Workflow: Epic → Story → Task → Implementation\n';
        output += '🕒 Estimated Timeline: 25-30 minutes (based on similar Epic tasks)\n';
    }
    else if (intent.complexity === 'story') {
        output += '📋 Predicted Story Structure:\n';
        output += '   S01: Database schema + API implementation\n';
        output += '   S02: UI display components\n';
        output += '   S03: Create/Edit forms with validation\n';
        output += '   S04: Real-time updates and admin features\n\n';
        output += '🕒 Estimated Timeline: 18-22 minutes (based on CRUD velocity)\n';
    }
    else if (intent.complexity === 'task') {
        output += '📋 Predicted Task Flow:\n';
        output += '   T01: Analysis and planning\n';
        output += '   T02: Implementation\n';
        output += '   T03: Testing and validation\n\n';
        output += '🕒 Estimated Timeline: 8-12 minutes (based on task complexity)\n';
    }
    output += '\n🎯 AUTO-WORKFLOW ROUTING:\n';
    output += '   Enhanced 4-Step: STOP → ANALYZE → INJECT → ROUTE\n\n';
    output += '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n';
    return output;
}
// =============================================================================
// LAYER 1: SKILL SYSTEM - Guardrail + Context Provider
// =============================================================================
function findProjectRoot() {
    // Hook is executed from project root, so process.cwd() is the project root
    let currentDir = process.cwd();
    let attempts = 0;
    const maxAttempts = 10; // Prevent infinite loop
    while (!existsSync(join(currentDir, '.claude', 'skills')) && attempts < maxAttempts) {
        const parent = dirname(currentDir);
        if (parent === currentDir) {
            // Reached filesystem root without finding project
            return process.cwd();
        }
        currentDir = parent;
        attempts++;
    }
    if (attempts >= maxAttempts) {
        // .claude/skills not found, return current working directory
        return process.cwd();
    }
    return currentDir;
}
function loadSkillRules(projectRoot) {
    const rulesPath = join(projectRoot, '.claude', 'skills', 'skill-rules.json');
    if (!existsSync(rulesPath)) {
        return null;
    }
    try {
        const content = readFileSync(rulesPath, 'utf-8');
        return JSON.parse(content);
    }
    catch (err) {
        console.error('[Skill System] Failed to load skill-rules.json:', err);
        return null;
    }
}
function checkPromptTriggers(rule, prompt) {
    if (!rule.promptTriggers)
        return false;
    const lowerPrompt = prompt.toLowerCase();
    // Keyword matching
    if (rule.promptTriggers.keywords) {
        for (const keyword of rule.promptTriggers.keywords) {
            if (lowerPrompt.includes(keyword.toLowerCase())) {
                return true;
            }
        }
    }
    // Intent pattern matching (regex)
    if (rule.promptTriggers.intentPatterns) {
        for (const pattern of rule.promptTriggers.intentPatterns) {
            try {
                const regex = new RegExp(pattern, 'i');
                if (regex.test(lowerPrompt)) {
                    return true;
                }
            }
            catch (err) {
                // Invalid regex, skip
            }
        }
    }
    return false;
}
function checkSkillRules(prompt, projectRoot) {
    const rules = loadSkillRules(projectRoot);
    if (!rules) {
        return { blocked: false };
    }
    for (const [ruleName, rule] of Object.entries(rules)) {
        if (!checkPromptTriggers(rule, prompt)) {
            continue;
        }
        // Rule matched - handle based on enforcement
        if (rule.enforcement === 'block') {
            return {
                blocked: true,
                blockMessage: rule.blockMessage || `Blocked by rule: ${ruleName}`,
                ruleName
            };
        }
        else if (rule.enforcement === 'suggest') {
            const suggestions = [];
            if (rule.resources) {
                suggestions.push(...rule.resources.map(r => `--context-file ${r}`));
            }
            if (rule.suggested_agent) {
                suggestions.push(`--agent ${rule.suggested_agent}`);
            }
            if (rule.message) {
                console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
                console.log(`💡 SKILL CONTEXT INJECTED: ${ruleName}`);
                console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
                console.log(rule.message);
                console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
            }
            return { blocked: false, suggestions, ruleName };
        }
        else if (rule.enforcement === 'warn') {
            if (rule.message) {
                console.log(`\n⚠️ WARNING: ${ruleName} - ${rule.message}\n`);
            }
        }
    }
    return { blocked: false };
}
async function main() {
    const logFile = join(__dirname, 'user-prompt-submit.log');
    try {
        writeFileSync(logFile, `\n[${new Date().toISOString()}] === Hook started ===\n`, { flag: 'a' });
        writeFileSync(logFile, `Working directory: ${process.cwd()}\n`, { flag: 'a' });
        writeFileSync(logFile, `Script directory: ${__dirname}\n`, { flag: 'a' });
        // Read input from stdin
        const input = readFileSync(0, 'utf-8');
        writeFileSync(logFile, `Raw input length: ${input.length}\n`, { flag: 'a' });
        const data = JSON.parse(input);
        const prompt = data.prompt;
        // Debug log
        writeFileSync(logFile, `Received prompt: ${prompt}\n`, { flag: 'a' });
        // Skip if prompt is too short or looks like non-development request
        if (prompt.length < 10 ||
            !prompt.match(/추가|생성|수정|개선|삭제|구현|개발|시스템|api|ui|db|컴포넌트|기능|커밋|푸시|commit|push/i)) {
            writeFileSync(logFile, `[${new Date().toISOString()}] Skipped (non-dev prompt): ${prompt}\n`, { flag: 'a' });
            process.exit(0);
        }
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // LAYER 1: Skill System - Guardrail + Context Provider
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        writeFileSync(logFile, `Finding project root...\n`, { flag: 'a' });
        const projectRoot = findProjectRoot();
        writeFileSync(logFile, `Project root: ${projectRoot}\n`, { flag: 'a' });
        writeFileSync(logFile, `Checking skill rules...\n`, { flag: 'a' });
        const skillCheck = checkSkillRules(prompt, projectRoot);
        writeFileSync(logFile, `Skill check complete. Blocked: ${skillCheck.blocked}\n`, { flag: 'a' });
        if (skillCheck.blocked) {
            // Guardrail: Block execution
            console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
            console.log('🛑 GUARDRAIL BLOCKED');
            console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
            console.log(skillCheck.blockMessage);
            console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
            process.exit(1);
        }
        // Layer 1 suggestions (for future enhancement - inject into Layer 2)
        const layer1Suggestions = skillCheck.suggestions || [];
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // LAYER 2: Enhanced 4-Step Workflow
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // Step 1: ANALYZE - Intent Pattern Analysis
        writeFileSync(logFile, `Analyzing user intent...\n`, { flag: 'a' });
        let intent = analyzeUserIntent(prompt);
        writeFileSync(logFile, `Intent: ${intent.intent_type}, Complexity: ${intent.complexity}, Domain: ${intent.domain}\n`, { flag: 'a' });
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // T012-S04: Conditional Ambiguity Detection + User Questions
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        let ambiguityAnalysis = null;
        let questionsAsked = false;
        let userResponses = null;
        try {
            // Dynamic import ambiguity detector
            const ambiguityModule = await import('../utils/ambiguity-detector.js');
            const detectAmbiguity = ambiguityModule.detectAmbiguity;
            // Step 1.5: Detect ambiguity
            writeFileSync(logFile, `[S04] Detecting ambiguity...\n`, { flag: 'a' });
            // Adapt UserIntent to IntentAnalysis (ambiguity-detector expects simpler interface)
            const intentForAmbiguity = {
                keywords: intent.keywords,
                intent: intent.intent_type,
                domain: intent.domain,
            };
            ambiguityAnalysis = detectAmbiguity(prompt, intentForAmbiguity);
            writeFileSync(logFile, `[S04] Confidence: ${ambiguityAnalysis.confidence}%, Risk: ${ambiguityAnalysis.triggers.riskLevel}\n`, { flag: 'a' });
            // Step 1.6: Conditional question activation
            const CONFIDENCE_THRESHOLD = 60;
            const URGENT_KEYWORDS = ['긴급', 'P0', '장애', '서비스 다운', 'hotfix'];
            const isUrgent = URGENT_KEYWORDS.some(kw => prompt.toLowerCase().includes(kw.toLowerCase()));
            if (!isUrgent && ambiguityAnalysis.confidence < CONFIDENCE_THRESHOLD && ambiguityAnalysis.triggers.shouldAskQuestions) {
                writeFileSync(logFile, `[S04] Questions triggered (confidence: ${ambiguityAnalysis.confidence}%)\n`, { flag: 'a' });
                // Import question batcher
                const questionModule = await import('../utils/question-batcher.js');
                const batchQuestions = questionModule.batchQuestions;
                // Generate questions
                const batchResult = batchQuestions(ambiguityAnalysis, 4);
                if (batchResult.shouldAsk && batchResult.questions.length > 0) {
                    writeFileSync(logFile, `[S04] Asking ${batchResult.questions.length} questions...\n`, { flag: 'a' });
                    // Format questions for user
                    const questionText = batchResult.questions.map((q, idx) => `${idx + 1}. [${q.category}] ${q.question}`).join('\n');
                    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
                    console.log('🤔 Ambiguity Detected - Need Clarification');
                    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
                    console.log(`Confidence: ${ambiguityAnalysis.confidence}%`);
                    console.log(`\nQuestions:\n${questionText}`);
                    console.log('\nNote: This is a non-blocking workflow. You can skip questions if needed.');
                    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
                    questionsAsked = true;
                    // TODO: Integrate with AskUserQuestion MCP when available
                    // For now, log and continue with original analysis
                    writeFileSync(logFile, `[S04] Questions logged. Continuing with original analysis.\n`, { flag: 'a' });
                }
            }
            else if (isUrgent) {
                writeFileSync(logFile, `[S04] Urgent keyword detected, skipping questions\n`, { flag: 'a' });
            }
            else {
                writeFileSync(logFile, `[S04] Confidence sufficient (${ambiguityAnalysis.confidence}%), skipping questions\n`, { flag: 'a' });
            }
            // Save metadata
            const cacheDir = join(__dirname, '../hooks-cache/user-prompt-submit');
            if (!existsSync(cacheDir)) {
                mkdirSync(cacheDir, { recursive: true });
            }
            const metadata = {
                timestamp: new Date().toISOString(),
                userPrompt: prompt,
                analysis: ambiguityAnalysis,
                questionsAsked,
                userResponses,
                confidence: ambiguityAnalysis.confidence,
            };
            const metadataFile = join(cacheDir, `${new Date().toISOString().replace(/:/g, '-')}.json`);
            writeFileSync(metadataFile, JSON.stringify(metadata, null, 2));
            writeFileSync(logFile, `[S04] Metadata saved: ${metadataFile}\n`, { flag: 'a' });
        }
        catch (err) {
            // Graceful degradation
            writeFileSync(logFile, `[S04] Warning: ${err instanceof Error ? err.message : String(err)}\n`, { flag: 'a' });
            writeFileSync(logFile, `[S04] Continuing without ambiguity detection\n`, { flag: 'a' });
        }
        // Step 2: INJECT - Select optimal agent and generate context
        writeFileSync(logFile, `Selecting optimal agent...\n`, { flag: 'a' });
        const recommendation = selectOptimalAgent(intent);
        writeFileSync(logFile, `Recommended agent: ${recommendation.agent} (${recommendation.confidence}%)\n`, { flag: 'a' });
        writeFileSync(logFile, `Generating context injection...\n`, { flag: 'a' });
        const contextInjection = generateContextInjection(intent, recommendation);
        // Step 3: OUTPUT - Send context injection to Claude
        writeFileSync(logFile, `Sending output to Claude...\n`, { flag: 'a' });
        console.log(contextInjection);
        console.log(`📨 Original User Message: "${prompt}"\n`);
        writeFileSync(logFile, `Hook completed successfully\n`, { flag: 'a' });
        process.exit(0);
    }
    catch (err) {
        const logFile = join(__dirname, 'user-prompt-submit.log');
        const errorMsg = `[${new Date().toISOString()}] ERROR: ${err instanceof Error ? err.message : String(err)}\nStack: ${err instanceof Error ? err.stack : 'N/A'}\n`;
        writeFileSync(logFile, errorMsg, { flag: 'a' });
        console.error('Error in user-prompt-submit hook:', err);
        process.exit(1);
    }
}
main().catch(err => {
    console.error('Uncaught error:', err);
    process.exit(1);
});
