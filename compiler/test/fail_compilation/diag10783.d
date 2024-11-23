/*
TEST_OUTPUT:
---
fail_compilation/diag10783.d(21): Error: no property `type` for `event` of type `diag10783.Event`
    switch (event.type) with (En)
                 ^
fail_compilation/diag10783.d(16):        struct `Event` defined here
struct Event { }
^
fail_compilation/diag10783.d(21): Error: undefined identifier `En`
    switch (event.type) with (En)
                              ^
---
*/

struct Event { }

void main()
{
    Event event;
    switch (event.type) with (En)
    {
        default:
    }
}
