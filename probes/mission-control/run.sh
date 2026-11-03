#!/bin/sh
set -eu
cd "$(dirname "$0")"
mkdir -p .build
swiftc -O main.swift -o .build/mc-state-probe
exec .build/mc-state-probe "${1:-180}"
