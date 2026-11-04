#!/bin/bash
# pipefail: without it, `if [ $? -gt 0 ]` below only ever saw the last sed's exit status, never
# curl's - a stalled/failing request (e.g. UniProt REST timing out or returning an error page)
# went undetected and run_taxonomies.sh carried on feeding the resulting empty/garbage tsv into
# runrecipe, which failed much later with an opaque crash far from the real cause.
set -euo pipefail

taxids=$1

echo "uniprot	glyco"
for taxid in ${taxids//,/ }; do
	url="https://rest.uniprot.org/uniprotkb/stream?fields=accession,ft_carbohyd&format=tsv&query=organism_id:$taxid%20AND%20(ft_carbohyd_exp:*)"
	# --fail: treat HTTP error responses as failures, not as "successfully downloaded an error page".
	# --retry/--retry-delay: ride out transient UniProt hiccups. --max-time: give up on a stalled
	# connection instead of trickling for minutes before failing anyway.
	curl --fail --silent --show-error --retry 3 --retry-delay 5 --connect-timeout 10 --max-time 300 "$url" \
		| tail -n+2 | sed -e 's/e;/e/g' -e 's/0000244/0000269/' -e 's/0007013/0000269/' -e 's/0008037/0000269/' -e 's/0008035/0000269/' -e 's/0007014/0000269/' -e 's/0000245/0000269/' -e 's/0007675/0000269/' -e 's/0007744/0000269/'
done