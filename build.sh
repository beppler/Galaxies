#!/usr/bin/env bash
# Build (and optionally test/run) on Linux and macOS.  Usage: ./build.sh [test|run]
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p bin
case "${1:-build}" in
  test) odin test src -out:bin/galaxies_test -define:ODIN_TEST_THREADS=1 ;;
  run)  odin build src -out:bin/galaxies -o:speed && ./bin/galaxies ;;
  *)    odin build src -out:bin/galaxies -o:speed ;;
esac
