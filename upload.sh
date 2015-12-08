#!/bin/bash
set -e

if ! aws s3 ls s3://$AWS_S3_BUCKET ; then
	aws s3 mb s3://$AWS_S3_BUCKET
fi
/src/update-redirects.sh

if [ -n "$CLEAN" ] ; then
  aws s3 rm --recursive s3://$AWS_S3_BUCKET/$CLEAN
fi

# Hugo currently created zero length files, which cause issues when pushed to s3
# delete them.
EMPTYFILES=$(find . -size 0 -type f)
if [ -n "EMPTYFILES" ]; then
	echo "DELETING Size zero files:"
	find . -size 0 -type f -printf "DELETING empty file %p\n" -delete
fi


aws s3 sync --acl=public-read . s3://$AWS_S3_BUCKET
