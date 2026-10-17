#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
xcrun swift-format format --configuration .swift-format --in-place --recursive Package.swift Sources Tests scripts
