#!/usr/bin/env bash
#   Name: dockersearchs - Dockerfile CLI search and clone tool
#   Version 1.0.0
#   Written by: anouarbensaad.

set -e

# Default options
VERSION="1.0.0"
INDEX=0
DOCKER_HUB="https://hub.docker.com"
OFF_ENDPOINT="/api/content/v1/products/images/"
UNOFF_ENDPOINT="/v2/repositories/"
USER_AGENT="Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:90.0) Gecko/20100101 Firefox/90.0"
IMAGE_SELECTED=""
VERSION_SELECTED=""
ARRAY=()
ARRAY2=()

# binding keys.
UP="$(echo -e '\e[A')"
DOWN="$(echo -e '\e[B')"
ENTER="$(echo -e '\n')"

# associative arrays.
declare -A OFFICIAL_IMAGES
declare -A ARR_VERSIONS

# usage info
usage() {
  cat <<EOF
  Usage: hgo [options]
  Options:
    search                  Search image
    --                      End of options
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
    response=$(curl \
        --silent -A $USER_AGENT \
        -XGET \
        -H "Content-Type: application/json" "${OFFICIAL_IMAGES[$selected]}/" | jq .full_description)
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
function preview_dockerfile() {
    selected_version="$1"
    curl --silent -XGET ${ARR_VERSIONS[$selected_version]} | less
}

# clone dockerfile.
function mirror_dockerfile() {
    selected_version="$1"
    curl --silent -XGET ${ARR_VERSIONS[$selected_version]} --output ./"$selected_version.dockerfile"
}

# check number of arguments.
if [[ $# -ne 2 ]];then
    usage
fi

if [[ "$1" == "search" ]]; then
    search_images "$2"
    parse_isOfficial
    print_official_images
fi