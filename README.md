# gSpanCORK

Discriminative frequent subgraph mining with CORK feature selection, based on [gSpan](http://www.kyb.mpg.de/bs/people/nowozin/gboost/) (Taku Kudo) and extended by Marisa Thoma and Lei Zhao.

This repository adds a reproducible build path (bundled igraph), helper scripts, and example datasets under `data/`.

> The original upstream readme is preserved in [Readme.txt](Readme.txt).

## Quick start

### 1. Build

See **[BUILD.md](BUILD.md)** for prerequisites, bundled-igraph build commands, linker notes, and `LD_LIBRARY_PATH` setup.

```bash
cd src
make clean
make IGRAPHLIB="-L../igraph/igraph/src/.libs -ligraph" \
     IGRAPHINCLUDE="-I../igraph/igraph/src"
```

This produces `bin/gSpanCORK`.

### 2. Run a dataset

```bash
./scripts/run-dataset.sh ptc -f FCORK -m 34
```

Results land in **`results/<dataset>/`**:

| File | Description |
|------|-------------|
| `patterns_raw.txt` | Raw stdout from gSpanCORK |
| `log.txt` | stderr (progress and CORK statistics) |
| `patterns.txt` | Clean selected subgraphs in DIMACS format |
| `cork_stats.tsv` | Per-iteration CORK statistics table |
| `command.txt` | Exact command that was run |

The script sets `-l` from the dataset name and adds `-v` if you omit it (so the stats table is captured). Pass any other [gSpanCORK flags](#gspancork-flags) after the dataset name.

## Datasets

Graph and label files live in `data/`:

| Dataset | Graphs | Labels |
|---------|--------|--------|
| `ptc` | `data/ptc_graph.txt` | `data/ptc_label.txt` |
| `mutag` | `data/mutag_graph.txt` | `data/mutag_label.txt` |
| `nci1` | `data/nci1_graph.txt` | `data/nci1_label.txt` |
| `cycles` | `data/cycles_graph.txt` | `data/cycles_label.txt` |

The `cycles` files are generated from the SMP k-cycle benchmark (k=6, n≈56) via
`python folder/CYCLES/build_cycles_gspan.py` (5000 class-balanced graphs by default).

Naming convention for datasets:

- `data/<name>_graph.txt` + `data/<name>_label.txt`

### Input format

**Graphs** — DIMACS-style, one graph after another:

```
t # <graph_id>
v <vertex_id> <vertex_label>
e <from> <to> <edge_label>
```

Vertex indices start at 0. Labels are non-negative integers.

**Class labels** — one line per graph (in graph order). Only the first number on each line is used. Binary classification (`0`/`1`) is required for CORK.

Lines starting with `c` in some datasets (e.g. PTC) are metadata only; gSpanCORK skips them.

## Scripts

| Script | Purpose |
|--------|---------|
| [`scripts/run-dataset.sh`](scripts/run-dataset.sh) | Mine + extract patterns + extract CORK table |
| [`scripts/extract-pattern.sh`](scripts/extract-pattern.sh) | Pull `t`/`v`/`e` blocks from raw pattern output |
| [`scripts/extract-cork-stats.sh`](scripts/extract-cork-stats.sh) | Pull tab-separated CORK stats from a log file |

### `run-dataset.sh`

```bash
./scripts/run-dataset.sh <dataset> [gSpanCORK flags...]
```

Examples:

```bash
./scripts/run-dataset.sh ptc -f FCORK -m 34
./scripts/run-dataset.sh ptc -f CORK10 -m 34 -w 1
./scripts/run-dataset.sh mutag -f FCORK
```

Override output location:

```bash
RESULTS_ROOT=/tmp/gspan_results ./scripts/run-dataset.sh ptc -f FCORK
```

### Post-processing only

If you already ran gSpanCORK manually with split streams:

```bash
bin/gSpanCORK -f FCORK -l data/ptc_label.txt -v < data/ptc_graph.txt \
  > results/ptc/patterns_raw.txt 2> results/ptc/log.txt

./scripts/extract-pattern.sh results/ptc/patterns_raw.txt --all \
  -o results/ptc/patterns.txt
./scripts/extract-cork-stats.sh results/ptc/log.txt results/ptc/cork_stats.tsv
```

View the stats table:

```bash
column -t -s $'\t' results/ptc/cork_stats.tsv | less -S
```

## gSpanCORK flags

Call `bin/gSpanCORK -h` for the full list. Common options:

| Flag | Meaning |
|------|---------|
| `-f CORK` / `-f CORK10` / `-f FCORK` | Feature selection mode |
| `-m <minsup>` | Minimum support (absolute graph count) |
| `-t <n>` | Stop when correspondences fall below `n` (with `-f`) |
| `-v` | Verbose CORK statistics on stderr |
| `-w 1` / `-w 2` | Traceback of matching graph ids (and frequencies) |
| `-e` / `-d` | Output DFS codes instead of DIMACS |
| `-L <n>` | Maximum subgraph size (vertices) |
| `-n <n>` | Minimum subgraph size (vertices; default 2) |

`-l` is supplied automatically by `run-dataset.sh`.

## Output interpretation

### `patterns.txt`

Each selected subgraph:

```
t # <id> * <support>
v ...
e ...
```

- **`id`** — greedy selection order (0 = first chosen).
- **`support`** — number of graphs containing the pattern (on the remaining set for FCORK).

### `cork_stats.tsv`

Tab-separated table written to stderr when `-v` is set (captured in `log.txt` by `run-dataset.sh`). One row per selected subgraph, plus a final `last` summary row.

Example (`results/mutag/cork_stats.tsv`):

| correspondences | correspondence_classes | num_unresolved | size_unresolved | max_unresolved | iteration | tested | frequent | minimal | winners | pruned | time_[s] |
|-----------------|------------------------|----------------|-----------------|----------------|-----------|--------|----------|---------|---------|--------|----------|
| 10448 | 1 | 1 | 188 | 188 | 0 | 17 | 17 | 17 | 3 | 14 | 0 |
| 7126 | 2 | 2 | 94 | 151 | 1 | 15 | 15 | 14 | 3 | 11 | 0 |
| … | … | … | … | … | … | … | … | … | … | … | … |
| 4416 | 16 | 10 | 18.2 | 110 | last | 11 | 11 | 11 | 0 | 11 | 0 |

Column reference:

| Column | Meaning |
|--------|---------|
| `correspondences` | Global CORK score after this iteration's subgraph is selected. Sum of one-vs-rest class ambiguities across all correspondence equivalence classes. **Lower is better.** |
| `correspondence_classes` | Number of correspondence equivalence classes currently tracked. Grows as CORK splits groups of graphs that remain class-ambiguous. |
| `num_unresolved` | Equivalence classes that still contain graphs from **more than one class** (not yet fully separated). |
| `size_unresolved` | Average number of graphs per unresolved equivalence class (`num_unresolved` > 0). |
| `max_unresolved` | Size of the largest unresolved equivalence class. |
| `iteration` | Greedy selection round (0-based), matching `t # <id>` in `patterns.txt`. The final row is labelled `last`. |
| `tested` | Candidate subgraphs evaluated in this iteration's gSpan search. |
| `frequent` | Candidates that met the minimum support threshold (`-m`). |
| `minimal` | Frequent candidates that also passed the minimum DFS-code check. |
| `winners` | Minimal candidates that improved the best CORK score during this iteration (competing subgraphs before the final pick). |
| `pruned` | Minimal candidates whose search branches were cut early by CORK pruning (could not beat the current best). |
| `time_[s]` | Wall-clock seconds for this iteration. |

## Manual examples (without `run-dataset.sh`)

From the repo root, with `LD_LIBRARY_PATH` set per [BUILD.md](BUILD.md):

```bash
# Top 10 subgraphs, 10% minimum support
bin/gSpanCORK -f CORK10 -l data/ptc_label.txt -m 34 < data/ptc_graph.txt

# FCORK with traceback
bin/gSpanCORK -f FCORK -l data/ptc_label.txt -m 34 -w 2 < data/ptc_graph.txt
```

## Source and citation

Original package: [sam2010.zip](http://www.dbs.ifi.lmu.de/~thoma/pub/sam2010/sam2010.zip)

> Marisa Thoma, Hong Cheng, Arthur Gretton, Jiawei Han, Hans-Peter Kriegel, Alex Smola, Le Song, Philip Yu, Xifeng Yan, Karsten Borgwardt. *Discriminative frequent subgraph mining with optimality guarantees*, Statistical Analysis and Data Mining (2010).

Paper datasets: [data.zip](http://www.dbs.ifi.lmu.de/~thoma/pub/sam2010/data.zip) (23.4 MB).

## License

GPL v2 — see source file headers. Provided without warranty.
