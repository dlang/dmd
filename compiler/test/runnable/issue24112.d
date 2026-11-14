/*
REQUIRED_ARGS: -mcpu=native
PERMUTE_ARGS: -O -inline -release
*/

// https://claude.ai/artifact/3MjVK4cPNdTnNAWnnLH8Qe

uint f(uint x) { return x / 0xFFFF_FFFF; }

void main()
{
    assert(f(0xFFFF_FFFF) == 1);
}
