module linkdebug;

void main()
{
    import linkdebug_uni;
    import linkdebug_range;

    // OK
    //SortedRangeX!(uint[], "a <= b") SR;

    CodepointSet set;
    set.addInterval(1, 2);

    // NG, order dependent.
    SortedRange!(uint[], "a <= b") SR;
}
