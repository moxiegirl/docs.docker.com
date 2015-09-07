#!/bin/bash -ex

DOCS_DIR=$( dirname $( find /docs -name 'build.json' | head -n1 ) )
BUILD_JSON="${DOCS_DIR}/build.json"
BUILDINFO_PARTIAL="${DOCS_DIR}/layouts/partials/container-footer.html"

# Populate an array with just docker dirs and one with content dirs
# docker_dir=(`ls -d /docs/content/docker/*`)
content_dir=(`ls -d /docs/content/*`)

# Loop content not of docker/
#
# Sed to process GitHub Markdown
# 1-2 Remove comment code from metadata block
# 3 Remove .md extension from link text
# 4 Change ](/ to ](/project/ in links
# 5 Change ](word) to ](/project/word)
# 6 Change ](../../ to ](/project/
# 7 Change ](../ to ](/project/word)
# 
for i in "${content_dir[@]}"
do
   :
   case $i in
      "/docs/content/docker-trusted-registry")
      ;;
      "/docs/content/docker-hub")
      ;;
      "/docs/content/windows")
      ;;
      "/docs/content/mac")
      ;;
      "/docs/content/linux")
      ;;
      "/docs/content/registry")
      ;;
      "/docs/content/compose")
      ;;
      "/docs/content/swarm")
      ;;
      "/docs/content/machine")
      ;;
      "/docs/content/kitematic")
      ;;
      "/docs/content/opensource")
      ;;
      *)
      ;;
      esac
done


# Substitute in the build data in the buildinfo partial
sed "/BUILD_DATA/r $BUILD_JSON" "$BUILDINFO_PARTIAL" | sed '/BUILD_DATA/d' > "${BUILDINFO_PARTIAL}.out" \
    && mv "${BUILDINFO_PARTIAL}.out" "${BUILDINFO_PARTIAL}"
