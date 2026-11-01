#!/usr/bin/env node
'use strict';

// CLI wrapper for normalize_sites.js: reads a recipe-runner glycosylation output file, normalizes
// it to the 2.0 sites format, and writes the result back out. If the species has no glycosylation
// records at all, writes nothing and exits non-zero so run_taxonomies.sh can skip publishing it
// (data_schema/TODO.md: "regenerate, or delete it if the species has no UniProt glycosylation
// records" - confirmed by querying UniProt directly that some species, e.g. S. pombe/284812,
// genuinely have zero experimentally-verified sites right now).
const fs = require('fs');
const { normalize } = require('./normalize_sites');

const [, , inputPath, outputPath] = process.argv;
if (!inputPath || !outputPath) {
    console.error('usage: normalize_sites_cli.js <input.json> <output.json>');
    process.exit(2);
}

const doc = normalize(JSON.parse(fs.readFileSync(inputPath, 'utf8')));

if (doc.metadata.mimetype === 'application/json+msdata' && Object.keys(doc.data || {}).length === 0) {
    console.error(`normalize_sites_cli: ${inputPath} has no glycosylation records - not writing ${outputPath}`);
    process.exit(1);
}

fs.writeFileSync(outputPath, JSON.stringify(doc));
