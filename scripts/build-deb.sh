#!/usr/bin/env bash
# Build cy/* Salt deb packages locally inside Docker for Debian 11 (bullseye)
# or Debian 12 (bookworm), amd64 only. Output: dist/<codename>/*.deb
#
# Patches in patches/series are applied via quilt before the build and popped
# afterward, regardless of build outcome (so the working tree is restored even
# if the build crashes).
#
# Usage:
#   scripts/build-deb.sh bullseye
#   scripts/build-deb.sh bookworm
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

codename="${1:-}"
case "$codename" in
    bullseye|bookworm) ;;
    ""|-h|--help)
        echo "Usage: $0 {bullseye|bookworm}" >&2
        exit 2
        ;;
    *)
        echo "Unknown codename: $codename (expected bullseye or bookworm)" >&2
        exit 2
        ;;
esac

for tool in docker quilt; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "$tool not found in PATH" >&2
        exit 127
    fi
done

# Refuse to start with a dirty tree — `tools pkg build deb` writes into salt/
# and pkg/ via debhelper, so we want a known-good baseline before applying
# patches and a known-good cleanup target afterward.
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Working tree has uncommitted changes; refuse to build." >&2
    echo "Commit, stash, or revert them first." >&2
    exit 1
fi

cleanup() {
    local rc=$?
    echo
    echo ">> Cleanup: pop patches, remove debian symlink ..."
    rm -f debian
    ./scripts/apply-patches.sh --pop >/dev/null 2>&1 || true
    if [[ $rc -ne 0 ]]; then
        echo ">> build-deb.sh exited with code $rc" >&2
    fi
    exit $rc
}
trap cleanup EXIT

echo ">> Applying patches ..."
./scripts/apply-patches.sh

image_tag="salt-cy-build-deb:${codename}"
echo
echo ">> Building image ${image_tag} (cached after first run) ..."
docker build \
    --tag "$image_tag" \
    --build-arg "DEBIAN_CODENAME=${codename}" \
    -f scripts/build-deb.dockerfile \
    scripts/

output_dir="dist/${codename}"
mkdir -p "$output_dir"

echo
echo ">> Running build for ${codename} amd64 ..."
docker run --rm \
    --platform linux/amd64 \
    -v "$PWD:/salt" \
    -v "$PWD/${output_dir}:/output" \
    "$image_tag"

echo
echo ">> Built artifacts in ${output_dir}/:"
ls -lh "${output_dir}"/*.deb 2>/dev/null || {
    echo "  (no .deb files produced — see container log above)" >&2
    exit 1
}
