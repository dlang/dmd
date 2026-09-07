/**
 * Cross-thread remote-free queue test for tgc.
 *
 * Run with: --DRT-gcopt=gc:tgc
 */
import core.atomic;
import core.memory;
import core.thread;

shared size_t remoteAddress;
shared bool freeQueued;
shared bool queueDrained;
shared bool lookupDone;

void ownerThread()
{
    auto owned = GC.malloc(128, GC.BlkAttr.NO_SCAN);
    assert(owned !is null);
    atomicStore(remoteAddress, cast(size_t) owned);

    while (!atomicLoad(freeQueued))
        Thread.yield();

    // Any owner allocation drains frees queued by foreign threads.
    auto trigger = GC.malloc(1, GC.BlkAttr.NO_SCAN);
    assert(trigger !is null);
    atomicStore(queueDrained, true);

    while (!atomicLoad(lookupDone))
        Thread.yield();
}

void main()
{
    auto owner = new Thread(&ownerThread);
    owner.start();

    size_t address;
    while (!address)
    {
        address = atomicLoad(remoteAddress);
        Thread.yield();
    }

    auto foreign = cast(void*) address;
    GC.free(foreign);
    atomicStore(freeQueued, true);

    while (!atomicLoad(queueDrained))
        Thread.yield();
    auto found = GC.addrOf(foreign);
    assert(found is null);
    atomicStore(lookupDone, true);
    owner.join();
}
