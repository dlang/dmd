import core.exception;
import core.thread;
import core.internal.thread : isSingleThreaded;

__gshared bool caught;

void main()
{
    if(isSingleThreaded)
        return;

    filterThreadThrowableHandler = (ref Throwable t) {
        if (auto t2 = cast(AssertError) t)
        {
            if (t2.message != "Hey!")
                return;
        }
        else
            return;

        caught = true;
        t = null;
    };

    Thread t = new Thread(&entry);
    t.start();
    t.join();

    assert(caught);
}

void entry()
{
    throw new AssertError("Hey!");
}
