#!/bin/sh
# vim: ft=sh et sw=4
set -e
set -o pipefail

if [ -n "$DEBUG$PLUGIN_DEBUG" ]; then
    set -x
fi

. tags.sh

if [ "$1" = "--tags" ]; then
    >&2 printf "Running in --tags test mode"
    shift
    printf "%s\n" "$@" | parse_tags | xargs -n 1 | sort -u
    exit 0
fi

if echo "$DRONE_COMMIT_MESSAGE" | grep -qiF -e "[PUBLISH SKIP]" -e "[SKIP PUBLISH]"; then
    >&2 printf "Skipping publish"
    exit 0
fi

# $PLUGIN_FROM      re-tag from this repo
# $PLUGIN_REPO      tag to this repo/repo to push to
# $PLUGIN_REGISTRY  registry to push the image to
# $PLUGIN_TAGS      newline or comma separated list of tags to push images with
# $PLUGIN_DELETE    delete image after publishing

LOGIN="${DOCKER_LOGIN:-${PLUGIN_LOGIN}}"
if [ -n "$LOGIN" ]; then
    USERNAME="${LOGIN/:*/}"
    PASSWORD="${LOGIN/$USERNAME:/}"
else
    USERNAME="${DOCKER_USERNAME:-${PLUGIN_USERNAME}}"
    PASSWORD="${DOCKER_PASSWORD:-${PLUGIN_PASSWORD}}"
fi

if [ -z "${USERNAME}" ]; then
    error "Missing required docker 'username' for pushing"
elif [ -z "${PASSWORD}" ]; then
    error "Missing required docker 'username' for pushing"
fi

if [ -z "${PLUGIN_REPO}" ]; then
    # Only assume the destination repo if we explicitly specify a registry to push to
    if [ -n "$PLUGIN_REGISTRY" ] && [ -n "$DRONE_BUILD_NUMBER" ]; then
        if [ -n "$DOCKER_IMAGE_TOKEN" ]; then
            PLUGIN_REPO="drone/$DRONE_REPO/$DRONE_BUILD_NUMBER/$DOCKER_IMAGE_TOKEN:$DRONE_STAGE_OS-$DRONE_STAGE_ARCH"
        else
            PLUGIN_REPO="drone/$DRONE_REPO/$DRONE_BUILD_NUMBER:$DRONE_STAGE_OS-$DRONE_STAGE_ARCH"
        fi
    else
        error "Missing 'repo' argument required for publishing"
    fi
fi

# Lowercase PLUGIN_REPO for Dockers requirements
PLUGIN_REPO=$(echo $PLUGIN_REPO | awk '{print tolower($0)}')

if [ -n "$PLUGIN_FROM" ]; then
    SRC_REPO="${PLUGIN_FROM}"
# Try to use the "automagic" from repo
elif [ -z "$DOCKER_IMAGE_TOKEN" ] && \
        docker image inspect "drone/$DRONE_REPO/$DRONE_BUILD_NUMBER:$DRONE_STAGE_OS-$DRONE_STAGE_ARCH" >/dev/null 2>/dev/null; then
    SRC_REPO="drone/$DRONE_REPO/$DRONE_BUILD_NUMBER:$DRONE_STAGE_OS-$DRONE_STAGE_ARCH"
elif [ -n "$DOCKER_IMAGE_TOKEN" ] && \
        docker image inspect "drone/$DRONE_REPO/$DRONE_BUILD_NUMBER/$DOCKER_IMAGE_TOKEN:$DRONE_STAGE_OS-$DRONE_STAGE_ARCH" >/dev/null 2>/dev/null; then
    SRC_REPO="drone/$DRONE_REPO/$DRONE_BUILD_NUMBER/$DOCKER_IMAGE_TOKEN:$DRONE_STAGE_OS-$DRONE_STAGE_ARCH"
else
    # If no PLUGIN_FROM specifed, and no predictable image found, assume PLUGIN_REPO
    SRC_REPO="$PLUGIN_REPO"
fi

# Prepend the registry to the destination image, but not the from image
if [ -n "${PLUGIN_REGISTRY}" ]; then
    PLUGIN_REPO="$PLUGIN_REGISTRY/$PLUGIN_REPO"
fi

# Log in to the specified Docker registry (or the default if not specified)
printf %s "${PASSWORD}" | \
    docker login \
        --password-stdin \
        --username "${USERNAME}" \
        "${PLUGIN_REGISTRY}"

# Ensure at least one tag exists
if [ -z "${PLUGIN_TAGS}" ]; then
    # Take into account the case where the repo already has the tag appended
    if echo "${PLUGIN_REPO}" | grep -q ':'; then
        # Break after the last colon in case there are multiple, like a registry with a port
        TAGS="${PLUGIN_REPO##*:}"
        PLUGIN_REPO="${PLUGIN_REPO%:*}"
    else
    # If none specified, assume 'latest'
        TAGS="latest"
    fi
else
    # Parse and process dynamic tags
    TAGS="$(echo "${PLUGIN_TAGS}" | tr ',' '\n' | parse_tags | xargs -n 1 | sort -u | xargs)"
fi

# Tag all images
for tag in $TAGS; do
    docker tag "${SRC_REPO}" "${PLUGIN_REPO}:$tag"
done
# Push all tagged images
for tag in $TAGS; do
    printf "Pushing tag '%s'...\n" "$tag"
    docker push "${PLUGIN_REPO}:$tag"
    docker rmi "${PLUGIN_REPO}:$tag" >/dev/null 2>/dev/null || true
    printf "\n"
done

if [ -z "${PLUGIN_DELETE}" ]; then
    printf "Deleting source image ${SRC_REPO}"
    docker rmi "${SRC_REPO}" >/dev/null 2>/dev/null || true
fi
