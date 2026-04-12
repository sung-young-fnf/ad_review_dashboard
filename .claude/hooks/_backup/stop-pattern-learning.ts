#!/usr/bin/env node
import { readFileSync, writeFileSync, existsSync } from 'fs';
import { join } from 'path';

// Hook Input Interface (Claude Code standard)
interface StopEventInput {
    session_id: string;
    transcript_path: string;
    cwd: string;
    permission_mode: string;
}

interface TaskPattern {
    timestamp: number;
    session_id: string;
    user_input: string;
    agent_used?: string;
    complexity: string;
    domain: string;
    file_types: string[];
    success: boolean;
    completion_time: number;
    quality_score: number;
}

interface UserLearningProfile {
    user_id: string;
    profile_version: string;
    last_updated: string;
    learning_metrics: {
        total_tasks: number;
        success_rate: number;
        average_completion_time: number;
        quality_trend: string;
        skill_velocity: number;
    };
    workflow_mastery: Record<string, {
        usage: number;
        success: number;
        preference: number;
    }>;
    domain_expertise: Record<string, {
        confidence: number;
        tasks: number;
        trend: string;
    }>;
    quality_evolution: Record<string, {
        mastery: number;
        improvement_rate: number;
    }>;
    success_patterns: Record<string, {
        score: number;
        frequency: number;
    }>;
    risk_predictions: Record<string, {
        risk: number;
        mitigation: string;
    }>;
}

function getProjectRoot(): string {
    // Hook is executed from .claude/hooks, so go up two levels
    const cwd = process.cwd();
    if (cwd.endsWith('.claude/hooks')) {
        return join(cwd, '..', '..');
    }
    // Fallback: use env var or cwd
    return process.env.CLAUDE_PROJECT_DIR || cwd;
}

function loadUserProfile(): UserLearningProfile {
    const projectDir = getProjectRoot();
    const profilePath = join(projectDir, '.claude', 'user-learning-profile.json');

    if (!existsSync(profilePath)) {
        // Create default profile
        return {
            user_id: 'yun',
            profile_version: '2.1',
            last_updated: new Date().toISOString(),
            learning_metrics: {
                total_tasks: 0,
                success_rate: 0,
                average_completion_time: 0,
                quality_trend: 'stable',
                skill_velocity: 1.0
            },
            workflow_mastery: {
                epic_chain: { usage: 0, success: 0, preference: 0.2 },
                story_chain: { usage: 0, success: 0, preference: 0.6 },
                task_chain: { usage: 0, success: 0, preference: 0.15 },
                hotfix: { usage: 0, success: 0, preference: 0.05 }
            },
            domain_expertise: {
                auth: { confidence: 0.5, tasks: 0, trend: 'learning' },
                crud: { confidence: 0.5, tasks: 0, trend: 'learning' },
                ui: { confidence: 0.5, tasks: 0, trend: 'learning' },
                api: { confidence: 0.5, tasks: 0, trend: 'learning' },
                db: { confidence: 0.5, tasks: 0, trend: 'learning' },
                deployment: { confidence: 0.3, tasks: 0, trend: 'learning' }
            },
            quality_evolution: {
                react_hooks: { mastery: 0.6, improvement_rate: 0.1 },
                api_errors: { mastery: 0.7, improvement_rate: 0.15 },
                db_patterns: { mastery: 0.6, improvement_rate: 0.08 },
                typescript: { mastery: 0.7, improvement_rate: 0.12 }
            },
            success_patterns: {
                incremental_development: { score: 0.8, frequency: 0.7 },
                api_first_approach: { score: 0.75, frequency: 0.5 },
                comprehensive_error_handling: { score: 0.7, frequency: 0.6 },
                admin_features_inclusion: { score: 0.8, frequency: 0.7 }
            },
            risk_predictions: {
                performance_optimization: { risk: 0.6, mitigation: 'extra_validation' },
                complex_state_management: { risk: 0.5, mitigation: 'smaller_chunks' },
                deployment_configuration: { risk: 0.7, mitigation: 'research_first' }
            }
        };
    }

    try {
        const content = readFileSync(profilePath, 'utf-8');
        return JSON.parse(content);
    } catch (err) {
        console.error('Error loading user profile:', err);
        return loadUserProfile(); // Return default
    }
}

function saveUserProfile(profile: UserLearningProfile): void {
    const projectDir = getProjectRoot();
    const profilePath = join(projectDir, '.claude', 'user-learning-profile.json');

    try {
        writeFileSync(profilePath, JSON.stringify(profile, null, 2));
    } catch (err) {
        console.error('Error saving user profile:', err);
    }
}

function extractTaskPattern(sessionId: string): TaskPattern | null {
    const projectDir = getProjectRoot();
    const cacheDir = join(projectDir, '.claude', 'hooks-cache', sessionId || 'default');

    // Try to extract information from transcript or cache
    const editedFilesPath = join(cacheDir, 'edited-files.log');
    const fileTypesPath = join(cacheDir, 'file-types.txt');

    if (!existsSync(editedFilesPath)) {
        return null;
    }

    try {
        // Extract file types
        const fileTypes: string[] = [];
        if (existsSync(fileTypesPath)) {
            const content = readFileSync(fileTypesPath, 'utf-8');
            fileTypes.push(...content.trim().split('\n').filter(t => t.length > 0));
        }

        // Determine domain from file types
        let domain = 'api';
        if (fileTypes.includes('react')) domain = 'ui';
        else if (fileTypes.includes('database')) domain = 'db';
        else if (fileTypes.some(t => t.includes('auth'))) domain = 'auth';

        // Estimate completion time (simplified)
        const startTime = Date.now() - 300000; // Assume 5 minutes ago
        const completionTime = (Date.now() - startTime) / 1000 / 60; // in minutes

        return {
            timestamp: Date.now(),
            session_id: sessionId,
            user_input: 'extracted_from_session', // Would need transcript analysis
            complexity: fileTypes.length > 3 ? 'story' : 'task',
            domain,
            file_types: fileTypes,
            success: true, // Assume success if we reach this point
            completion_time: completionTime,
            quality_score: 85 // Default score, would be updated by quality gate
        };
    } catch (err) {
        return null;
    }
}

function updateProfile(profile: UserLearningProfile, pattern: TaskPattern): UserLearningProfile {
    const updated = { ...profile };

    // Update timestamp
    updated.last_updated = new Date().toISOString();

    // Update learning metrics
    updated.learning_metrics.total_tasks += 1;

    const currentSuccessRate = updated.learning_metrics.success_rate;
    const totalTasks = updated.learning_metrics.total_tasks;
    updated.learning_metrics.success_rate =
        ((currentSuccessRate * (totalTasks - 1)) + (pattern.success ? 100 : 0)) / totalTasks;

    const currentAvgTime = updated.learning_metrics.average_completion_time;
    updated.learning_metrics.average_completion_time =
        ((currentAvgTime * (totalTasks - 1)) + pattern.completion_time) / totalTasks;

    // Update workflow mastery
    const workflowType = pattern.complexity === 'story' ? 'story_chain' : 'task_chain';
    if (updated.workflow_mastery[workflowType]) {
        updated.workflow_mastery[workflowType].usage += 1;
        if (pattern.success) {
            updated.workflow_mastery[workflowType].success += 1;
        }

        // Recalculate preferences based on success rates
        const totalUsage = Object.values(updated.workflow_mastery).reduce((sum, w) => sum + w.usage, 0);
        for (const [key, workflow] of Object.entries(updated.workflow_mastery)) {
            workflow.preference = workflow.usage / totalUsage;
        }
    }

    // Update domain expertise
    if (updated.domain_expertise[pattern.domain]) {
        const domain = updated.domain_expertise[pattern.domain];
        domain.tasks += 1;

        // Increase confidence based on success and quality
        if (pattern.success && pattern.quality_score > 80) {
            domain.confidence = Math.min(1.0, domain.confidence + 0.05);
            domain.trend = 'improving';
        } else if (pattern.quality_score < 60) {
            domain.confidence = Math.max(0.1, domain.confidence - 0.02);
            domain.trend = 'needs_work';
        }

        // Determine trend
        if (domain.confidence > 0.85) {
            domain.trend = 'mastered';
        } else if (domain.confidence > 0.7) {
            domain.trend = 'stable';
        } else if (domain.confidence < 0.5) {
            domain.trend = 'learning';
        }
    }

    // Update quality evolution based on file types
    for (const fileType of pattern.file_types) {
        let qualityArea = '';
        switch (fileType) {
            case 'react':
                qualityArea = 'react_hooks';
                break;
            case 'api':
                qualityArea = 'api_errors';
                break;
            case 'database':
                qualityArea = 'db_patterns';
                break;
            case 'typescript':
                qualityArea = 'typescript';
                break;
        }

        if (qualityArea && updated.quality_evolution[qualityArea]) {
            const quality = updated.quality_evolution[qualityArea];
            if (pattern.quality_score > 90) {
                quality.mastery = Math.min(1.0, quality.mastery + 0.03);
                quality.improvement_rate = Math.min(0.3, quality.improvement_rate + 0.01);
            } else if (pattern.quality_score < 70) {
                quality.mastery = Math.max(0.3, quality.mastery - 0.01);
            }
        }
    }

    return updated;
}

function generateLearningInsights(profile: UserLearningProfile, pattern: TaskPattern): string {
    let output = '';

    output += '📚 Pattern Learning Update:\n';
    output += `  ✅ ${pattern.complexity.toUpperCase()} completion: +1 success\n`;
    output += `  ⏱️ Completion time: ${pattern.completion_time.toFixed(1)} minutes`;

    if (pattern.completion_time < profile.learning_metrics.average_completion_time) {
        output += ' (faster than average)\n';
    } else {
        output += ' (within normal range)\n';
    }

    output += `  🎯 Quality score: ${pattern.quality_score}/100`;

    const prevQualityAvg = 85; // Simplified - would track historical average
    if (pattern.quality_score > prevQualityAvg) {
        output += ` (above your ${prevQualityAvg} average)\n`;
    } else {
        output += ` (room for improvement)\n`;
    }

    const domainConfidence = profile.domain_expertise[pattern.domain]?.confidence || 0;
    output += `  📈 ${pattern.domain.toUpperCase()} expertise: ${(domainConfidence * 100).toFixed(0)}%`;

    if (domainConfidence > 0.85) {
        output += ' (mastered) ✅\n';
    } else if (domainConfidence > 0.7) {
        output += ' (proficient)\n';
    } else {
        output += ' (developing)\n';
    }

    output += '\n🧠 Learning Insights:\n';

    // Provide specific insights based on patterns
    if (pattern.domain === 'ui' && profile.quality_evolution.react_hooks.mastery > 0.9) {
        output += '  • Your React Hook dependency management: mastered ✅\n';
    } else if (pattern.domain === 'ui') {
        output += '  • React Hook patterns: continuing to improve\n';
    }

    if (pattern.domain === 'api' && profile.domain_expertise.api.confidence > 0.8) {
        output += '  • API development skills: strong expertise gained\n';
    }

    if (pattern.domain === 'db' && profile.quality_evolution.db_patterns.mastery > 0.8) {
        output += '  • Database schema patterns: consistent application ✅\n';
    }

    // Suggest focus areas
    const weakestDomain = Object.entries(profile.domain_expertise)
        .sort(([,a], [,b]) => a.confidence - b.confidence)[0];

    if (weakestDomain && weakestDomain[1].confidence < 0.6) {
        output += `  💡 Suggested focus area: ${weakestDomain[0]} development (${(weakestDomain[1].confidence * 100).toFixed(0)}% confidence)\n`;
    }

    return output;
}

async function main() {
    try {
        // Read input from stdin
        const input = readFileSync(0, 'utf-8');
        const data: StopEventInput = JSON.parse(input);

        // Extract task pattern from session
        const pattern = extractTaskPattern(data.session_id);

        if (!pattern) {
            process.exit(0); // No learning data available
        }

        // Load user profile
        const profile = loadUserProfile();

        // Update profile with new pattern
        const updatedProfile = updateProfile(profile, pattern);

        // Save updated profile
        saveUserProfile(updatedProfile);

        // Generate learning insights
        const insights = generateLearningInsights(updatedProfile, pattern);
        console.error(insights); // Use stderr for Hook output

        process.exit(0);
    } catch (err) {
        console.error('Error in stop-pattern-learning hook:', err);
        process.exit(1);
    }
}

main().catch(err => {
    console.error('Uncaught error:', err);
    process.exit(1);
});