#!/bin/bash
set -euo pipefail

other_taxids="HUMAN_9606"

echo "uniprot	refseq"
for taxid in ${other_taxids//,/ }; do
	url="ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/idmapping/by_organism/${taxid}_idmapping.dat.gz"
	# --fail/--retry/--max-time as in retrieve_glycoinfo.sh. grep is wrapped with `|| true` since
	# "zero RefSeq_NT lines" is valid output, not a failure - under pipefail an un-wrapped grep
	# would otherwise make the whole pipeline (wrongly) look like it failed whenever that happens,
	# while still correctly surfacing an actual curl/gunzip failure (pipefail reports the exit
	# status of whichever stage actually failed, not just the last one).
	curl --fail --silent --show-error --retry 3 --retry-delay 5 --connect-timeout 10 --max-time 300 "$url" \
		| gunzip | { grep 'RefSeq_NT' || true; } | awk -F$'\t' '{ print $1 FS $3 }'
done