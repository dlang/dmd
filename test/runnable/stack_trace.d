// REQUIRED_ARGS: -g
// EXTRA_SOURCES: imports/stacktrace1.d imports/stacktrace2.d

import stacktrace2;

/*
  Error looks like:
  core.exception.AssertError@runnable/imports/stacktrace2.d(7): Assertion failure
  ----------------
  ??:? _d_assertp [0x103c21831]
  runnable/imports/stacktrace2.d:7 _ZN3Foo3barEv [0x10d17a874]
  runnable/stack_trace.d:19 _Dmain [0x103c14821]
 */

void main ()
{
    try {
        scope o = new Foo;
        o.bar();
    }  catch (Exception e) {
        import std.algorithm : canFind;
        immutable str = e.toString();
        assert(!str.canFind("stacktrace1.d"));
        assert( str.canFind("stacktrace2.d:7 _ZN3Foo3barEv"));
    }
}
