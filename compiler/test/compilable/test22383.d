struct T22383
{
    int a = 4;
    int b : 16;
    int c : 8;
    int d : 4;
    int e : 2;
    int f : 1;
    int g : 1;
    int h = 8;
}
static assert(T22383.init == T22383(4,0,0,0,0,0,0,8));
