#!/bin/bash

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
	mv json/sources_glycosylation.json "$outdir/glycosylation-$taxid.json"
	head -3 "$outdir/glycosylation-$taxid.json"
done

bash ./retrieve_mappings.sh > sources/mappings.tsv

runrecipe --input sources --output json --env version="$TARGETVERSION" --env git="$GIT_STATUS" --env timestamp="$(date -u +%FT%TZ)" --env taxid="$taxid"

mv json/sources_refseqnt.json $outdir/refseqnt.json
