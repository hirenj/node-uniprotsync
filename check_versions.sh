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

if [ $exit_code -eq 0 ]; then
	true
else
	echo "UniProt glycosylation files are up to date"
	false
fi