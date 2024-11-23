/* TEST_OUTPUT:
---
fail_compilation/test17451.d(30): Error: undefined identifier `allocator`
                try allocator;
                    ^
fail_compilation/test17451.d(31): Error: `false` has no effect
                catch (Exception e) false; // should never happen
                                    ^
fail_compilation/test17451.d(38): Error: variable `test17451.HashMap!(ThreadSlot).HashMap.__lambda_L38_C20.v` - size of type `ThreadSlot` is invalid
        static if ({ Value v; }) {}
                           ^
fail_compilation/test17451.d(52): Error: template instance `test17451.HashMap!(ThreadSlot)` error instantiating
        HashMap!ThreadSlot m_waiters;
        ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=17451

interface ManualEvent {}

interface EventDriver {
        ManualEvent createManualEvent() ;
}

struct ArraySet(Key)
{
        ~this()
    {
                try allocator;
                catch (Exception e) false; // should never happen
        }
}

struct HashMap(TValue)
{
        alias Value = TValue;
        static if ({ Value v; }) {}
}

struct Task {}

class Libevent2Driver : EventDriver {
        Libevent2ManualEvent createManualEvent() {}
}

struct ThreadSlot {
        ArraySet!Task tasks;
}

class Libevent2ManualEvent : ManualEvent {
        HashMap!ThreadSlot m_waiters;
}
