#
# Dot-Include this one, like this:
#
# . getversion.sh
#
# And we will put BUILD_VERSION and TAG_VERSION into your environment.
# (We need to have version.txt in the cwd.)
#

# (Executed in a subshell to avoid making too many extra variables.)
#
BUILD_VERSION=$(
  # Read version from version.txt file
  VERSION=`cat version.txt`

  # Determine BUILD_ID. If running in CircleCI, use the branch name as the
  # prerelease ID. Unless, the branch is "master" in which case no prerelease
  # ID is used. If not running in CircleCI, use the user name for the prerelease
  # ID. (There's no build number in that case.)
  if [ -n "$CIRCLECI" ]; then
    if [ "$CIRCLE_BRANCH" != "master" ]; then
            PRERELEASE_ID="-$CIRCLE_BRANCH"
    fi
    BUILD_ID="$PRERELEASE_ID+$CIRCLE_BUILD_NUM"
  else
    BUILD_ID="-$USER"
  fi

  # Build version is a combination of the version and the build id.
  echo "$VERSION$BUILD_ID"
)
TAG_VERSION=${BUILD_VERSION%%+*}
