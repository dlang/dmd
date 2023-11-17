module core.internal.event_tests;

import core.sync.event : Event;
import core.time;

// Test single-thread (non-shared) use.
@nogc nothrow unittest
{
    // auto-reset, initial state false
    Event ev1 = Event(false, false);
    assert(!ev1.wait(1.dur!"msecs"));
    ev1.setIfInitialized();
    assert(ev1.wait());
    assert(!ev1.wait(1.dur!"msecs"));

    // manual-reset, initial state true
    Event ev2 = Event(true, true);
    assert(ev2.wait());
    assert(ev2.wait());
    ev2.reset();
    assert(!ev2.wait(1.dur!"msecs"));
}

unittest
{
    import core.thread, core.atomic;

    scope event      = new Event(true, false);
    int  numThreads = 10;
    shared int numRunning = 0;

    void testFn()
    {
        event.wait(8.dur!"seconds"); // timeout below limit for druntime test_runner
        numRunning.atomicOp!"+="(1);
    }

    auto group = new ThreadGroup;

    for (int i = 0; i < numThreads; ++i)
        group.create(&testFn);

    auto start = MonoTime.currTime;
    assert(numRunning == 0);

    event.setIfInitialized();
    group.joinAll();

    assert(numRunning == numThreads);

    assert(MonoTime.currTime - start < 5.dur!"seconds");
}
