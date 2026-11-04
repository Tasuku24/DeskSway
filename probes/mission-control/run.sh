#!/bin/sh
set -eu
cd "$(dirname "$0")"
mkdir -p .build
swiftc -O ../../Sources/DeskSwayCore/Detection.swift ../../Sources/DeskSwayCore/MissionControlReader.swift main.swift -o .build/mc-state-probe
exec .build/mc-state-probe "${1:-180}"
