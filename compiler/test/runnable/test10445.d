/*
 */

import core.simd;

int main()
{
    version (D_SIMD)
    {
	{
	    auto m = ubyte16.max;
	    auto n = cast(ubyte16)ubyte.max;
	    assert(m.array == n.array);
	}

	{
	    auto m = ubyte16.min;
	    auto n = cast(ubyte16)ubyte.min;
	    assert(m.array == n.array);
	}

	{
	    auto m = float4.max;
	    auto n = cast(float4)float.max;
	    assert(m.array == n.array);
	}

	{
	    auto m = float4.min_normal;
	    auto n = cast(float4)float.min_normal;
	    assert(m.array == n.array);
	}

	{
	    auto m = float4.epsilon;
	    auto n = cast(float4)float.epsilon;
	    assert(m.array == n.array);
	}

	{
	    auto m = float4.infinity;
	    auto n = cast(float4)float.infinity;
	    assert(m.array == n.array);
	}

	{
	    auto m = float4.nan;
	    auto n = cast(float4)float.nan;
	    assert(m.array != n.array);
	}
    }
    return 0;
}
