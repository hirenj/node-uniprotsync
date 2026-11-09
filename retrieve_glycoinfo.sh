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
	# --retry: ride out transient UniProt hiccups, including 429 rate-limiting - no --retry-delay
	# given deliberately, so curl falls back to its own exponential backoff AND (curl 7.66+) honors
	# a `Retry-After` header UniProt sends with the 429, instead of us overriding it with a fixed,
	# too-short delay that just re-triggers the same rate limit. --retry-max-time caps the total
	# time spent retrying one request. --max-time: give up on a stalled connection instead of
	# trickling for minutes before failing anyway. -A: UniProt's API docs ask scripted/bulk
	# consumers to identify themselves with a contact so they can be told apart from anonymous
	# traffic, which otherwise tends to get throttled harder under load.
	# -D: capture response headers so the real UniProt release (x-uniprot-release, e.g. "2026_04")
	# can be stamped into the published file's data-version - the /stream endpoint always serves
	# "whatever's current", there's no way to request a specific past release the way InterPro's
	# or Ensembl's caches can, so this is the only way to know which release we actually got.
	headerfile=$(mktemp)
	curl --fail --silent --show-error --retry 5 --retry-max-time 600 --connect-timeout 10 --max-time 300 \
		-D "$headerfile" \
		-A "node-uniprotsync (https://github.com/hirenj/node-uniprotsync; hirenj@gmail.com)" "$url" \
		| tail -n+2 | sed -e 's/e;/e/g' -e 's/0000244/0000269/' -e 's/0007013/0000269/' -e 's/0008037/0000269/' -e 's/0008035/0000269/' -e 's/0007014/0000269/' -e 's/0000245/0000269/' -e 's/0007675/0000269/' -e 's/0007744/0000269/'
	(grep -i '^x-uniprot-release:' "$headerfile" | tr -d '\r' | awk '{print $2}' || echo unknown) > uniprot_release.txt
	rm -f "$headerfile"
done