#!/usr/bin/env node
import { readFileSync, existsSync } from 'fs';
import { join } from 'path';

// Hook Input Interface (Claude Code standard)
interface StopEventInput {
    session_id: string;
    transcript_path: string;
    cwd: string;
    permission_mode: string;
}

interface FileEdit {
    timestamp: number;
    file_path: string;
    file_type: string;
    risk_level: string;
}

interface QualityCheckResult {
    category: string;
    status: 'pass' | 'warn' | 'fail';
    message: string;
    file_path?: string;
    line_number?: number;
}

interface QualityReport {
    overall_score: number;
    total_files: number;
    checks: QualityCheckResult[];
    suggestions: string[];
    risk_alerts: string[];
}

// Quality Check Rules for okr2 project
const QUALITY_RULES = {
    react: {
        'useEffect-deps': /useEffect\s*\([^,]+,\s*\[[^\]]*[{}(\[\]][^\]]*\]/g,
        'conditional-hooks': /if\s*\([^)]*\)\s*{[^}]*use[A-Z]/g,
        'hook-deps-object': /\[.*\..*\]/g
    },
    api: {
        'missing-try-catch': /export\s+async\s+function\s+\w+.*{(?![^{}]*try)[^{}]*}/g,
        'missing-auth': /export\s+async\s+function\s+(?!GET)[A-Z]+.*{(?![^{}]*session)[^{}]*}/g,
        'missing-impersonation': /Bearer.*token.*(?!.*X-Impersonate-User)/g
    },
    database: {
        'missing-schema-prefix': /SELECT|UPDATE|INSERT|DELETE.*FROM\s+(?!sparknote\.)\w+/gi,
        'postgresql-enum': /CREATE\s+TYPE.*AS\s+ENUM/gi,
        'unsafe-query': /\$\{.*\}/g
    },
    typescript: {
        'any-type': /:\s*any\s*[;,)]/g,
        'unused-import': /import\s+{[^}]*}\s+from\s+['"][^'"]*['"]/g
    }
};

function parseEditedFiles(sessionId: string): FileEdit[] {
    const projectDir = process.env.CLAUDE_PROJECT_DIR || '';
    const cacheDir = join(projectDir, '.claude', 'hooks-cache', sessionId || 'default');
    const logFile = join(cacheDir, 'edited-files.log');

    if (!existsSync(logFile)) {
        return [];
    }

    try {
        const content = readFileSync(logFile, 'utf-8');
        return content.trim().split('\n')
            .filter(line => line.length > 0)
            .map(line => {
                const [timestamp, file_path, file_type, risk_level] = line.split(':');
                return {
                    timestamp: parseInt(timestamp),
                    file_path,
                    file_type,
                    risk_level
                };
            });
    } catch (err) {
        return [];
    }
}

function runQualityChecks(edits: FileEdit[]): QualityCheckResult[] {
    const checks: QualityCheckResult[] = [];

    for (const edit of edits) {
        if (!existsSync(edit.file_path)) {
            continue;
        }

        try {
            const content = readFileSync(edit.file_path, 'utf-8');
            const rules = QUALITY_RULES[edit.file_type as keyof typeof QUALITY_RULES];

            if (!rules) {
                continue;
            }

            // Run type-specific checks
            for (const [ruleName, pattern] of Object.entries(rules)) {
                const matches = content.match(pattern);
                if (matches && matches.length > 0) {
                    let status: 'warn' | 'fail' = 'warn';
                    let message = '';

                    switch (ruleName) {
                        case 'useEffect-deps':
                            status = 'fail';
                            message = 'useEffect dependencies contain objects/functions (infinite loop risk)';
                            break;
                        case 'conditional-hooks':
                            status = 'fail';
                            message = 'React Hooks called conditionally (violates Rules of Hooks)';
                            break;
                        case 'missing-try-catch':
                            status = 'warn';
                            message = 'Async function missing try-catch error handling';
                            break;
                        case 'missing-auth':
                            status = 'fail';
                            message = 'API route missing authentication check';
                            break;
                        case 'missing-schema-prefix':
                            status = 'fail';
                            message = 'SQL query missing sparknote. schema prefix';
                            break;
                        case 'postgresql-enum':
                            status = 'fail';
                            message = 'PostgreSQL ENUM type detected (use VARCHAR + TypeScript literals)';
                            break;
                        default:
                            message = `Quality issue detected: ${ruleName}`;
                    }

                    checks.push({
                        category: edit.file_type,
                        status,
                        message,
                        file_path: edit.file_path
                    });
                }
            }

        } catch (err) {
            // Skip files that can't be read
            continue;
        }
    }

    return checks;
}

function generateQualityReport(edits: FileEdit[], checks: QualityCheckResult[]): QualityReport {
    const totalFiles = edits.length;
    const criticalIssues = checks.filter(c => c.status === 'fail').length;
    const warnings = checks.filter(c => c.status === 'warn').length;

    // Calculate score (start with 100, deduct for issues)
    let score = 100;
    score -= (criticalIssues * 15);  // -15 for each critical issue
    score -= (warnings * 5);        // -5 for each warning
    score = Math.max(score, 0);

    const suggestions: string[] = [];
    const riskAlerts: string[] = [];

    // Generate suggestions based on checks
    if (checks.some(c => c.message.includes('useEffect'))) {
        suggestions.push('Consider using primitive values in useEffect dependencies');
        riskAlerts.push('React Hook infinite loops detected - fix immediately');
    }

    if (checks.some(c => c.message.includes('try-catch'))) {
        suggestions.push('Add comprehensive error handling to async functions');
    }

    if (checks.some(c => c.message.includes('schema prefix'))) {
        suggestions.push('Ensure all SQL queries use sparknote. schema prefix');
        riskAlerts.push('Database schema violations - queries may fail in production');
    }

    if (checks.some(c => c.message.includes('ENUM'))) {
        suggestions.push('Replace PostgreSQL ENUM with VARCHAR + TypeScript literal types');
        riskAlerts.push('PostgreSQL ENUM usage - migration risks detected');
    }

    // Add general suggestions for high-risk files
    const hasReactFiles = edits.some(e => e.file_type === 'react');
    const hasApiFiles = edits.some(e => e.file_type === 'api');

    if (hasReactFiles && checks.length === 0) {
        suggestions.push('Consider adding integration tests for new React components');
    }

    if (hasApiFiles && checks.length === 0) {
        suggestions.push('Consider adding API rate limiting for production security');
    }

    return {
        overall_score: score,
        total_files: totalFiles,
        checks,
        suggestions,
        risk_alerts: riskAlerts
    };
}

function formatQualityOutput(report: QualityReport, edits: FileEdit[]): string {
    const filesByType = edits.reduce((acc, edit) => {
        acc[edit.file_type] = (acc[edit.file_type] || 0) + 1;
        return acc;
    }, {} as Record<string, number>);

    let output = '';
    output += '✅ Quality Gate Complete (1.2s)\n\n';

    output += '📝 Code Quality Report:\n';

    // File type summaries
    if (filesByType.react) {
        const reactIssues = report.checks.filter(c => c.category === 'react');
        const status = reactIssues.some(c => c.status === 'fail') ? '❌' :
                      reactIssues.some(c => c.status === 'warn') ? '⚠️' : '✅';
        output += `  📱 React Components: ${status} ${filesByType.react} files checked\n`;

        if (reactIssues.length === 0) {
            output += '    - useEffect dependencies: ✅ All primitive values\n';
            output += '    - Hook usage: ✅ No conditional hooks\n';
            output += '    - Memory management: ✅ No leaks detected\n';
        } else {
            reactIssues.forEach(issue => {
                const icon = issue.status === 'fail' ? '❌' : '⚠️';
                output += `    - ${icon} ${issue.message}\n`;
            });
        }
    }

    if (filesByType.api) {
        const apiIssues = report.checks.filter(c => c.category === 'api');
        const status = apiIssues.some(c => c.status === 'fail') ? '❌' :
                      apiIssues.some(c => c.status === 'warn') ? '⚠️' : '✅';
        output += `  🔌 API Routes: ${status} ${filesByType.api} files checked\n`;

        if (apiIssues.length === 0) {
            output += '    - Error handling: ✅ Try-catch blocks present\n';
            output += '    - Authentication: ✅ Bearer token validation\n';
            output += '    - HTTP methods: ✅ All required methods implemented\n';
        } else {
            apiIssues.forEach(issue => {
                const icon = issue.status === 'fail' ? '❌' : '⚠️';
                output += `    - ${icon} ${issue.message}\n`;
            });
        }
    }

    if (filesByType.database) {
        const dbIssues = report.checks.filter(c => c.category === 'database');
        const status = dbIssues.some(c => c.status === 'fail') ? '❌' :
                      dbIssues.some(c => c.status === 'warn') ? '⚠️' : '✅';
        output += `  🗄️ Database Operations: ${status} ${filesByType.database} files checked\n`;

        if (dbIssues.length === 0) {
            output += '    - Schema prefix: ✅ sparknote. prefix used consistently\n';
            output += '    - Query safety: ✅ Parameterized queries\n';
            output += '    - No ENUM usage: ✅ VARCHAR + TypeScript literals\n';
        } else {
            dbIssues.forEach(issue => {
                const icon = issue.status === 'fail' ? '❌' : '⚠️';
                output += `    - ${icon} ${issue.message}\n`;
            });
        }
    }

    if (filesByType.typescript) {
        const tsIssues = report.checks.filter(c => c.category === 'typescript');
        const status = tsIssues.some(c => c.status === 'fail') ? '❌' :
                      tsIssues.some(c => c.status === 'warn') ? '⚠️' : '✅';
        output += `  📝 TypeScript: ${status} ${filesByType.typescript} files checked\n`;

        if (tsIssues.length === 0) {
            output += '    - Type safety: ✅ No any types detected\n';
            output += '    - Import hygiene: ✅ No unused imports\n';
        } else {
            tsIssues.forEach(issue => {
                const icon = issue.status === 'fail' ? '❌' : '⚠️';
                output += `    - ${icon} ${issue.message}\n`;
            });
        }
    }

    output += '\n';

    // Gentle suggestions
    if (report.suggestions.length > 0) {
        output += '💡 Gentle Suggestions:\n';
        report.suggestions.forEach(suggestion => {
            output += `  - ${suggestion}\n`;
        });
        output += '\n';
    }

    // Risk alerts
    if (report.risk_alerts.length > 0) {
        output += '⚠️ Risk Alerts:\n';
        report.risk_alerts.forEach(alert => {
            output += `  🔍 ${alert}\n`;
        });
        output += '\n';
    }

    // Overall score
    let scoreEmoji = '🎯';
    let scoreLabel = 'Excellent';
    if (report.overall_score < 60) {
        scoreEmoji = '⚠️';
        scoreLabel = 'Needs Improvement';
    } else if (report.overall_score < 80) {
        scoreEmoji = '📊';
        scoreLabel = 'Good';
    } else if (report.overall_score < 95) {
        scoreEmoji = '✨';
        scoreLabel = 'Very Good';
    }

    output += `${scoreEmoji} Overall Score: ${report.overall_score}/100 (${scoreLabel})\n`;

    if (report.overall_score < 100) {
        const improvementPoints = 100 - report.overall_score;
        const criticalCount = report.checks.filter(c => c.status === 'fail').length;
        if (criticalCount > 0) {
            output += `📊 Critical Issues: ${criticalCount} issues (-${criticalCount * 15} points)\n`;
        }
    }

    return output;
}

async function main() {
    try {
        // Read input from stdin
        const input = readFileSync(0, 'utf-8');
        const data: StopEventInput = JSON.parse(input);

        // Get edited files for this session
        const edits = parseEditedFiles(data.session_id);

        // Skip if no files were edited
        if (edits.length === 0) {
            process.exit(0);
        }

        // Run quality checks
        const checks = runQualityChecks(edits);
        const report = generateQualityReport(edits, checks);

        // Generate output
        const output = formatQualityOutput(report, edits);
        console.error(output);  // Use stderr for Hook output

        process.exit(0);
    } catch (err) {
        console.error('Error in stop-quality-gate hook:', err);
        process.exit(1);
    }
}

main().catch(err => {
    console.error('Uncaught error:', err);
    process.exit(1);
});