#!/bin/bash

taxids=$1

echo "Checking for existing UniProt Glycosylation data for $taxids"

exit_code=1

for taxid in ${taxids//,/ }; do
	echo "Checking existence of UniProt glycosylation data for $taxid"
	testversion_skip_exit "glycosylation-$taxid.json" --header 'X-UniProt-Release' --remote 'http://www.uniprot.org/uniprot/P12345'
	retcode=$?
	if [ $retcode -ne 0 ]; then
		echo "Existing UniProt json for $taxid"
	else
		echo "No existing UniProt json for $taxid"
		exit_code=0
	fi
done

echo "Checking existence of UniProt refseq mapping data"
testversion_skip_exit "refseqnt.json" --header 'X-UniProt-Release' --remote 'http://www.uniprot.org/uniprot/P12345'
retcode=$?
if [ $retcode -ne 0 ]; then
	echo "Existing RefSeqNT UniProt json"
else
	echo "No existing RefSeqNT UniProt json"
	exit_code=0
fi

if [ $exit_code -eq 0 ]; then
	true
else
	echo "UniProt synced files are up to date"
	touch VERSION_MATCHING
	exit 2
fi