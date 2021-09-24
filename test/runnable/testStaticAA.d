import core.internal.hash;

// thanks wikipedia
ushort Fletcher16( const(char)[] data ) pure nothrow
{
   ushort sum1 = cast(ushort)data.length;
   ushort sum2 = cast(ushort)data.length;

   foreach(b;data)
   {
      sum1 = (sum1 + b) % 255;
      sum2 = (sum2 + sum1) % 255;
   }

   return cast(ushort)((sum2 << 8) | sum1);
}

uint Fletcher32_16( const(ushort)[] data ) pure nothrow
{
   ushort sum1 = cast(ushort)data.length;
   ushort sum2 = cast(ushort)data.length;
   foreach(u;data)
   {
      sum1 = (sum1 + u) % 511;
      sum2 = (sum2 + sum1) % 511;
   }

   return (sum2 << 16) | sum1;
}

/// hopefully this is order depdendent
size_t check(const(string)[] s) pure nothrow
{
    size_t result = s.length;
    ushort[] sums = new ushort[](s.length);
    foreach(i, s_;s)
    {
        sums[i] = Fletcher16(s_);
    }
    return Fletcher32_16(sums);
}

enum aaLit = q{ ["abc":"v",  "ab":"vv", "c" : "vvv", "d" : "vvvv"] };

static immutable ctAA = mixin(aaLit);
enum CTcheckDiffCT = () { return check(ctAA.keys) - check(ctAA.values); } ();

void main()
{
    auto rtAA = mixin(aaLit);
    auto checkDiffCT = check(ctAA.keys) - check(ctAA.values);
    auto checkDiffRT = check(rtAA.keys) - check(rtAA.values);


    assert(checkDiffCT == checkDiffRT,
        "Error: order of iteration differs between compile-time and run-time. " ~
        "This indicates that the hash-table algorithms diverged. Check that " ~
        "`_d_assocarrayliteralTX` in `druntime/src/rt/aaA.d` and " ~
        "`computeBucketOrder` in `dmd/src/dmd/aa.d` " ~
        "are equivalent algorithmically."
    );
}
