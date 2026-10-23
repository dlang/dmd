/// Sample session of using the compile time debugger via pragma(breakpoint)

module pragmabreakpoint;

import dshell;

const expectedOutput = `Pragma Breakpoint: static else, before expanding the dependent template
(ctdb)
Backtrace
frame 0 compiler/test/compilable/extra-files/pragmaBreakpoint.d(39): scope: T (struct)
frame 1 compiler/test/compilable/extra-files/pragmaBreakpoint.d(54): scope: T!3LU (template instance)
frame 2 : scope: __anonymous (ScopeDsymbol)
frame 3 compiler/test/compilable/extra-files/pragmaBreakpoint.d: scope: pragmaBreakpoint (module)
frame 4 : scope: __anonymous (ScopeDsymbol)
(ctdb)
Members of scope pragmaBreakpoint
pragmaBreakpoint.object
pragmaBreakpoint.T(ulong x)
D main
pragmaBreakpoint._d_cmain!()
pragmaBreakpoint.T!3LU
(ctdb)
continuing compilation
Pragma Breakpoint: static else, before expanding the dependent template
(ctdb)
continuing compilation
Pragma Breakpoint: static else, before expanding the dependent template
(ctdb)
continuing compilation
Pragma Breakpoint: done T!0LU
(ctdb)
Backtrace
frame 0 compiler/test/compilable/extra-files/pragmaBreakpoint.d(39): scope: T (struct)
frame 1 compiler/test/compilable/extra-files/pragmaBreakpoint.d(46): scope: T!0LU (template instance)
frame 2 : scope: __anonymous (ScopeDsymbol)
frame 3 compiler/test/compilable/extra-files/pragmaBreakpoint.d: scope: pragmaBreakpoint (module)
frame 4 : scope: __anonymous (ScopeDsymbol)
(ctdb)
Members of scope T!0LU
pragmaBreakpoint.T!0LU.T
(ctdb)
continuing compilation
Pragma Breakpoint: main
(ctdb)
continuing compilation`;

int main(){

    auto inputPipe = std.process.pipe();
    auto outputPipe = std.process.pipe();

    auto args = parseCommand("$DMD $EXTRA_FILES/pragmabreakpoint/pragmabreakpoint.d");

    auto proc = spawnProcess(args, inputPipe.readEnd, outputPipe.writeEnd, outputPipe.writeEnd);
    inputPipe.write("bt\nm 3\nc\nc\nc\nbt\nm 1\nc\n c\n");
    enforce(wait(proc) == 0);

    const output = cast(string) outputPipe.readEnd.byChunk(4096).join();
    assert(output == expectedOutput,  "actual output:\n" ~ output);
}
