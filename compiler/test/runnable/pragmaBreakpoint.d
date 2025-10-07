/+
TEST_OUTPUT:
---
Pragma Breakpoint: static else, before expanding the dependent template
Starting backtrace
compilable/pragmaBreakpoint.d(8): scope: T
compilable/pragmaBreakpoint.d(2): scope: T!3LU
compilable/pragmaBreakpoint.d(17): scope: __anonymous
compilable/pragmaBreakpoint.d: scope: pragmaBreakpoint
compilable/pragmaBreakpoint.d: scope: __anonymous
Pragma Breakpoint: static else, before expanding the dependent template
Starting backtrace
compilable/pragmaBreakpoint.d(8): scope: T
compilable/pragmaBreakpoint.d(2): scope: T!2LU
compilable/pragmaBreakpoint.d(9): scope: __anonymous
compilable/pragmaBreakpoint.d: scope: pragmaBreakpoint
compilable/pragmaBreakpoint.d: scope: __anonymous
Pragma Breakpoint: static else, before expanding the dependent template
Starting backtrace
compilable/pragmaBreakpoint.d(8): scope: T
compilable/pragmaBreakpoint.d(2): scope: T!1LU
compilable/pragmaBreakpoint.d(9): scope: __anonymous
compilable/pragmaBreakpoint.d: scope: pragmaBreakpoint
compilable/pragmaBreakpoint.d: scope: __anonymous
Pragma Breakpoint: done T!0LU
Starting backtrace
compilable/pragmaBreakpoint.d(6): scope: T
compilable/pragmaBreakpoint.d(2): scope: T!0LU
compilable/pragmaBreakpoint.d(9): scope: __anonymous
compilable/pragmaBreakpoint.d: scope: pragmaBreakpoint
compilable/pragmaBreakpoint.d: scope: __anonymous
Pragma Breakpoint: main
Starting backtrace
compilable/pragmaBreakpoint.d(21): scope: __anonymous
compilable/pragmaBreakpoint.d(15): scope: __anonymous
compilable/pragmaBreakpoint.d(15): scope: pragmaBreakpoint
compilable/pragmaBreakpoint.d: scope: __anonymous
+/
struct T(size_t x){
    static if(x == 0){
        enum done = true;
        //additional arguments are passed to pragma(msg), so they work the same way
        pragma(breakpoint, "done ", T);
    } else {
        pragma(breakpoint, "static else, before expanding the dependent template");
        T!(x - 1) nested;

    }
}


void main(){

    T!3 t3;
    static if(is(t3.done)){
        pragma(msg, "instantiated");
    }
    pragma(breakpoint, "main");
}
