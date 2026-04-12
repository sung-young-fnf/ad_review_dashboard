#!/usr/bin/env node
import { readFileSync, writeFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

interface HookInput {
    session_id: string;
    transcript_path: string;
    cwd: string;
    permission_mode: string;
    prompt: string;
}

async function main() {
    const logFile = join(__dirname, 'hook-simple.log');
    try {
        const input = readFileSync(0, 'utf-8');
        const data: HookInput = JSON.parse(input);

        writeFileSync(logFile, `[${new Date().toISOString()}] Prompt: ${data.prompt}\n`, { flag: 'a' });

        // Simple output with explicit flush
        const output = '✅ UserPromptSubmit Hook is working!\n' +
                      `📝 Your prompt: "${data.prompt}"\n`;

        process.stdout.write(output);

        // Wait for stdout to flush
        await new Promise(resolve => process.stdout.write('', resolve));

        writeFileSync(logFile, `Hook completed\n`, { flag: 'a' });
        process.exit(0);
    } catch (err) {
        writeFileSync(logFile, `ERROR: ${err}\n`, { flag: 'a' });
        process.stderr.write(`Hook error: ${err}\n`);
        process.exit(1);
    }
}

main();
