#!/bin/sh
set -eu

xcodebuild -scheme Rill -destination 'platform=macOS' build
xcodebuild -scheme Rill -destination 'platform=macOS' test
