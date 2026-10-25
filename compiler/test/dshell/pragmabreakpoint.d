/// Sample session of using the compile time debugger via pragma(breakpoint)

module pragmabreakpoint;

import dshell;
import std.process;
import core.time;
import std.string;
import std.algorithm;
import std.array;

//no newlines after the (ctdb) prompt here
const expectedOutput = `Pragma Breakpoint: static else, before expanding the dependent template
(ctdb) Backtrace
frame 0 dshell/extra-files/pragmabreakpoint/pragmabreakpoint.d(3): scope: T (struct)
frame 1 dshell/extra-files/pragmabreakpoint/pragmabreakpoint.d(18): scope: T!3 (template instance)
frame 2 : scope: __anonymous (ScopeDsymbol)
frame 3 dshell/extra-files/pragmabreakpoint/pragmabreakpoint.d: scope: pragmabreakpoint (module)
frame 4 : scope: __anonymous (ScopeDsymbol)
(ctdb) Members of scope pragmabreakpoint
pragmabreakpoint.pragmabreakpoint.object
pragmabreakpoint.pragmabreakpoint.T(int x)
D main
pragmabreakpoint.pragmabreakpoint._d_cmain!()
pragmabreakpoint.pragmabreakpoint.T!3
(ctdb) continuing compilation
Pragma Breakpoint: static else, before expanding the dependent template
(ctdb) continuing compilation
Pragma Breakpoint: static else, before expanding the dependent template
(ctdb) continuing compilation
Pragma Breakpoint: done T!0
(ctdb) Backtrace
frame 0 dshell/extra-files/pragmabreakpoint/pragmabreakpoint.d(3): scope: T (struct)
frame 1 dshell/extra-files/pragmabreakpoint/pragmabreakpoint.d(10): scope: T!0 (template instance)
frame 2 : scope: __anonymous (ScopeDsymbol)
frame 3 dshell/extra-files/pragmabreakpoint/pragmabreakpoint.d: scope: pragmabreakpoint (module)
frame 4 : scope: __anonymous (ScopeDsymbol)
(ctdb) Members of scope T!0
pragmabreakpoint.pragmabreakpoint.T!0
(ctdb) continuing compilation
Pragma Breakpoint: main
(ctdb) continuing compilation`;

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
    const output = (cast(string) outputPipe.readEnd.byChunk(4096).join())
        .splitLines
        .map!strip
        .map!(l => l.replace("\\", "/")) //paths are different on different platforms.  TODO, use module name instead?
        .filter!(l => l.length > 0)
        .join("\n");
    assert(output == expectedOutput,  "actual output:\n" ~ output ~ "\nexpected output:\n" ~ expectedOutput);
    return 0;
}
