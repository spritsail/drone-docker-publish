#!/bin/sh
set -e

# ANSI colour escape sequences
RED='\033[0;31m'
RESET='\033[0m'

error() { >&2 echo -e "${RED}Error: $@${RESET}"; exit 1; }

parse_tags() {
    alltags=

    # Read each tag, one per line, from stdin
    while read -r tag; do

        # Start with an empty list of tags
        tags=

        # Split the entire string by | to find each command+args
        IFS=$'|'
        for pipe in $tag; do

            # Split each pipe command into words (cmd + args)
            IFS=' '
            set -- $(echo "$pipe")
            cmd="$1"; shift

            # If the cmd doesn't begin with %, it must be a literal tag
            if [ "${cmd:0:1}" != '%' ]; then
                tags="$(echo "$tags"$'\n'"$cmd" | sed '/^$/d')"
                continue
            else

                # Match on the command (removing the %)
                case "${cmd:1}" in
                    # Add a prefix
                    # usage: prefix <prefix> [separator=-]
                    prefix)
                        [ $# -lt 1 ] && error "$cmd expects at least 1 argument"
                        tags="$(echo "$tags" | sed "s/^/${1}${2:--}/g")"
                        ;;

                    # Add a suffix
                    # usage: suffix <suffix> [separator=-]
                    suffix)
                        [ $# -lt 1 ] && error "$cmd expects at least 1 argument"
                        tags="$(echo "$tags" | sed "s/$/${2:--}${1}/g")"
                        ;;

                    # Remove a prefix
                    # usage: rempre <prefix> [separator=-]
                    rempre)
                        [ $# -lt 1 ] && error "$cmd expects at least 1 argument"
                        tags="$(echo "$tags" | sed "s/${1}${2--}//g")"
                        ;;

                    # Remove a suffix
                    # usage: suffix <suffix> [separator=-]
                    remsuf)
                        [ $# -lt 1 ] && error "$cmd expects at least 1 argument"
                        tags="$(echo "$tags" | sed "s/${2:--}${1}//g")"
                        ;;

                    # Generate an automatic list of semver tags
                    auto)
                        [ $# -gt 0 ] && error "$cmd expects 0 arguments"

                        ver=$1
                        newtags=

                        for tag in $tags; do
                            # Only trim if there is a minor version to trim off
                            while echo "$tag" | grep -q -e '\.' -e '-'; do
                                # Save the current tag before trimming
                                newtags="$(echo "$newtags"$'\n'"$tag" | sed '/^$/d')"

                                # Trim after (and including) the last dot/dash
                                # Recurse and try to trim the version further
                                tag="$(echo $tag | sed -E 's/(.*)[\.-].*/\1/')"
                            done

                            # Keep the last tag after trimming
                            newtags="$(echo "$newtags"$'\n'"$tag" | sed '/^$/d')"
                        done
                        tags="$newtags"
                        ;;

                    # Fetch docker image label
                    # usage: label <label-name> [image name=$SRC_REPO]
                    label)
                        [ $# -lt 1 ] && error "$cmd expects at least 1 argument"
                        tags="$(docker inspect -f "{{ index .Config.Labels \"$1\" }}" "${2:-$SRC_REPO}")"
                        ;;

                    # Load a tag from a file
                    # usage: file <file-name>
                    file)
                        [ $# -ne 1 ] && error "$cmd expects 1 argument"
                        [ -e "$1" ] || error "tag file '$1' doesn't exist"
                        [ -r "$1" ] || error "tag file '$1' cannot be read"
                        tags="$(cat "$1")"
                        ;;
                    *)
                        error "unknown command '$cmd'"
                        ;;
                esac
            fi
        done

        alltags="$alltags"$'\n'"$tags"
    done

    # Print all of the tags, sans empty lines
    echo "$alltags" | sed '/^$/d'
}

