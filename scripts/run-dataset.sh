#!/usr/bin/env bash
# Run gSpanCORK on a dataset and post-process outputs.
#
# Usage:
#   ./scripts/run-dataset.sh <dataset> [gSpanCORK flags...]
#
# The dataset name selects graph and label files under data/:
#   <name> -> data/<name>_graph.txt + data/<name>_label.txt
#
# Output is written to results/<dataset>/:
#   patterns_raw.txt  stdout from gSpanCORK (may include verbose lines)
#   log.txt           stderr from gSpanCORK
#   patterns.txt      clean DIMACS subgraphs only
#   cork_stats.tsv    per-iteration CORK statistics table
#
# Examples:
#   ./scripts/run-dataset.sh ptc -f FCORK -m 34
#   ./scripts/run-dataset.sh ptc -f CORK10 -v -w 1
#
# Notes:
#   - Class labels (-l) are set automatically; do not pass -l.
#   - -v is added automatically if omitted (needed for cork_stats.tsv).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GSPAN="${GSPAN:-$ROOT/bin/gSpanCORK}"
RESULTS_ROOT="${RESULTS_ROOT:-$ROOT/results}"
IGRAPH_LIBS="$ROOT/igraph/igraph/src/.libs"

usage() {
    cat <<EOF
usage: $0 <dataset> [gSpanCORK flags...]

Run discriminative subgraph mining and write results to results/<dataset>/.

Examples:
  $0 ptc -f FCORK -m 34
  $0 mutag -f CORK10 -m 2 -w 1

See also: bin/gSpanCORK -h
EOF
    exit "${1:-0}"
}

[[ $# -ge 1 ]] || usage 1

dataset="$1"
shift

gspan_args=()
has_v=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage 0
            ;;
        -l)
            echo "error: -l is set automatically from the dataset; do not pass -l" >&2
            exit 1
            ;;
        -v)
            has_v=1
            gspan_args+=("$1")
            shift
            ;;
        *)
            gspan_args+=("$1")
            shift
            ;;
    esac
done

resolve_dataset_files() {
    local name="$1"
    graph="$ROOT/data/${name}_graph.txt"
    labels="$ROOT/data/${name}_label.txt"
    if [[ -f "$graph" && -f "$labels" ]]; then
        return 0
    fi
    echo "error: could not find graph/label files for dataset '$name'" >&2
    echo "       expected data/${name}_graph.txt + data/${name}_label.txt" >&2
    exit 1
}

resolve_dataset_files "$dataset"

if [[ ! -x "$GSPAN" && ! -f "$GSPAN" ]]; then
    echo "error: gSpanCORK binary not found at $GSPAN" >&2
    echo "       build it first; see BUILD.md" >&2
    exit 1
fi

if [[ "$has_v" -eq 0 ]]; then
    echo "note: adding -v so CORK statistics are captured in log.txt" >&2
    gspan_args=(-v "${gspan_args[@]}")
fi

out_dir="$RESULTS_ROOT/$dataset"
mkdir -p "$out_dir"

if [[ -d "$IGRAPH_LIBS" ]]; then
    export LD_LIBRARY_PATH="$IGRAPH_LIBS${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

cmd=("$GSPAN" -l "$labels" "${gspan_args[@]}")
printf '%q ' "${cmd[@]}" "<" "$graph" > "$out_dir/command.txt"
echo >> "$out_dir/command.txt"

echo "dataset:  $dataset" >&2
echo "graphs:   $graph" >&2
echo "labels:   $labels" >&2
echo "output:   $out_dir/" >&2
echo "running:  ${cmd[*]} < $graph" >&2

"${cmd[@]}" < "$graph" > "$out_dir/patterns_raw.txt" 2> "$out_dir/log.txt"

"$ROOT/scripts/extract-pattern.sh" "$out_dir/patterns_raw.txt" --all \
    -o "$out_dir/patterns.txt"
"$ROOT/scripts/extract-cork-stats.sh" "$out_dir/log.txt" "$out_dir/cork_stats.tsv"

echo "done:" >&2
echo "  $out_dir/patterns_raw.txt" >&2
echo "  $out_dir/log.txt" >&2
echo "  $out_dir/patterns.txt" >&2
echo "  $out_dir/cork_stats.tsv" >&2
