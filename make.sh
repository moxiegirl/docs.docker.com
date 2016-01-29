#!/usr/bin/env bash

set -e
set -o pipefail

test_github_env() {
	test_env "GITHUB_USERNAME"
	test_env "GITHUB_TOKEN"
}

test_aws_env() {
	test_env "AWS_USER"
	test_env "AWS_ACCESS_KEY_ID"
	test_env "AWS_SECRET_ACCESS_KEY"
	test_env "AWS_S3_BUCKET"
	test_env "S3HOSTNAME"
}

test_env() {
	eval test=\$$1
	if [ -z "$test" ]; then
		echo "ERROR: $1 not defined"
		exit -1
	fi
}

fetch() {
	echo "fetching"
	cd /src
	./fetch_content.py /docs all-projects.yml

	# touch-up.sh
	# add the git sha info for all repos in json
	DOCS_DIR=$( dirname $( find /docs -name 'build.json' | head -n1 ) )
	BUILD_JSON="${DOCS_DIR}/build.json"
	BUILDINFO_PARTIAL="${DOCS_DIR}/layouts/partials/container-footer.html"

	# Substitute in the build data in the buildinfo partial
	sed "/BUILD_DATA/r $BUILD_JSON" "$BUILDINFO_PARTIAL" | sed '/BUILD_DATA/d' > "${BUILDINFO_PARTIAL}.out" \
	    && mv "${BUILDINFO_PARTIAL}.out" "${BUILDINFO_PARTIAL}"
}

build() {
	DEST_PATH="$DOCS_VERSION"
	if [ -n "$RELEASE_LATEST" ]; then
		DEST_PATH=""
	fi

	echo "RUNNING: hugo -d /public/$DEST_PATH --baseUrl=http://$S3HOSTNAME/$DEST_PATH --config=config.toml"
	hugo -d /public/$DEST_PATH --baseUrl=http://$S3HOSTNAME/$DEST_PATH --config=config.toml
}

upload() {
	if ! aws s3 ls s3://$AWS_S3_BUCKET ; then
		aws s3 mb s3://$AWS_S3_BUCKET
	fi
	/src/update-redirects.sh

	DEST_PATH="$DOCS_VERSION"
	if [ -n "$RELEASE_LATEST" ]; then
		DEST_PATH=""
	else
		# don't want to clean the historical versions
		if [ -n "$CLEAN" ] ; then
			aws s3 rm --recursive s3://$AWS_S3_BUCKET/$DEST_PATH
		fi
	fi

	# Hugo currently created zero length files, which cause issues when pushed to s3
	# delete them.
	EMPTYFILES=$(find . -size 0 -type f)
	if [ -n "EMPTYFILES" ]; then
		echo "DELETING Size zero files:"
		find . -size 0 -type f -printf "DELETING empty file %p\n" -delete
	fi

	aws s3 sync --acl=public-read /public/ s3://$AWS_S3_BUCKET/$DEST_PATH
}

cleanup() {
	if [[ "$AWS_S3_BUCKET" =~ "/" ]] ; then
		BUCKET_PATH=$( echo "$AWS_S3_BUCKET" | sed "s/[^\/]*\///" )
		BUCKET_PATH+="/"
		AWS_S3_BUCKET=$( echo "$AWS_S3_BUCKET" | sed "s/\/.*//")
	else
		BUCKET_PATH=
	fi

	[ -z "$RM_OLDER_THAN" ] && exit 1
	CUTOFF_UNIX_TS=$( date --date "$RM_OLDER_THAN" '+%s' )
	aws s3 ls --recursive s3://$AWS_S3_BUCKET/$BUCKET_PATH | while read -a LINE ; do
		DATE="${LINE[0]}"
		TIME="${LINE[1]}"
		SIZE="${LINE[2]}"
		NAME="${LINE[*]:3}"

		VERSION_REGEX="^${BUCKET_PATH}v[0-9]+\.[0-9]+/"
		UNIX_TS=$( date --date "$DATE $TIME" "+%s" )

		if [[ "$NAME" =~ $VERSION_REGEX ]] || [[ "$CUTOFF_UNIX_TS" -le "$UNIX_TS" ]] ; then
			echo "Keeping $NAME"
			continue
		fi

		echo "Creating redirect for $NAME"
		aws s3 cp "s3://$AWS_S3_BUCKET/$NAME" "s3://$AWS_S3_BUCKET/$NAME" --website-redirect="/${BUCKET_PATH}index.html" --acl=public-read > /dev/null
	done
}

case "$1" in
bash)
	test_github_env
	test_aws_env

	exec bash
	;;
fetch)
	test_github_env

	fetch
	;;
markdownlint)
	test_github_env

	fetch
	/usr/local/bin/markdownlint /docs/content/
	;;
html)
	test_github_env

	fetch
	cd /docs
	build
	;;
serve)
	test_github_env

	fetch
	cd /docs
	hugo server -d /public --port=8000 --watch --baseUrl=$(HUGO_BASE_URL) --bind=0.0.0.0 --config=config.toml
	;;
test)
	test_github_env

	fetch
	cd /docs
	hugo server -d /public --port=8000 --watch --baseUrl=$(HUGO_BASE_URL) --bind=0.0.0.0 --config=config.toml &

	echo "About to run markdownlint and linkcheck"
	sleep 4
	/usr/local/bin/markdownlint /docs/content/
	/usr/local/bin/linkcheck http://localhost:8000

	;;
htmllint)
	test_env "CHECKURL"

	/usr/local/bin/linkcheck $CHECKURL
	;;
build_and_upload)
	test_github_env
	test_aws_env
	# TODO: maybe move the CLEAN var code into here too
	# test_env CLEAN

	fetch
	cd /docs
	build
	upload
	;;
cleanup)
	test_aws_env
	test_env RM_OLDER_THAN

	echo "cleanup"
	cleanup
	;;
*)
	echo "ERROR: Command $1 not found"
	echo "	Supported commands: bash, fetch, markdownlint, html, serve, test, htmllint, upload, build_and_upload, cleanup"
	echo
esac
