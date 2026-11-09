#!/bin/bash
# set -e: retrieve_glycoinfo.sh/retrieve_mappings.sh now fail loudly on a bad download (see their
# own comments), but nothing here was checking their exit status - without -e, a failed retrieve
# left sources/*.tsv empty/truncated and run_taxonomies.sh carried on into runrecipe anyway, which
# crashed far from the real cause with an opaque, taxid-less stack trace.
set -e

taxids=$1
outdir=${2:-/dist}
workdir=${3:-/work}

# GIT_STATUS/TARGETVERSION were referenced here but never actually set anywhere (not in the
# Dockerfile, not by the orchestrator) - every published file's data-version silently defaulted to
# "unknown" regardless of success or failure. GIT_STATUS: this repo's own commit (pipeline
# version) - allow an existing env var to win so a caller can still override it.
GIT_STATUS="${GIT_STATUS:-$(git rev-parse HEAD 2>/dev/null || echo unknown)}"

if [ ! -e "$outdir" ]; then
	mkdir "$outdir";
fi

touch sources/mappings.tsv

# Per-taxid cache of the last successfully published glycosylation-<taxid>.json, on the
# orchestrator's persistent /work mount (survives across quarterly runs) - used as a fallback below
# when a live UniProt fetch fails, so one bad quarter for UniProt doesn't mean zero data for a
# species we've successfully built before.
cachedir="$workdir/glycosylation-cache"
mkdir -p "$cachedir"

for taxid in ${taxids//,/ }; do
	echo "Retrieving glycosylation data for $taxid"
	if bash ./retrieve_glycoinfo.sh $taxid > sources/glycosylation.tsv; then
		# TARGETVERSION: the real UniProt release this data just came from (see
		# retrieve_glycoinfo.sh - there's no way to request a specific past release, only observe
		# which one we got), so a fresh file is correctly stamped instead of "unknown".
		TARGETVERSION=$(cat uniprot_release.txt 2>/dev/null || echo unknown)
		runrecipe --input sources --output json --env version="$TARGETVERSION" --env git="$GIT_STATUS" --env timestamp="$(date -u +%FT%TZ)" --env taxid="$taxid"
		if node normalize_sites_cli.js json/sources_glycosylation.json "$outdir/glycosylation-$taxid.json"; then
			head -3 "$outdir/glycosylation-$taxid.json"
			cp "$outdir/glycosylation-$taxid.json" "$cachedir/$taxid.json"
		else
			echo "Skipping $taxid - no glycosylation records"
			# A live fetch just reconfirmed zero records for real - don't let a stale "had some,
			# a while back" cache paper over that the next time a live fetch merely fails to connect.
			rm -f "$cachedir/$taxid.json"
		fi
	elif [ -e "$cachedir/$taxid.json" ]; then
		cached_version=$(node -e "console.log((JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8')).metadata || {})['data-version'] || 'unknown')" "$cachedir/$taxid.json")
		echo "WARNING: live UniProt fetch failed for $taxid - falling back to the cached build from UniProt release $cached_version"
		cp "$cachedir/$taxid.json" "$outdir/glycosylation-$taxid.json"
	else
		echo "WARNING: live UniProt fetch failed for $taxid and no cached fallback is available - skipping"
	fi
	# UniProt rate-limits by request rate, not just concurrency - firing one REST request per taxid
	# back-to-back across all 9 organisms with nothing in between is what triggered 429s here. A
	# small gap costs little against a once-a-quarter job and makes the limit much less likely to
	# trip at all, on top of retrieve_glycoinfo.sh's own retry/backoff.
	sleep 3
done

bash ./retrieve_mappings.sh > sources/mappings.tsv

runrecipe --input sources --output json --env version="$TARGETVERSION" --env git="$GIT_STATUS" --env timestamp="$(date -u +%FT%TZ)" --env taxid="$taxid"

# refseqnt.json is an accession->RefSeq mapping table, not an msdata glycoproteomics data build (no
# species/sample, mimetype: application/json) - kept out from under $outdir's msdata files (one
# level deeper, in mappings/) so it isn't picked up by validate.mjs's /data-builds/*/*.json scan.
mkdir -p "$outdir/mappings"
mv json/sources_refseqnt.json "$outdir/mappings/refseqnt.json"
