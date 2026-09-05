# DMD perf check

Every pull request is measured against its merge-base with master. CI builds dmd at both commits the same way on the runner:
host compiler ldc-1.42.0, one shared PGO profile, and LTO. So any difference in the numbers comes from the PR itself.

The bot posts one sticky comment when at least one metric crosses its noise threshold, and updates that same comment on every push.
If nothing crosses the threshold, it doesn't post at all.

Most metrics are instruction counts measured under cachegrind, which are very much stable between runs. Wall time swings by a few
percent from run to run on shared CI runners, so it is shown as informational metric.

## Metrics

| Metric | What is measured | Threshold |
|--------|------------------|----------:|
| compile hello.d (instr) | instructions to run `dmd -c hello.d` under cachegrind | 0.1% |
| compile hello.d -O -release (instr) | same, with `-O -release` | 0.1% |
| compile Phobos (instr) | instructions for `dmd -c -i=std -preview=dip1000 std/package.d` | 0.1% |
| compile Phobos codegen (instr) | the Phobos compile minus a frontend-only (`-o-`) run | 0.1% |
| compile vibe.d (instr) | instructions to compile a vibe.d app in one invocation (`-i`) | 0.1% |
| dmd binary size (stripped) | size of the stripped dmd binary | 0.1% |
| hello binary size (stripped) | size of the stripped hello executable | 0.1% |
| peak RSS (compile ...) | maximum resident set size, from `/usr/bin/time -v` | 2% |
| compile dmd itself (wall) | wall time to build dmd itself, `generated/build dmd BUILD=debug -j1 --force`, min of 3 runs | 2% |
| compile ... (wall) | total wall time, from `-ftime-trace` | informational |
