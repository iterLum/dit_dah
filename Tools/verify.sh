#!/bin/bash
# Runs the model-layer checks in Tools/main.swift.
#
# Alphabet.swift and MorseCode.swift import nothing but Foundation, so they
# compile straight to a macOS binary — no simulator, no test target, ~1 second.
set -euo pipefail

cd "$(dirname "$0")/.."
OUT="$(mktemp -d)/verify"

swiftc -O \
  "DitDah Watch App/Model/Alphabet.swift" \
  "DitDah Watch App/Model/MorseCode.swift" \
  Tools/main.swift \
  -o "$OUT"

"$OUT"
