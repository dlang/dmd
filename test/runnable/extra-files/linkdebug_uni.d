module linkdebug_uni;

import linkdebug_range;

struct GcPolicy {}

alias CodepointSet = InversionList!();

struct InversionList(SP = GcPolicy)
{
@trusted:
    size_t addInterval(int a, int b, size_t hint = 0)
    {
        auto data = new uint[](0);        // affects to the number of missimg symbol
        auto range = assumeSorted(data[]);  // NG
        //SortedRange!(uint[], "a < b") SR; // OK
        return 1;
    }
}
