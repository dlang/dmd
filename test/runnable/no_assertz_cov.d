// REQUIRED_ARGS: -cov=100
module no_assertz_cov;

void v()
{
    assert(0);
}

void main()
{
    int a = 42;
    if (!a)
        assert(0);
    switch (a)
    {
    case 42: break;
    case 99: {{assert(0);}}
    default: assert(0);
    }
}

