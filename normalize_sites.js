'use strict';

// Brings glycosylation-<taxid>.json up to the msdata 2.0 sites format (see
// /workspaces/published-sitedata/data_schema/TODO.md's "Sites" section and its mapping table for
// what "sites: [position, marker]" tuples become, and the "curated" row of that table
// specifically for how UniProt's own curated annotations map to observed/inferred).
//
// UniProt's bare "Man" marker is ambiguous between O-Man (Ser/Thr) and C-Man (Trp) - the
// conversion from UniProt's raw feature text already collapsed that distinction away by the time
// it reaches sites.json, so it's resolved here from a prebuilt classification (see
// fetch_man_classification.js, which checks the real residue at each site's position, including
// historical sequence versions where the current sequence has since been revised - re-run it
// if new taxonomies or new "Man" sites are added).
const MAN_CLASS = require('./man_classification.json');

const UNKNOWN_VERSION = 'unknown';
const MSDATA_VERSION = '2.0';

// Collapsed composition labels that aren't simple bare residues - decomposed into the schema's
// fixed composition vocabulary (Hex, HexHex, HexHexNAc, HexNAc, dHex, Pent, HexA, NeuAc, NeuGc,
// Sia, Phospho, Sulfo).
const COMPOSITE_MARKERS = {
    Man6P: '1xHex1xPhospho',
    GlcNAc6P: '1xHexNAc1xPhospho',
    GlcA: '1xHexA',
};

function convertMarker(marker, accession, position) {
    if (marker === 'GlcNAc(b1-4)GlcNAc') {
        return { inferred: ['N'] };
    }
    if (marker === 'GalNAc') {
        return { inferred: ['OGalNAc'] };
    }
    if (marker === 'GlcNAc') {
        // Bare GlcNAc (not the N-glycan chitobiose marker above) is UniProt's annotation for
        // cytoplasmic/nuclear O-GlcNAc, a modification distinct from N-glycosylation.
        return { inferred: ['OGlcNAc'] };
    }
    if (marker === 'Man') {
        const cls = MAN_CLASS[accession + '\t' + position];
        if (!cls) {
            throw new Error(`normalize_sites: no O-Man/C-Man classification for ${accession} position ${position}`);
        }
        return { inferred: [cls] };
    }
    if (marker === 'Glc') {
        return { inferred: ['OGlc'] };
    }
    if (marker === 'Gal') {
        return { inferred: ['OGal'] };
    }
    if (marker === 'Fuc') {
        return { inferred: ['OFuc'] };
    }
    if (marker === 'Xyl') {
        return { inferred: ['GAG'] };
    }
    if (marker === 'Man6P') {
        // A phosphorylated mannose on Ser/Thr is still structurally an O-Man glycan.
        return { observed: COMPOSITE_MARKERS[marker], inferred: ['OMan'] };
    }
    if (COMPOSITE_MARKERS[marker]) {
        // GlcNAc6P, GlcA alone: real composition, but no existing glycan-classes.json entry
        // matches a bare occurrence confidently - observed only, no class concluded.
        return { observed: COMPOSITE_MARKERS[marker] };
    }
    if (marker === 'HexNAc' || marker === 'Hex') {
        // Genuinely ambiguous (could be either N- or O-linked, or several different classes) -
        // no dataset-wide certainty the way e.g. a SimpleCell line gives published-sitedata.
        return { observed: '1x' + marker };
    }
    throw new Error(`normalize_sites: unrecognised site marker ${JSON.stringify(marker)}`);
}

function convertSites(entry, accession) {
    const converted = (entry.sites || []).map(([position, marker]) => {
        const result = convertMarker(marker, accession, position);
        const site = { position };
        if (result.observed !== undefined) {
            site.observed = result.observed;
        }
        if (result.inferred !== undefined) {
            site.inferred = result.inferred;
        }
        return site;
    });
    if (converted.length) {
        entry.sites = converted;
    } else {
        delete entry.sites;
    }
}

function fixSoftwareEntry(entry) {
    if (!entry.version) {
        entry.version = UNKNOWN_VERSION;
    }
}

function normalize(doc) {
    if (!doc || !doc.metadata || doc.metadata.mimetype !== 'application/json+msdata') {
        return doc;
    }
    doc.metadata['msdata-version'] = MSDATA_VERSION;
    doc.metadata['site_method'] = 'curated';
    if (!doc.metadata['data-version']) {
        doc.metadata['data-version'] = UNKNOWN_VERSION;
    }
    (doc.metadata.software || []).forEach(fixSoftwareEntry);

    const usedClasses = new Set();
    Object.keys(doc.data || {}).forEach((accession) => {
        doc.data[accession].forEach((entry) => convertSites(entry, accession));
        doc.data[accession] = doc.data[accession].filter((entry) => entry.sites && entry.sites.length);
        doc.data[accession].forEach((entry) => (entry.sites || []).forEach((s) => (s.inferred || []).forEach((id) => usedClasses.add(id))));
        if (doc.data[accession].length === 0) {
            delete doc.data[accession];
        }
    });

    if (usedClasses.size) {
        // Vendored from published-sitedata/data_schema/glycan-classes.json (the shared source of
        // truth) - copy, not a cross-repo reference, since this converter has to be deployable on
        // its own. Keep in sync if glycan-classes.json changes.
        const GLYCAN_CLASSES = require('./glycan-classes.json');
        doc.metadata.glycan_classes = {};
        [...usedClasses].sort().forEach((id) => {
            doc.metadata.glycan_classes[id] = GLYCAN_CLASSES[id];
        });
    }

    return doc;
}

module.exports = { normalize };
