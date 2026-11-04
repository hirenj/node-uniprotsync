#!/bin/bash
# set -e: retrieve_glycoinfo.sh/retrieve_mappings.sh now fail loudly on a bad download (see their
# own comments), but nothing here was checking their exit status - without -e, a failed retrieve
# left sources/*.tsv empty/truncated and run_taxonomies.sh carried on into runrecipe anyway, which
# crashed far from the real cause with an opaque, taxid-less stack trace.
set -e

taxids=$1
outdir=${2:-/dist}

if [ ! -e "$outdir" ]; then
	mkdir "$outdir";
fi

touch sources/mappings.tsv

for taxid in ${taxids//,/ }; do
	echo "Retrieving glycosylation data for $taxid"
	bash ./retrieve_glycoinfo.sh $taxid > sources/glycosylation.tsv
	runrecipe --input sources --output json --env version="$TARGETVERSION" --env git="$GIT_STATUS" --env timestamp="$(date -u +%FT%TZ)" --env taxid="$taxid"
	if [ "$?" -gt 0 ]; then
		exit 1
	fi
	if node normalize_sites_cli.js json/sources_glycosylation.json "$outdir/glycosylation-$taxid.json"; then
		head -3 "$outdir/glycosylation-$taxid.json"
	else
		echo "Skipping $taxid - no glycosylation records"
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
