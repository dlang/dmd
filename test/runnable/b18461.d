// REQUIRED_ARGS: -O -inline -release
import core.bitop;

void main()
{
    size_t test_val = 0b0001_0000;

    if(bt(&test_val, 4) == 0)
        assert(false);
} 
