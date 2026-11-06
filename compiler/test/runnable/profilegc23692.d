/*
REQUIRED_ARGS: -profile=gc
RUN_OUTPUT:
---
bytes allocated, allocations, type, function, file:line
       32000000	        1000000	void* profilegc23692.main runnable/profilegc23692.d:22
---
*/

import core.runtime;
import core.time;

void main()
{
    profilegc_setlogfilename("");

    MonoTime start = MonoTime.currTime;

    void* list;
    foreach (i; 0 .. 1000000)
    {
        auto array = new void*[1];
        array[0] = list;
        list = array.ptr;

        // The program should finish in less than a second, but allow
        // more for different hardware.
        // Previously it could take more than 600 seconds,
        // see https://github.com/dlang/dmd/issues/23692.
        assert(MonoTime.currTime - start < 30.seconds);
    }
}
