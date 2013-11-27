// PERMUTE_ARGS:

const int X15;
immutable int Y15;
const int Z15;

int foo15(int i)
{
    auto y = 1;
    switch (i)
    {
        case X15:
            y += 1;
            goto case;
        case 3:
            y += 2;
            break;
        case Y15:
            y += 20;
            goto case;
        case Z15:
            y += 10;
            break;
        default:
            y += 4;
            break;
    }
    return y;
}

static this()
{
    X15 = 4;
    Y15 = 4;
    Z15 = 5;
}

void main()
{
    auto i = foo15(3);
    assert(i == 3);
    i = foo15(4);
    assert(i == 4);
    i = foo15(7);
    assert(i == 5);
    i = foo15(5);
    assert(i == 11);
}
