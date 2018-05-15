#!/bin/bash

other_taxids="HUMAN_9606"

echo "uniprot	refseq"
for taxid in ${other_taxids//,/ }; do
	url="ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/idmapping/by_organism/${taxid}_idmapping.dat.gz"
	curl $url | gunzip | grep 'RefSeq_NT' | awk -F$'\t' '{ print $1 FS $3 }'
	if [ $? -gt 0 ]; then
		exit 1
	fi
done