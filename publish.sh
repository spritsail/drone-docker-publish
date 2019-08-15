#!/bin/sh
set -e
set -o pipefail

source tags.sh

if [ "$1" = "--tags" ]; then
    >&2 echo -e "Running in --tags test mode"
    shift
    printf "%s\n" "$@" | parse_tags | xargs -n 1 | sort -u
    exit 0
fi

if echo "$DRONE_COMMIT_MESSAGE" | grep -qiF -e "[PUBLISH SKIP]" -e "[SKIP PUBLISH]"; then
    >&2 echo -e "Skipping publish"
    exit 0
fi

# $PLUGIN_FROM  re-tag from this repo
# $PLUGIN_REPO  tag to this repo/repo to push to
# $PLUGIN_TAGS  newline or comma separated list of tags to push images with

USERNAME="${DOCKER_USERNAME:-${PLUGIN_USERNAME}}"
PASSWORD="${DOCKER_PASSWORD:-${PLUGIN_PASSWORD}}"

if [ -z "${USERNAME}" ]; then
    error "Missing required docker 'username' for pushing"
elif [ -z "${PASSWORD}" ]; then
    error "Missing required docker 'username' for pushing"
fi

if [ -z "${PLUGIN_REPO}" ]; then
    error "Missing 'repo' argument required for publishing"
fi

# If no PLUGIN_FROM specifed, assume PLUGIN_REPO instead
export SRC_REPO="${PLUGIN_FROM:-${PLUGIN_REPO}}"

# Log in to the specified Docker registry (or the default if not specified)
login_error="$(
    echo -n "${PASSWORD}" \
    | docker login \
        --password-stdin \
        --username "${USERNAME}" \
        "${PLUGIN_REGISTRY}" \
    2>&1
)"
if [ $? -ne 0 ]; then
    >&2 echo "$login_error"
fi

# Ensure at least one tag exists
if [ -z "${PLUGIN_TAGS}" ]; then
    # Take into account the case where the repo already has the tag appended
    if echo "${PLUGIN_REPO}" | grep -q ':'; then
        TAGS="${PLUGIN_REPO#*:}"
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
    printf "Pushing tag '%s'...\n" $tag
    docker push "${PLUGIN_REPO}:$tag"
    printf "\n"
done
# Remove all tagged images
for tag in $TAGS; do
    docker rmi "${PLUGIN_REPO}:$tag" >/dev/null 2>/dev/null || true
done
docker rmi "${SRC_REPO}" >/dev/null 2>/dev/null || true

if [ -n "$MICROBADGER_TOKEN" ]; then
    >&2 echo "Legacy \$MICROBADGER_TOKEN provided, you can remove this"
fi

printf "%s... " "Updating Microbadger metadata for ${PLUGIN_REPO%:*}"
WEBHOOK_URL="$(curl -sS https://api.microbadger.com/v1/images/${PLUGIN_REPO%:*} | jq -r .WebhookURL)" && \
curl -sS -X POST "$WEBHOOK_URL" || true
