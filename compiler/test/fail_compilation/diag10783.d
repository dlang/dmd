/*
TEST_OUTPUT:
---
fail_compilation/diag10783.d(14): Error: no property `type` for `event` of type `diag10783.Event`
fail_compilation/diag10783.d(9):        struct `Event` defined here
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
