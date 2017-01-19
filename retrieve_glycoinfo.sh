#!/bin/bash

taxids=$1

echo "uniprot	glyco"
for taxid in ${taxids//,/ }; do
	url="http://www.uniprot.org/uniprot/?sort=score&desc=&compress=no&query=organism:$taxid%20AND%20annotation:(type:CARBOHYD%20evidence:ECO_0000269)&fil=&force=no&format=tab&columns=id,feature(GLYCOSYLATION)"
	curl $url | tail -n+2
	if [ $? -gt 0 ]; then
		exit 1
	fi
done