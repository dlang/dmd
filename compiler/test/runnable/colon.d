// REQUIRED_ARGS: -betterC

// this is an address miscalculation bug
// may not crash if the data segment has a different layout
// e.g. when pasted into with another file

struct S {
   int i;
}

__gshared S gs = S(1);
ref S get() => gs;

extern (C)
int main()
{
    (get().i ? get() : get()).i++;
    return 0;
}
