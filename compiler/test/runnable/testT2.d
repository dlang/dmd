module dmd.compiler.test.runnable.testT2;

import std.array : appender;
import std.range.primitives : put;
import object : idup, dup;
import std.stdio : writeln;

@safe pure nothrow unittest
{
    debug { writeln("Starting unittest..."); }

    string s = "hello".idup;
    char[] a = "hello".dup;
    
    debug { writeln("Original string s: ", s); }
    debug { writeln("Original char array a: ", a); }

    auto appS = appender(s);
    auto appA = appender(a);

    debug { writeln("Appending 'w' to appS..."); }
    put(appS, 'w');
    debug { writeln("appS after put: ", appS[]); }

    debug { writeln("Appending 'w' to appA..."); }
    put(appA, 'w');
    debug { writeln("appA after put: ", appA[]); }

    debug { writeln("Appending 'a' to s..."); }
    s ~= 'a'; // Clobbers here?
    debug { writeln("s after ~=: ", s); }

    debug { writeln("Appending 'a' to a..."); }
    a ~= 'a'; // Clobbers here?
    debug { writeln("a after ~=: ", a); }

    debug { writeln("Final appS: ", appS[]); }
    debug { writeln("Final appA: ", appA[]); }

    assert(appS[] == "hellow");
    assert(appA[] == "hellow");

    debug { writeln("Unittest completed successfully!"); }
}
