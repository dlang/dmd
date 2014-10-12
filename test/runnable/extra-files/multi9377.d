import core.stdc.stdio;

import mul9377a, mul9377b;

int main()
{
    printf("main\n");
    abc();
    def!().mem();
    pragma(msg, def!().mem.mangleof);
    return 0;
}

