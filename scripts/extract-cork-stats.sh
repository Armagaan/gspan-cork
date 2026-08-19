#!/usr/bin/env bash
# Extract CORK per-iteration statistics from gSpanCORK log output.
#
# Usage:
#   ./scripts/extract-cork-stats.sh [log-file] [output.tsv]
#
# Examples:
#   ./scripts/extract-cork-stats.sh ptc.out
#   ./scripts/extract-cork-stats.sh ptc_log.txt ptc_cork_stats.tsv

set -euo pipefail

input="${1:-ptc.out}"
output="${2:-${input%.*}_cork_stats.tsv}"

if [[ ! -f "$input" ]]; then
    echo "error: file not found: $input" >&2
    exit 1
fi

grep -P '^\t(correspondences|[0-9])' "$input" | sed 's/^\t//' > "$output"

echo "Wrote $(wc -l < "$output") lines to $output" >&2
