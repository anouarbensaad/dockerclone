#!/usr/bin/env bash
#   Name: dockerclone - Dockerfile CLI search and clone tool
#   Version 1.0.0
#   Written by: anouarbensaad.

set -e

## Settings File
rc_file=""
# Default options
VERSION="1.0.0"
INDEX=0
IMAGE_SELECTED=""
VERSION_SELECTED=""
SEARCH=""
ARRAY=()
ARRAY2=()

# associative arrays.
declare -A OFFICIAL_IMAGES
declare -A ARR_VERSIONS

## Locate setting file
if [[ -f "${HOME}/.dockerclone_rc" ]];then
    rc_file="${HOME}/.searchsploit_rc"
elif [[ -f "${PWD}/.dockerclone_rc" ]];then
    rc_file="${PWD}/.dockerclone_rc"
elif [[ ! -f "${rc_file}" ]]; then
  printf "\n   $(tput bold)$(tput setaf 1)%s$(tput sgr0)\n\n" "Could not find: rc_file ~ ${rc_file}"
  exit 1
fi

## Use config file
source "${rc_file}"

# usage info
usage() {
  cat <<EOF
  Usage: dockerclone [options]
  Options:
    -s, --search            Search the image name (Default NGINX)
    -n, --name              Specify image from searches.
    -x, --examine           Examine (Preview Dockerfile) found.
    -c  --clone             Clone (copies) the dockerfile to the current working directory"
    -h, --help              This message.
    -v, --version           Show version.
    --                      End of options.
EOF
}

# search images by name
function search_images() {
    imagename=$1
    searchs=$(docker search "$imagename" \
        --format "table {{.Name}} {{.IsOfficial}}" |\
        egrep -vi "name")
    IFS=$'\n'
    for i in ${searchs}
    do
        ARRAY+=( "$i" )
    done
    unset $IFS
}

# set the official image to array 
function parse_isOfficial() {
    for image in ${ARRAY[@]}
    do
        image_name="$(echo $image|awk -F " " '{print $1}')"
        if [[ $(echo $image|awk -F " " '{print $2}') =~ "[OK]" ]];then
            ARRAY2+=( "$image_name" )
            OFFICIAL_IMAGES[${image_name}]="$DOCKER_HUB""$OFF_ENDPOINT"${image_name}
        fi
    done
}

# print all official images.
function print_official_images() {
    if [[ ${#OFFICIAL_IMAGES[@]} -eq 0 ]];then
        printf "\n   $(tput bold)$(tput setaf 1)%s$(tput sgr0)\n\n" "No images found" 2>/dev/null
        exit 1
    else
        printf "\n   $(tput bold)$(tput setaf 2)%s$(tput sgr0)\n\n" "Official Images Docker-Hub"
        for item in ${!OFFICIAL_IMAGES[@]}
        do
            printf " * %s\n" "$item" 2>/dev/null
        done
        printf "\n"
    fi
}

# get dockerfile by
function parse_tag_and_dockerfile() {
    selected="$1"
    # if [[ ${#OFFICIAL_IMAGES} -eq 0 ]];then
    #     printf "\n   $(tput bold)$(tput setaf 1)%s$(tput sgr0)\n\n" "Search for image first."
    #     exit 1
    # fi
    response=$(curl \
        --silent -A $USER_AGENT \
        -XGET \
        -H "Content-Type: application/json" "${OFFICIAL_IMAGES[$selected]}/" | jq .full_description 2>/dev/null)
    extract=$(echo -e $response | sed -e '/\[\(.*\)\].*Dockerfile.$/!d')
    for x in $extract
    do
        _version=$(echo $x|sed -e 's/\[\(.*\)\].*/\1/g'|cut -d "," -f1|sed -e 's/-\t`\(.*\)`/\1/g')
        _url=$(echo "$x" |sed -e 's/-\t\[.*\](\(.*\))/\1/g;s/github.com/raw.githubusercontent.com/g;s/\/blob\//\//g')
        ARR_VERSIONS["$_version"]="$_url"
        printf "* %s\t\t%s\n" "$_version" "$_url"
    done
}

# preview dockerfile.
function examine_dockerfile() {
    selected_version="$1"
    echo $selected_version
    curl --silent -XGET ${ARR_VERSIONS[$selected_version]} | less
}

# clone dockerfile.
function mirror_dockerfile() {
    selected_image="$1"
    selected_version="$2"
    curl --silent -XGET ${ARR_VERSIONS[$selected_version]} --output ./"$selected_image.$selected_version.dockerfile"
}

# Parse options
while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do
    case $1 in
	-v | --version )
	    echo "$VERSION"
	    exit
	    ;;
	-s | --search )
        SEARCH="$2"
        search_images "$2"
        parse_isOfficial
        print_official_images
	    shift;
	    ;;
	-n | --name )
        IMAGE_SELECTED="$2"
        parse_tag_and_dockerfile "$IMAGE_SELECTED"
        shift;
	    ;;
	-x | --examine )
        VERSION_SELECTED="$2"
        echo $VERSION_SELECTED
        examine_dockerfile "$VERSION_SELECTED"
        shift;
	    ;;
    -c | --clone )
        VERSION_SELECTED="$2"
        mirror_dockerfile "$IMAGE_SELECTED" "$VERSION_SELECTED"
        ;;
	-h | --help )
	    usage
	    exit
	    ;;
	* )
	    echo "abort: unknown argument" 1>&2
	    exit 1
    esac
    shift
done
if [[ "$1" == "--" ]]; then shift; fi
if [[ -z $SEARCH ]];then
    printf "\n   $(tput bold)$(tput setaf 1)%s$(tput sgr0)\n\n" "You must search before set name of image." 2>/dev/null
    exit 1
fi