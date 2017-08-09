uint fn(uint a)
{
    final switch(a)
    {
        case 1 : {
            while(a < 20)
            {
                a++;
                if (a == 17) 
                    break;
            }
                return a;
        }
    }

    return 1;
}
pragma(msg, fn(20));
static assert(fn(1) == 17);
