#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter create --project-name apexbooks --org in.apexbooks --platforms=android,ios,web,windows,macos,linux .
flutter pub get
