set -e

# ANSI colour escape sequences
RED='\033[0;31m'
RESET='\033[0m'

error() { >&2 echo -e "${RED}Error: $@${RESET}"; exit 1; }
cmd_fmt() { echo "%$@\\s*:\\s*"; }
nth_line() { cut -f$1 -d$'\n' | tr -d ' '; }
rem_from() { echo "$2" | sed "s|$1||"; }

# Constant format strings for sed/grep
file_fmt="$(cmd_fmt 'file')"            # %file: ..
label_fmt="$(cmd_fmt 'label')"          # %label: ..
auto_fmt="$(cmd_fmt 'auto')"            # %auto: ..
fileauto_fmt="$(cmd_fmt 'fileauto')"    # %fileauto: ..
labelauto_fmt="$(cmd_fmt 'labelauto')"  # %label: ..
prefix_fmt="$(cmd_fmt 'prefix')"        # %prefix: ..

check_file() {
    [ -e "$1" ] || error "tag file '$1' doesn't exist"
    [ -r "$1" ] || error "tag file '$1' cannot be read"
}

auto_tags() {

    local version="$1"
    local prefix="$2"

    # If provided, the prefix is prepended, with a dash separator
    [ -n "$prefix" ] && echo "$prefix-$version" || echo "$version"

    # Ensure pre 1.0 versions don't get truncated to '0'
    [ "$version" = "0" ] && return

    # Only trim if there is a minor version to trim off
    echo "$version" | grep -qv '\.' && return

    # Trim after (and including) the last dot
    local ext="${version##*.}"
    local version="$(basename "$version" ".$ext")"

    # Recurse and try to trim the version further
    auto_tags "$version" "$prefix"
}

# Takes a string like '%prefix: prepend-this % filename' and
# outputs first 'filename' then 'prepend-this'. If no prefix is
# present, only 'filename' is emitted
parse_prefix() {
    # Check if the auto-format has a prefix tag, and split it
    if echo "$1" | grep -q "$prefix_fmt"; then
        echo "$1" | sed "s|$prefix_fmt.*%\\s*||"
        echo "$1" | sed -n "s|$prefix_fmt\\(.*\\)\\s*%.*|\\1|p"
    else
        echo "$1"
    fi
}

parse_tags() {
    # Read each tag, one per line, from stdin
    while read -r tag; do

        # Load in dynamic tag file
        if echo $tag | grep -q "$file_fmt"; then
            local parts="$(parse_prefix "$(rem_from "$file_fmt" "$tag")")"
            local filename="$(echo "$parts" | nth_line 1)"
            check_file "$filename"

            # Print prefix if one is present
            local prefix="$(echo "$parts" | nth_line 2)"
            [ -n "$prefix" ] && echo -n "$prefix-"

            cat "$filename"

        # Load in dynamic tag file _and_ auto-process version tags
        elif echo $tag | grep -q "$fileauto_fmt"; then
            local parts="$(parse_prefix "$(rem_from "$fileauto_fmt" "$tag")")"
            local filename="$(echo "$parts" | nth_line 1)"

            # Ensure file exists
            check_file "$filename"

            local version="$(cat $filename)"
            local prefix="$(echo "$parts" | nth_line 2)"
            auto_tags "$version" "$prefix"

        # Load in image labels
        elif echo $tag | grep -q "$label_fmt"; then
            local parts="$(parse_prefix "$(rem_from "$label_fmt" "$tag")")"
            local label="$(echo "$parts" | nth_line 1)"
            local prefix="$(echo "$parts" | nth_line 2)"

            # Print prefix if one is present
            [ -n "$prefix" ] && echo -n "$prefix-"

            docker inspect -f "{{ index .Config.Labels \"$label\" }}" "$SRC_REPO"

        # Load in image labels and generate auto-numbered versions
        elif echo $tag | grep -q "$labelauto_fmt"; then
            local parts="$(parse_prefix "$(rem_from "$labelauto_fmt" "$tag")")"
            local label="$(echo "$parts" | nth_line 1)"
            local prefix="$(echo "$parts" | nth_line 2)"

            local version="$(docker inspect -f "{{ index .Config.Labels \"$label\" }}" "$SRC_REPO")"
            auto_tags "$version" "$prefix"

        # Generate automatic-numbered version tags
        elif echo $tag | grep -q "$auto_fmt"; then
            local parts="$(parse_prefix "$(rem_from "$auto_fmt" "$tag")")"
            local version="$(echo "$parts" | nth_line 1)"
            local prefix="$(echo "$parts" | nth_line 2)"
            auto_tags "$version" "$prefix"

        # else just use the tag raw
        else
            echo $tag
        fi

    # Remove any duplicate tags and sort them
    done
}

