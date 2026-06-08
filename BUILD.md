# gSpanCORK build log

Notes from building gSpanCORK on Linux (June 2026) using the **bundled igraph**
under `igraph/igraph/`, without installing igraph to `/usr/local`.

## Prerequisites

- `g++`
- `make`
- Bundled igraph already built at `igraph/igraph/src/.libs/libigraph.so`
  (rebuild with `make` in `igraph/igraph/` if needed)

## Build (bundled igraph, no sudo)

From the repo root:

```bash
cd src
make clean
make IGRAPHLIB="-L../igraph/igraph/src/.libs -ligraph" \
     IGRAPHINCLUDE="-I../igraph/igraph/src"
```

This produces `bin/gSpanCORK`.

## Run

Set the runtime library path so the dynamic linker finds bundled igraph:

```bash
export LD_LIBRARY_PATH="/path/to/gspan-cork/igraph/igraph/src/.libs:$LD_LIBRARY_PATH"
```

Example (PTC dataset from `Readme.txt`):

```bash
cd /path/to/gspan-cork
bin/gSpanCORK -f CORK10 -l data/ptc.lab -m 34 < data/ptc.txt
```

## Issues encountered and fixes

### 1. Wrong igraph headers (`igraph/igraph/include/`)

**Symptom:** compile error in `dfs.cpp` — cannot convert
`igraph_vector_long_t*` to `igraph_bool_t*` when calling
`igraph_subisomorphic_vf2`.

**Cause:** gSpanCORK uses the **igraph 0.6 colored-isomorphism API** (vertex/edge
label arguments). The headers in `igraph/igraph/include/igraph.h` declare the
older 0.5.1 API. The patched 0.6 declarations live in
`igraph/igraph/src/igraph.h` (see `igraph/readme.txt`).

**Fix:** use `-I../igraph/igraph/src`, not `-I../igraph/igraph/include`.

### 2. Linker errors in `src/Makefile` (line 45)

**Symptoms:**

- `multiple definition of main` / `usage()` / `gSpanCORK_executable`
- `undefined reference to igraph_*` despite `-ligraph`

**Cause:** the original link rule both compiled `gSpanCORK.cpp` and linked
`gSpanCORK.o` (duplicate symbols), and placed `-ligraph` **before** the object
files (Linux linkers need libraries **after** objects).

**Fix:** in `src/Makefile`, line 45 was changed from:

```makefile
${CPP} ${CPPFLAGS} ${IGRAPHLIB} ${IGRAPHINCLUDE} gSpanCORK.cpp ${OBJ} -o ${BIN}gSpanCORK
```

to:

```makefile
${CPP} ${CPPFLAGS} ${IGRAPHINCLUDE} ${OBJ} -o ${BIN}gSpanCORK ${IGRAPHLIB}
```

## Alternative: system install (Option A)

Install bundled igraph to `/usr/local`, then use default Makefile paths:

```bash
cd igraph/igraph
make
sudo make install

cd ../../src
make
```

Default Makefile settings expect igraph at `/usr/local/lib` and
`/usr/local/include/igraph`. Note: even with a system install, the **0.6**
header patch may still be required unless `include/igraph.h` is updated to
match `src/igraph.h`.

## One-liner (build + run)

```bash
cd src && \
make clean && \
make IGRAPHLIB="-L../igraph/igraph/src/.libs -ligraph" \
     IGRAPHINCLUDE="-I../igraph/igraph/src" && \
export LD_LIBRARY_PATH="$(pwd)/../igraph/igraph/src/.libs:$LD_LIBRARY_PATH" && \
cd .. && \
bin/gSpanCORK -f CORK10 -l data/ptc.lab -m 34 < data/ptc.txt
```
