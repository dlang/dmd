// REQUIRED_ARGS: -inline -O

real f(real r)
{
    return r - real.infinity;
}

void main()
{
    assert(f(real.infinity) != f(real.infinity));

    version (D_SIMD)
    {
        import core.simd;
        float4 v1 = float.infinity;
        float4 v2 = v1 - v1;
        static foreach (i; 0 .. 4)
            assert(v2[i] != v2[i]);
    }
}
