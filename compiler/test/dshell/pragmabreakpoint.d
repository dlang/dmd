/// Sample session of using the compile time debugger via pragma(breakpoint)

module pragmabreakpoint;

import dshell;
import std.process;
import core.time;

//no newlines after the (ctdb) prompt here
const expectedOutput = `Pragma Breakpoint: static else, before expanding the dependent template
(ctdb) Backtrace
frame 0 compiler/test/compilable/extra-files/pragmaBreakpoint.d(3): scope: T (struct)
frame 1 compiler/test/compilable/extra-files/pragmaBreakpoint.d(18): scope: T!3LU (template instance)
frame 2 : scope: __anonymous (ScopeDsymbol)
frame 3 compiler/test/compilable/extra-files/pragmaBreakpoint.d: scope: pragmaBreakpoint (module)
frame 4 : scope: __anonymous (ScopeDsymbol)
(ctdb) Members of scope pragmaBreakpoint
pragmaBreakpoint.object
pragmaBreakpoint.T(ulong x)
D main
pragmaBreakpoint._d_cmain!()
pragmaBreakpoint.T!3LU
(ctdb) continuing compilation
Pragma Breakpoint: static else, before expanding the dependent template
(ctdb) continuing compilation
Pragma Breakpoint: static else, before expanding the dependent template
(ctdb) continuing compilation
Pragma Breakpoint: done T!0LU
(ctdb) Backtrace
frame 0 compiler/test/compilable/extra-files/pragmaBreakpoint.d(3): scope: T (struct)
frame 1 compiler/test/compilable/extra-files/pragmaBreakpoint.d(10): scope: T!0LU (template instance)
frame 2 : scope: __anonymous (ScopeDsymbol)
frame 3 compiler/test/compilable/extra-files/pragmaBreakpoint.d: scope: pragmaBreakpoint (module)
frame 4 : scope: __anonymous (ScopeDsymbol)
(ctdb) Members of scope T!0LU
pragmaBreakpoint.T!0LU.T
(ctdb) continuing compilation
Pragma Breakpoint: main
(ctdb) continuing compilation
`;

int main(){

    auto inputPipe = std.process.pipe();
    auto outputPipe = std.process.pipe();

    auto args = parseCommand("$DMD $EXTRA_FILES/pragmabreakpoint/pragmabreakpoint.d");

    auto proc = spawnProcess(args, inputPipe.readEnd, outputPipe.writeEnd, outputPipe.writeEnd);
    inputPipe.writeEnd.write("bt\nm 3\nc\nc\nc\nbt\nm 1\nc\nc\nc\nc\n"); //2 extra "continue" + newlines should be ignored
    inputPipe.writeEnd.flush();
    const deadline = MonoTime.currTime + 5.seconds;
    while(true)
    {
        auto result = tryWait(proc);
        if(result.terminated){
            enforce(result.status == 0);
            break;
        }
        if(MonoTime.currTime > deadline){
            assert(false, "pragmabreakpoint compile test timed out");
        }
        Thread.sleep(100.msecs);
    }
    const output = cast(string) outputPipe.readEnd.byChunk(4096).join();
    assert(output == expectedOutput,  "actual output:\n" ~ output);
    return 0;
}
