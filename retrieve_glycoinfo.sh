#!/bin/bash

taxids=$1

echo "uniprot	glyco"
for taxid in ${taxids//,/ }; do
	url="https://rest.uniprot.org/uniprotkb/stream?fields=accession,ft_carbohyd&format=tsv&query=organism_id:$taxid%20AND%20(ftev_carbohyd:ECO_0000269)"
	curl $url | tail -n+2 | sed -e 's/e;/e/g'
	if [ $? -gt 0 ]; then
		exit 1
	fi
done