int wrongcode3139(int x)
{
   switch(x) {
        case -6: .. case -4: return 3;
        default:
        return 4;
   }
}

static assert(wrongcode3139(-5)==3);

int testSwitch(int v)
{
    switch(v) 
    {
        case -5 : return 3;
        default : return 0;
    }
}

static assert(testSwitch(-5));
