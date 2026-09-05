/*
REQUIRED_ARGS: -profile=gc
RUN_OUTPUT:
---
bytes allocated, allocations, type, function, file:line
             64	              1	void[] profilegc17158.main runnable/profilegc17158.d:20
             32	              1	void[] profilegc17158.main runnable/profilegc17158.d:19
             32	              1	void[] profilegc17158.main runnable/profilegc17158.d:22
---
*/

import core.runtime;

void main()
{
    profilegc_setlogfilename("");

    void[] buffer;
    buffer.length = 20;
    buffer.length = 60;
    buffer.length = 10;
    buffer ~= "abcd".dup;
}
