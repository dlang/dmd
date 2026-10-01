// https://github.com/dlang/dmd/issues/22054

import core.sys.windows.winbase;
import core.sys.windows.winnt;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.memory;

// comment to use core.stdc.stdio.printf
void printf(const(char)* fmt, ...) {}

extern(Windows)
void workerFiberFunc(LPVOID param)
{
    LPVOID mainFiber = cast(LPVOID)param;

    printf("Worker Fiber: Started, stack = %p\n", &mainFiber);

    // scanning stack ranges must not crash here
    GC.collect();

    // Yield control back to the main fiber
    SwitchToFiber(mainFiber);

    // Execution resumes here when switched back to
    printf("Worker Fiber: Resumed\n");

    GC.collect();

    SwitchToFiber(mainFiber);
}

void main()
{
    // Convert the current thread to a fiber
    // This must be done before creating any other fibers
    LPVOID mainFiber = ConvertThreadToFiber(null);
    mainFiber || assert(false, "Failed to convert thread to fiber");
    printf("Main Thread converted to Fiber: %p\n", mainFiber);

    // run multiple times to hopefully get a variety of fiber stack adresses
    for (int i = 0; i < 10; i++)
    {
        // Create a new fiber
        LPVOID workerFiber = CreateFiber(0, &workerFiberFunc, mainFiber);
        workerFiber || assert(false, "Failed to create fiber");
        printf("Worker Fiber created: %p\n", workerFiber);

        // Switch execution to the worker fiber
        printf("Main Fiber: Switching to worker...\n");
        SwitchToFiber(workerFiber);

        // Execution resumes here after worker yields back
        printf("Main Fiber: Resumed from worker\n");

        GC.collect();

        // Resume worker fiber
        SwitchToFiber(workerFiber);

        // Clean up
        DeleteFiber(workerFiber);
        printf("Worker Fiber deleted\n");
    }

    // Optional: Convert back to a normal thread if no longer using fibers
    ConvertFiberToThread();
}
