import core.sys.posix.pthread;
import core.memory;

extern(C)
void* entry_point(void*)
{
    // try collecting - GC must ignore this call because this thread
    // is not registered in runtime
    GC.collect();
    return null;
}

void main()
{
    // allocate some garbage
    auto x = new int[1000];

    pthread_t thread;
    auto status = pthread_create(&thread, null, &entry_point, null);
    assert(status == 0);
    pthread_join(thread, null);
}
