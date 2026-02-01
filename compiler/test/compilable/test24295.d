// REQUIRED_ARGS: -betterC

int f()
{
   int[] overlaps = new int[1];
   overlaps[0] = 3;
   return overlaps[0];
}

enum res_f = f();
static assert(res_f == 3);
