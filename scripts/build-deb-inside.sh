#!/usr/bin/env bash
# Container entrypoint for build-deb.dockerfile.
# Runs upstream `tools pkg build deb` against /salt and moves the artifacts
# (which debuild emits into the parent dir, i.e. /) into /output on the host.
set -euo pipefail

cd /salt

echo ">> Building deb packages for amd64 ..."
python3 -m tools pkg build deb \
    --arch amd64 \
    --relenv-version=0.22.4 \
    --python-version=3.10.19

echo
echo ">> Collecting artifacts from / into /output ..."
shopt -s nullglob
moved=0
for f in /*.deb /*.dsc /*.changes /*.tar.* /*.buildinfo; do
    mv -v "$f" /output/
    moved=$((moved + 1))
done

if [[ "$moved" -eq 0 ]]; then
    echo "WARNING: no build artifacts found in /" >&2
    exit 1
fi

echo
echo ">> Done. Files in /output:"
ls -lh /output/
