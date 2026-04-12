#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const logFile = path.join(__dirname, 'hook-minimal.log');

try {
    const chunks = [];
    process.stdin.on('data', chunk => chunks.push(chunk));
    process.stdin.on('end', () => {
        try {
            const input = Buffer.concat(chunks).toString('utf-8');
            const data = JSON.parse(input);

            fs.appendFileSync(logFile, `[${new Date().toISOString()}] Received: ${data.prompt}\n`);

            // Minimal output
            process.stdout.write('Hook OK\n');

            fs.appendFileSync(logFile, 'Completed\n');
            process.exit(0);
        } catch (err) {
            fs.appendFileSync(logFile, `Parse error: ${err.message}\n`);
            process.exit(1);
        }
    });
} catch (err) {
    fs.appendFileSync(logFile, `Error: ${err.message}\n`);
    process.exit(1);
}
