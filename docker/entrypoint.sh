#!/bin/bash
set -e

CONFIG_PATH="${CONFIG_PATH:-/data/config.json}"
mkdir -p "$(dirname "$CONFIG_PATH")"

exec /opt/pironman5/venv/bin/pironman5 --config-path "$CONFIG_PATH" start
