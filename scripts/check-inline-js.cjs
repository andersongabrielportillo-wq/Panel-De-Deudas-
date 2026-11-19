#!/usr/bin/env node
// Parse every inline script in the integrated PWA without executing it.
const fs = require('node:fs');
const vm = require('node:vm');
const files = ['index.html', 'staging/index.html'];
let failed = false;
for (const file of files) {
  const html = fs.readFileSync(file, 'utf8');
  const scripts = [...html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)];
  let checked = 0;
  for (const [, attrs, source] of scripts) {
    if (/\bsrc\s*=/.test(attrs) || !source.trim()) continue;
    if (/\btype\s*=\s*["'](?:application\/json|importmap)["']/.test(attrs)) continue;
    try {
      new vm.Script(source, {filename: file + ':inline-script-' + (++checked)});
    } catch (error) {
      failed = true;
      console.error(error.stack || String(error));
    }
  }
  console.log(file + ': ' + checked + ' inline scripts checked');
}
if (failed) process.exitCode = 1;
