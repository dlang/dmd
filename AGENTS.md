# AGENTS.md

DMD, the reference D compiler (with `druntime/` and the compiler test suite).
Phobos is a separate repo, expected at `../phobos`.

Where the details live (read these rather than relying on this file):
- Conventions, branching, style, changelog: `CONTRIBUTING.md`
- Source layout: `compiler/src/dmd/README.md`
- Tests and test directives: `compiler/test/README.md`
- Build options: `compiler/src/build.d --help`
- What CI actually runs: `.github/`, `ci/`, `.cirrus.yml`, `.circleci/`, `azure-pipelines.yml`.
  If this file and CI disagree, CI wins.

## Before a change is reviewable

Run from the repo root and make sure these pass:

```sh
make -j$(nproc) dmd dmd-unittest         # build the compiler and run internal unittests
compiler/test/run.d <affected tests>     # e.g. fail_compilation/foo.d; `make dmd-test` for broad changes
make style                               # style/whitespace checks
dub build dmd:frontend                   # only if .d files were added/moved/removed or imports changed
dub build dmd:compiler                   # only if .d files were added/moved/removed or imports changed
```

### What may run concurrently

The `make`-based steps share `generated/` and must run one at a time, in the
order listed above: build first, then tests (they need the built compiler),
then `make style`. Only the DUB steps are independent of `generated/` (they
build under `.dub/`), so they can run in the background alongside that chain:

```sh
# Only if .d files were added/moved/removed or imports changed
( dub build dmd:frontend && dub build dmd:compiler ) &

make -j$(nproc) dmd dmd-unittest
compiler/test/run.d <affected tests>
make style

wait   # collect the DUB job and check its exit status
```

- Run the two DUB commands sequentially, not in parallel: `dmd:compiler`
  depends on `dmd:frontend` and both use `.dub/`.
- Don't run more than one `compiler/test/run.d` at a time in the same tree;
  it parallelizes internally and invocations share test output directories.
- `make -j$(nproc)` already uses all cores, so the background DUB job will
  slow the build somewhat. The benefit is hiding DUB's wall-clock time.
- Need real parallelism between make-based steps? Use a separate checkout
  or worktree for each.

## Things that are easy to get wrong

- **Three build paths exist**: GNU Make (`Makefile`), `compiler/src/build.d` (what Make calls),
  and DUB (`dub.sdl`). A change can pass Make and still break DUB, because `dub.sdl` lists some
  source files explicitly and excludes others by pattern. Update it when files or cross-module imports change.
- **Target branch**: bug/regression fixes go to `stable`, new features to `master`.
- **Bug fixes need a regression test** in `compiler/test/`. Review any `AUTO_UPDATE=1` diff;
  a changed compiler message is a behavior change.
- **Frontend C++ headers** are checked in. If `extern(C++)` frontend declarations change, run
  `compiler/src/build.d cxx-headers-test AUTO_UPDATE=1`.
- **Changelog**: user-visible changes that don't simply close an issue need an entry in `changelog/`
  (see `changelog/README.md`).
- **No concurrent `make` in one tree**: invocations share `generated/` (this includes
  `make style` and `make dmd-test`). Only the DUB steps may overlap with `make`;
  see "What may run concurrently" above. Don't commit `generated/`.
- Keep changes focused; no drive-by reformatting or tree-wide rewrites.
