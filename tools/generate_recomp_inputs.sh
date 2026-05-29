#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ ! -x ./N64Recomp ]]; then
  echo "Missing ./N64Recomp. Copy/build the host N64Recomp binary into the repo root." >&2
  exit 1
fi
if [[ ! -x ./RSPRecomp ]]; then
  echo "Missing ./RSPRecomp. Copy/build the host RSPRecomp binary into the repo root." >&2
  exit 1
fi

if [[ ! -f chameleontwist2JP.z64 ]]; then
  echo "Missing chameleontwist2JP.z64 (Chameleon Twist 2 JP ROM, local-only; do not commit)." >&2
  exit 1
fi
if [[ ! -f chameleontwist2.elf ]]; then
  echo "Missing chameleontwist2.elf (local generated/input ELF required by jp.rev0.toml; do not commit)." >&2
  exit 1
fi

./RSPRecomp n_aspMain.toml
./N64Recomp jp.rev0.toml
