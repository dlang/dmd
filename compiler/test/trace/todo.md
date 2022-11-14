# DMD Tracing TODO in order priority

- Write the mangled names to save space

- Add test that exercise all modes for a small D file with no object.d
  file. Then move statistics calcs into trace.d.

- Put back tracing memory usage by injecting a fake pure memoryUsageTracking functon in the
  rmem.d. Look at commit in rmem.d and `Mem.allocated`.

- Merge with Max Haughton’s work

- What about ditching all but last file version
  - Specifically: `ProbeRecord`, `ProbeRecordV2`, `TraceFileHeader`, `TraceFileHeaderV4`,
    `fVersion`, `(fVersion = 3)`?

- Make behavior be controlled via the `-trace` flag because I believe this is
  gonna be the most productive way of interaction. For instance
  - `dmd -trace=sum:Function,Type;file:trace`
  - `-trace=all:Template`
  - `-trace=file:SOME_FILE`

- Document why both `.dmd_trace` and `.dmd_symbol` are needed

- Adjusting symbol casings

- Discuss traceFile naming. Shall we add automatically add a timestamp to the file name?

- Filter on trace types during writing

- Make the global pointer to array a normal array instead
