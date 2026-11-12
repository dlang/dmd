# Tracing requests for function body analysis

When investigating attribute inference or forward references, knowing which function started semantic3 is not enough: a module traversal, a template instantiation, or an expression can request that analysis. The developer-only `TraceFunctionSemantic` debug identifier records those request origins and the decisions between them. It does not change inference or scheduling.

Build a compiler with the debug identifier, then select a trace file at runtime. From the repository root, using an existing host compiler:

```sh
dmd -run compiler/src/build.d --force dmd AUTO_BOOTSTRAP=0 DFLAGS=-debug=TraceFunctionSemantic
```

Set `HOST_DMD=/path/to/dmd` as an additional build argument if necessary. `--force` matters when changing build flags in an existing build directory: timestamp checks alone do not detect that change. The executable is under `generated/<os>/<build>/<model>/`.

For example, on a POSIX shell:

```sh
DMD_TRACE_FUNCTION_SEMANTIC=annotated-first.trace /path/to/traced/dmd -c -o- annotated.d ion.d
DMD_TRACE_FUNCTION_SEMANTIC=ion-first.trace /path/to/traced/dmd -c -o- ion.d annotated.d
```

In PowerShell:

```powershell
$env:DMD_TRACE_FUNCTION_SEMANTIC = "$PWD/annotated-first.trace"
& /path/to/traced/dmd -c -o- annotated.d ion.d
$env:DMD_TRACE_FUNCTION_SEMANTIC = "$PWD/ion-first.trace"
& /path/to/traced/dmd -c -o- ion.d annotated.d
Remove-Item Env:DMD_TRACE_FUNCTION_SEMANTIC
```

Use runtime headers matching the compiler source revision, as with other development builds. The examples above use the two files from [issue #24202](https://github.com/dlang/dmd/issues/24202). With the behavior reported there, the request chains differ as follows:

```text
annotated.d ion.d:
  root-module-semantic3(annotated)
    semantic3-dispatch(Annotated instance and aggregate)
      start(Annotated.opEquals)
        DotVarExp-function(Algebraic.opEquals), annotated.d(5,23)
          functionSemantic -> instantiated-function-attributes -> functionSemantic3
            start(Algebraic.opEquals)
              DotVarExp-function(Annotated.opEquals), ion.d(6,22)
                functionSemantic3 -> skip(already-active)

ion.d annotated.d:
  root-module-semantic3(ion)
    typeinfo-special-member(Algebraic.__xopEquals)
      start(Algebraic.__xopEquals), gag=1
        DotVarExp-function(Algebraic.opEquals), location unavailable
          start(Algebraic.opEquals)
            DotVarExp-function(Annotated.opEquals), ion.d(6,22)
              start(Annotated.opEquals)
```

This distinguishes the expression request from the later `functionParameters` request, and the ordinary member traversal from TypeInfo special-member scheduling. It does not prove that reordering either operation is safe.

## Reading the trace

Each tab-separated line begins with a monotonically increasing event ID. `parent` is the enclosing synchronous request's event ID; zero means there is no instrumented parent. Requests restore their parent on return, including early returns. Event IDs and declaration addresses are local to one frontend session.

The events are `request`, `start`, `finish`, `skip`, and `defer`. `start` means the function visitor has passed its active/completed guard and is entering semantic3, not necessarily that a body statement has been visited. `finish` distinguishes completed semantic3 from an early exit. `reason` identifies the operation or guard.

Important fields:

| Field | Meaning |
| --- | --- |
| `target`, `name`, `kind` | Declaration address, readable name, and kind. Use the address to distinguish instances with identical printed names. |
| `decl` | Target declaration location. It is not a request location. |
| `phase` | Target's current `PASS`: 0 initial, 1 semantic, 2 semanticdone, 3 semantic2, 4 semantic2done, 5 semantic3, 6 semantic3done; later values are defined in `dsymbol.d`. |
| `context`, `contextName`, `contextPhase` | Owner of the scope supplied at this event, or an explicitly supplied scheduling owner. A dispatcher using a saved declaration scope can name the target's module here. Follow `parent` links to the requesting expression or scheduler to identify the dynamic caller. |
| `locKind`, `loc` | A request location, an instantiation location, or unavailable. Locations always include columns when present, independent of diagnostic formatting options. Generated operations can have no location. |
| `module`, `tinst` | Module and template instance in the supplied scope, when available. |
| `spec`, `gag`, `errors`, `gaggedErrors` | Enclosing speculative template identity and the current gagging/error counters. `spec` alone does not describe every speculative context. |
| `deferred3`, `hasScope`, `savedCompilerHook` | Target's deferred3 flag, presence of a saved scope, and compiler-hook deferral flag in that saved scope. |
| `fullinst` | Full-instantiation requirement in the supplied scope. |
| `pendingPure`, `pendingNogc`, `pendingNothrow` | Existing pending inference flags, read without querying attributes. They do not establish that inference was abandoned. |
| `site` | Compiler source location of the instrumentation point. |

Unavailable textual values are `unavailable`; inapplicable numeric fields use `-1`, and absent pointers print as null addresses. Backslashes, tabs, CR and LF in textual values are escaped as `\\`, `\t`, `\r`, and `\n`. The format is a debugging aid, not a stable tooling interface.

## Scope and lifecycle

Ordinary compiler builds contain none of the tracing code and ignore `DMD_TRACE_FUNCTION_SEMANTIC`. In a trace build, an unset or empty variable disables output. The file is opened with truncation on the first traced operation; use a separate writable filename for each process or frontend session. If opening it fails, no trace is produced and compiler diagnostics are unaffected. Frontend initialization/deinitialization resets the trace state and closes its file. Rows are flushed as they are written.

The probes cover root-module scheduling, template-instance scheduling, selected function-expression and call-resolution requests, TypeInfo equality/comparison helper requests, `functionSemantic`/`functionSemantic3`, and function semantic3 entry/exit guards. They are not an inventory of every semantic3 caller or attribute consumer. Uninstrumented callers can appear as a dispatcher request without a more specific parent. Tracing does not retain `Scope*` values, call mutating attribute queries, change error counts, or change gagging.

The helper's unit test checks nested/early-return parent restoration, escaping, reset, and preservation of error/gagging counters. Run it with the compiler unit tests in a trace build:

```sh
dmd -run compiler/src/build.d --force unittest AUTO_BOOTSTRAP=0 DFLAGS=-debug=TraceFunctionSemantic
```
