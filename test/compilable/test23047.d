/* REQUIRED_ARGS: -O
 */

// https://issues.dlang.org/show_bug.cgi?id=23047

import core.simd;

version (D_SIMD):

long2 _mm_srl_epi64 ()
{
    long2 r = void;
    r[0] = 1;
    return r;
}
