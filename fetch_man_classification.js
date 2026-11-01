'use strict';

// Builds man_classification.json: for every bare "Man" site in the glycosylation-<taxid>.json
// files, which glycan class it really is - O-Man (on Ser/Thr) or C-Man (on Trp) - a distinction
// UniProt's own raw feature text keeps (e.g. "C-linked (Man) tryptophan") but this converter's
// recipe collapses away into a single "Man" composition token before it reaches sites.json.
// Resolved by checking the real residue at each site's position in the protein's UniProt
// sequence - falling back to older sequence versions (via UniSave) for the rare case where the
// current sequence has since been revised and no longer has the expected residue there.
//
// Run this again (from this directory, with network access) whenever a new taxonomy is added or
// UniProt's annotations change - it's not run automatically as part of the normal build, since it
// needs network access and the result rarely changes.
const fs = require('fs');
const path = require('path');

const OUTPUT_DIR = process.argv[2] || path.join(__dirname, 'output');

function collectManSites() {
    const sites = [];
    fs.readdirSync(OUTPUT_DIR).filter((f) => f.startsWith('glycosylation')).forEach((file) => {
        const doc = JSON.parse(fs.readFileSync(path.join(OUTPUT_DIR, file)));
        Object.entries(doc.data || {}).forEach(([accession, entries]) => {
            entries.forEach((entry) => {
                (entry.sites || []).forEach(([position, marker]) => {
                    if (marker === 'Man') {
                        sites.push({ accession, position });
                    }
                });
            });
        });
    });
    return sites;
}

async function fetchCurrentSequences(accessions) {
    const sequences = {};
    const BATCH = 150;
    for (let i = 0; i < accessions.length; i += BATCH) {
        const batch = accessions.slice(i, i + BATCH);
        const res = await fetch(`https://rest.uniprot.org/uniprotkb/accessions?accessions=${batch.join(',')}&fields=accession,sequence&format=json`);
        const json = await res.json();
        (json.results || []).forEach((r) => {
            if (r.sequence && r.sequence.value) {
                sequences[r.primaryAccession] = r.sequence.value;
            }
        });
    }
    return sequences;
}

async function fetchHistoricalSequence(accession) {
    const historyRes = await fetch(`https://rest.uniprot.org/unisave/${accession}?format=json`);
    if (!historyRes.ok) {
        return null;
    }
    const history = await historyRes.json();
    const versions = [...new Set((history.results || []).map((r) => r.sequenceVersion))].sort((a, b) => b - a);
    for (const version of versions) {
        const res = await fetch(`https://rest.uniprot.org/unisave/${accession}?format=fasta&versions=${version}`);
        if (!res.ok) {
            continue;
        }
        const text = await res.text();
        const seq = text.split('\n').slice(1).join('').trim();
        if (seq) {
            return seq;
        }
    }
    return null;
}

(async () => {
    const sites = collectManSites();
    const accessions = [...new Set(sites.map((s) => s.accession))];
    console.log(`${sites.length} Man sites across ${accessions.length} accessions`);

    const sequences = await fetchCurrentSequences(accessions);
    const classification = {};
    const needsHistory = [];

    sites.forEach(({ accession, position }) => {
        const seq = sequences[accession];
        const residue = seq ? seq[position - 1] : undefined;
        if (residue === 'W') {
            classification[`${accession}\t${position}`] = 'CMan';
        } else if (residue === 'S' || residue === 'T') {
            classification[`${accession}\t${position}`] = 'OMan';
        } else {
            needsHistory.push({ accession, position });
        }
    });

    if (needsHistory.length) {
        console.log(`${needsHistory.length} sites didn't match W/S/T in the current sequence - checking UniSave history`);
        const historyCache = {};
        for (const { accession, position } of needsHistory) {
            if (!(accession in historyCache)) {
                historyCache[accession] = await fetchHistoricalSequence(accession);
            }
            const seq = historyCache[accession];
            const residue = seq ? seq[position - 1] : undefined;
            if (residue === 'W') {
                classification[`${accession}\t${position}`] = 'CMan';
            } else if (residue === 'S' || residue === 'T') {
                classification[`${accession}\t${position}`] = 'OMan';
            } else {
                throw new Error(`fetch_man_classification: ${accession} position ${position} is still not W/S/T (got ${JSON.stringify(residue)}) even in historical sequences - needs manual review`);
            }
        }
    }

    fs.writeFileSync(path.join(__dirname, 'man_classification.json'), JSON.stringify(classification));
    const counts = {};
    Object.values(classification).forEach((c) => { counts[c] = (counts[c] || 0) + 1; });
    console.log('done:', counts);
})();
