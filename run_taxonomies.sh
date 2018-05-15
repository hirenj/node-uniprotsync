#!/bin/bash

taxids=$1

if [ ! -e dist ]; then
	mkdir dist;
fi

echo "uniprot\trefseq" > sources/mappings.tsv

for taxid in ${taxids//,/ }; do
	echo "Retrieving glycosylation data for $taxid"
	bash ./retrieve_glycoinfo.sh $taxid > sources/glycosylation.tsv
	runrecipe --input sources --output json --env version="$TARGETVERSION" --env git="$GIT_STATUS" --env timestamp="$(date -u +%FT%TZ)" --env taxid="$taxid"
	mv json/sources_glycosylation.json dist/glycosylation-$taxid.json
	head -3 dist/glycosylation-$taxid.json
done

bash ./retrieve_mappings.sh > sources/mappings.tsv

runrecipe --input sources --output json --env version="$TARGETVERSION" --env git="$GIT_STATUS" --env timestamp="$(date -u +%FT%TZ)" --env taxid="$taxid"

mv json/sources_refseqnt.json dist/refseqnt.json
