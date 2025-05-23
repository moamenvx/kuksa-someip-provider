#!/bin/bash
#********************************************************************************
# Copyright (c) 2022 Contributors to the Eclipse Foundation
#
# See the NOTICE file(s) distributed with this work for additional
# information regarding copyright ownership.
#
# This program and the accompanying materials are made available under the
# terms of the Apache License 2.0 which is available at
# http://www.apache.org/licenses/LICENSE-2.0
#
# SPDX-License-Identifier: Apache-2.0
#*******************************************************************************/
# shellcheck disable=SC2181
# shellcheck disable=SC2086
# shellcheck disable=SC2230

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTEXT_DIR="$SCRIPT_DIR"
# name of docker image: ${DOCKER_ARCH)/${DOCKER_IMAGE}
DOCKER_IMAGE="someip-feeder"


print_usage() {
	echo "USAGE: $0 [OPTIONS] TARGETS"
	echo
	echo "Standalone build helper for someip-feeder container."
	echo
	echo "OPTIONS:"
	echo "  -l, --local      local docker import (does not export tar)"
	echo "  -v, --verbose    enable plain docker output and disable cache"
	echo "      --help       show help"
	echo
	echo "TARGETS:"
	echo "  x86_64|amd64, aarch64|amd64    Target arch to build for, if not set - defaults to multiarch"
	echo
}

LOCAL=0
VERBOSE=0
while [ $# -gt 0 ]; do
	if [ "$1" = "--local" ] || [ "$1" = "-l" ]; then
		LOCAL=1
	elif [ "$1" = "--verbose" ] || [ "$1" = "-v" ]; then
		VERBOSE=1
	elif [ "$1" = "--help" ]; then
		print_usage
		exit 0
	else
		TARGET="$1"
	fi
	shift
done

target_arch() {
	local target="$1"
	case "$target" in
	"x86_64" | "amd64" | "linux/amd64")
		echo "amd64"
		;;
	"arm64" | "aarch64" | "linux/arm64")
		echo "arm64"
		;;
	"armv6" | "arm" | "linux/arm")
		echo "arm/v6"
		;;
	"multiarch" | "")
		echo "multiarch"
		;;
	*)
		return 1
		;;
	esac
	return 0
}

build_release() {
	local arch="$1"

	cd "$CONTEXT_DIR" || return 1
	echo "-- Building release for: $arch ..."
	./build-release.sh "$arch"

	echo "-- Building someip-feeder_${arch}_release.tar.gz ..."

	tar -czvf "someip-feeder_${arch}_release.tar.gz" \
		"target/${arch}/release/install/" \
		"target/${arch}/release/licenses/" \
		"proto/"

	echo "-- Checking [$arch] binaries: $(pwd)/target/${arch}/release/install/bin ..."
	file "target/${arch}/release/install/bin/someip_feeder" \
		"target/${arch}/release/install/bin/wiper_service" \
		"target/${arch}/release/install/lib/libvsomeip3.so.3.1.20"
}

if [ -z "$TARGET" ] && [ $LOCAL -eq 1 ]; then
	echo "Multiarch archives are not supported for local builds, removing --local flag ..."
	LOCAL=0
fi

set -e

DOCKER_ARCH=$(target_arch "$TARGET")
DOCKER_EXPORT="./${DOCKER_ARCH//\//_}-${DOCKER_IMAGE}.tar"

# NOTE: current Dockerfile is building from sources, could be optimized
if false; then
	echo "-- Building ${DOCKER_IMAGE} container ..."
	if [ "$DOCKER_ARCH" = "multiarch" ] || [ "$DOCKER_ARCH" = "amd64" ]; then
		build_release x86_64 || exit 1
	fi
	if [ "$DOCKER_ARCH" = "multiarch" ] || [ "$DOCKER_ARCH" = "arm64" ]; then
		build_release aarch64 || exit 1
	fi
fi

if [ "$DOCKER_ARCH" = "multiarch" ]; then
	DOCKER_ARGS="--platform linux/amd64,linux/arm64 -t $DOCKER_ARCH/$DOCKER_IMAGE --output type=oci,dest=$DOCKER_EXPORT"
else
	if [ $LOCAL -eq 1 ]; then
        DOCKER_ARGS="--load --platform linux/$DOCKER_ARCH -t $DOCKER_ARCH/$DOCKER_IMAGE" 
		DOCKER_EXPORT="($DOCKER_ARCH/$DOCKER_IMAGE ghcr.io/boschglobal/kuksa.val.feeders/$DOCKER_IMAGE:prerelease)"
	else
		DOCKER_ARGS="--platform linux/$DOCKER_ARCH -t $DOCKER_ARCH/$DOCKER_IMAGE --output type=oci,dest=$DOCKER_EXPORT"
	fi
fi

if [ "$VERBOSE" = "1" ]; then
	DOCKER_ARGS="--no-cache --progress=plain $DOCKER_ARGS"
fi

cd "$CONTEXT_DIR" || exit 1
echo "# docker buildx build $DOCKER_ARGS -f ./Dockerfile $CONTEXT_DIR"
DOCKER_BUILDKIT=1 docker buildx build $DOCKER_ARGS -f ./Dockerfile "$CONTEXT_DIR" $DOCKER_EXT

if [ $? -eq 0 ]; then
	if [ $LOCAL -eq 1 ]; then
		echo "docker image tag $DOCKER_ARCH/$DOCKER_IMAGE ghcr.io/eclipse/kuksa.val.services/$DOCKER_IMAGE:prerelease"
		docker image tag $DOCKER_ARCH/$DOCKER_IMAGE ghcr.io/eclipse/kuksa.val.services/$DOCKER_IMAGE:prerelease
		docker image ls | grep "/$DOCKER_IMAGE"
	else
		echo "# Exported $DOCKER_ARCH/$DOCKER_IMAGE in $DOCKER_EXPORT"
		skopeo inspect --raw oci-archive:$DOCKER_EXPORT | jq .
	fi
fi
