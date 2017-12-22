#!/bin/bash
set -eo pipefail

# Get the local directory, so we can safely look at files with relative paths.
DIR="$( cd -- "$( dirname -- "$0" )" && pwd )"
cd -- "$DIR"

. getversion.sh

# Create tag for docker build. Set the environment variable DOCKER_REPO if
# you plan on pushing to a remote repository. DOCKER_REPO will need a trailing
# slash.
DOCKER_TAG="${DOCKER_REPO}ncd-pipeline"

# Now, lets build
docker build --tag="$DOCKER_TAG" "$@" .

# And tag it with the version number
docker tag "$DOCKER_TAG" "$DOCKER_TAG:$TAG_VERSION"

# If running on Circle, add a branch label, too.
if [ -n "$CIRCLE_BRANCH" ]; then
  docker tag "$DOCKER_TAG" "$DOCKER_TAG:${CIRCLE_BRANCH}_latest"
fi