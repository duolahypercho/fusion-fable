#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';

const DEFAULT_SOURCE_URL = 'https://raw.githubusercontent.com/elder-plinius/CL4R1T4S/refs/heads/main/ANTHROPIC/CLAUDE-FABLE-5.md';
const sourceUrl = process.env.FUSION_FABLE_SOURCE_URL || DEFAULT_SOURCE_URL;
const outputPath = process.env.FUSION_FABLE_SOURCE_PROMPT_PATH
  || path.join(process.cwd(), 'config', 'fusion-fable-source-prompt.md');
const attributionPath = outputPath.replace(/\.md$/i, '.attribution.md');

const res = await fetch(sourceUrl, {
  headers: {
    'User-Agent': 'pinchpoint-fusion-fable-source-sync/1.0',
  },
});

if (!res.ok) {
  throw new Error(`Failed to fetch ${sourceUrl}: HTTP ${res.status}`);
}

const text = await res.text();
if (!text.trim().startsWith('# Claude Fable 5')) {
  throw new Error('Fetched source did not look like the expected Claude Fable 5 prompt');
}

await fs.mkdir(path.dirname(outputPath), { recursive: true });
await fs.writeFile(outputPath, text.trimEnd() + '\n', 'utf8');
await fs.writeFile(
  attributionPath,
  [
    '# Fusion-Fable Source Prompt Attribution',
    '',
    `Source URL: ${sourceUrl}`,
    'Repository: elder-plinius/CL4R1T4S',
    'Repository license observed: AGPL-3.0',
    `Fetched at: ${new Date().toISOString()}`,
    '',
    'The adjacent fusion-fable-source-prompt.md file is a synced local source used by the Pinchpoint Claude Max proxy Fusion-Fable profile when FUSION_FABLE_USE_SOURCE_PROMPT is not set to 0.',
  ].join('\n') + '\n',
  'utf8',
);

console.log(JSON.stringify({
  ok: true,
  sourceUrl,
  outputPath,
  attributionPath,
  chars: text.length,
}));
