module runnable;

/*
verify that semantic is not modified by changing
final switch(bool) to if...else...
*/

bool test_final_switch_bool1(bool a)
{
    final switch(a == true)
    {
        case true: a = false; a = true; return true;
        case false: a = true; a = false; return false;
    }
}

bool test_final_switch_bool2(bool a)
{
    final switch(!a)
    {
        case false: return true;
        case true: return false;
    }
}

bool test_final_switch_bool3(ubyte a)
{
    final switch(a != 0)
    {
        case 0: return true;
        case 1: return false;
    }
}

int test_final_switch_bool4(bool a)
{
    int result;
    final switch(a)
    {
        case true: result = 1; break;
        case false: result = 2; break;
    }
    return result;
}

int test_final_switch_bool5(bool a)
{
    int result;
    L0:
    for(auto i = 0; i < 10; i++)
    {
        final switch(a)
        {
            case false: ++result; break L0;
            case true: --result; break;
        }
    }
    return result;
}

bool test_final_switch_bool6(bool a)
{
    int b = a;
    final switch(!cast(bool) b)
    {
        case false: return false;
        case true: return true;
    }
}

void main()
{
    assert(test_final_switch_bool1(true));
    assert(!test_final_switch_bool1(false));

    assert(test_final_switch_bool2(true));
    assert(!test_final_switch_bool2(false));

    assert(!test_final_switch_bool3(true));
    assert(test_final_switch_bool3(false));

    assert(test_final_switch_bool4(false) == 2);
    assert(test_final_switch_bool4(true) == 1);

    assert(test_final_switch_bool5(false) == 1);
    assert(test_final_switch_bool5(true) < 0);

    assert(test_final_switch_bool6(false));
    assert(!test_final_switch_bool6(true));
}
