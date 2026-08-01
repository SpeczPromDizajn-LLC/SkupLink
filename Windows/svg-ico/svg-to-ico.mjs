#!/usr/bin/env node
/** SVG → ICO converter. Usage: node svg-to-ico.mjs <input.svg> <output.ico> [--sizes 16,24,...] — see README. */

import { writeFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';
import sharp from 'sharp';
import pngToIco from 'png-to-ico';

const DEFAULT_SIZES = [16, 24, 32, 48, 64, 128, 256];

function printUsage() {
  console.error(`Usage:
  node svg-to-ico.mjs <input.svg> <output.ico> [--sizes 16,24,32,48,64,128,256]

Examples:
  node svg-to-ico.mjs ../SkupLinkService/web/favicon.svg SkupLink.ico
  node svg-to-ico.mjs logo.svg app.ico --sizes 16,32,48,256`);
}

function parseArgs(argv) {
  const positional = [];
  let sizes = DEFAULT_SIZES;

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];

    if (arg === '--sizes') {
      const value = argv[++i];
      if (!value) {
        throw new Error('Missing value for --sizes');
      }
      sizes = value
        .split(',')
        .map((s) => Number(s.trim()))
        .filter((n) => Number.isInteger(n) && n > 0);
      if (!sizes.length) {
        throw new Error('Invalid --sizes list');
      }
      continue;
    }

    if (arg === '-h' || arg === '--help') {
      return { help: true };
    }

    if (arg.startsWith('-')) {
      throw new Error(`Unknown option: ${arg}`);
    }

    positional.push(arg);
  }

  if (positional.length !== 2) {
    throw new Error('Expected <input.svg> and <output.ico>');
  }

  return {
    help: false,
    input: resolve(positional[0]),
    output: resolve(positional[1]),
    sizes: [...new Set(sizes)].sort((a, b) => a - b),
  };
}

async function renderPng(inputPath, size) {
  return sharp(inputPath, { density: Math.max(72, size * 2) })
    .resize(size, size, {
      fit: 'contain',
      background: { r: 0, g: 0, b: 0, alpha: 0 },
    })
    .png()
    .toBuffer();
}

async function main() {
  let opts;
  try {
    opts = parseArgs(process.argv.slice(2));
  } catch (err) {
    console.error(String(err.message || err));
    printUsage();
    process.exit(1);
  }

  if (opts.help) {
    printUsage();
    process.exit(0);
  }

  if (!existsSync(opts.input)) {
    console.error(`Input not found: ${opts.input}`);
    process.exit(1);
  }

  const pngs = [];
  for (const size of opts.sizes) {
    pngs.push(await renderPng(opts.input, size));
  }

  const ico = await pngToIco(pngs);
  writeFileSync(opts.output, ico);

  console.log(`Wrote ${opts.output}`);
  console.log(`Sizes: ${opts.sizes.join(', ')}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
