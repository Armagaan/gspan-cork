#!/usr/bin/env bash
# Extract selected subgraph patterns from gSpanCORK pattern output.
#
# Usage:
#   ./scripts/extract-pattern.sh <patterns-file> <id> [id...]
#   ./scripts/extract-pattern.sh <patterns-file> --all [-o output-file]
#
# Examples:
#   ./scripts/extract-pattern.sh ptc_patterns.txt 5
#   ./scripts/extract-pattern.sh ptc_patterns.txt 5 -o pattern_5.txt
#   ./scripts/extract-pattern.sh ptc_patterns.txt 0 5 24
#   ./scripts/extract-pattern.sh ptc_patterns.txt --all -o patterns_clean.txt

set -euo pipefail

usage() {
    echo "usage: $0 <patterns-file> <id> [id...] [-o output-file]" >&2
    echo "       $0 <patterns-file> --all [-o output-file]" >&2
    exit 1
}

[[ $# -ge 2 ]] || usage

input="$1"
shift

if [[ ! -f "$input" ]]; then
    echo "error: file not found: $input" >&2
    exit 1
fi

output=""
want_all=0
declare -A want

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all)
            want_all=1
            shift
            ;;
        -o)
            [[ $# -ge 2 ]] || usage
            output="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            if [[ "$1" =~ ^[0-9]+$ ]]; then
                want["$1"]=1
                shift
            else
                echo "error: unknown argument: $1" >&2
                usage
            fi
            ;;
    esac
done

if [[ "$want_all" -eq 0 && ${#want[@]} -eq 0 ]]; then
    echo "error: specify at least one pattern id or --all" >&2
    exit 1
fi

want_ids=""
if [[ "$want_all" -eq 0 ]]; then
    want_ids=$(printf '%s\n' "${!want[@]}" | sort -n | paste -sd, -)
fi

separate_blocks=0
if [[ "$want_all" -eq 1 || ${#want[@]} -gt 1 ]]; then
    separate_blocks=1
fi

extract_patterns() {
    awk -v want_all="$want_all" -v want_ids="$want_ids" -v separate_blocks="$separate_blocks" '
        BEGIN {
            if (!want_all) {
                n = split(want_ids, ids, ",")
                for (i = 1; i <= n; i++)
                    want[ids[i]] = 1
            }
        }
        /^t # [0-9]+ \*/ {
            if (separate_blocks && need_sep)
                print ""
            cur = $3
            in_block = want_all || (cur in want)
            if (in_block) {
                print
                need_sep = separate_blocks
            }
            next
        }
        in_block && /^[ve] / {
            print
            next
        }
        in_block {
            in_block = 0
        }
    ' "$input"
}

if [[ -n "$output" ]]; then
    extract_patterns > "$output"
    echo "Wrote $output" >&2
else
    extract_patterns
fi
