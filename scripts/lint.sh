#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
xcrun swift-format lint --configuration .swift-format --strict --recursive Package.swift Sources Tests scripts
if command -v swiftlint >/dev/null 2>&1; then
    swiftlint_binary="$(command -v swiftlint)"
elif [[ -x /opt/homebrew/bin/swiftlint ]]; then
    swiftlint_binary=/opt/homebrew/bin/swiftlint
else
    print -u2 'SwiftLint is required. Install it with: brew install swiftlint'
    exit 1
fi
"$swiftlint_binary" lint --strict --config .swiftlint.yml --no-cache
