/* TEST_OUTPUT:
---
fail_compilation/diag16976.d(108): Error: foreach: key cannot be of non-integral type `float`
    foreach(float f, i; dyn) {}
    ^
fail_compilation/diag16976.d(109): Error: foreach: key cannot be of non-integral type `float`
    foreach(float f, i; sta) {}
    ^
fail_compilation/diag16976.d(110): Error: foreach: key cannot be of non-integral type `float`
    foreach(float f, i; str) {}
    ^
fail_compilation/diag16976.d(111): Error: foreach: key cannot be of non-integral type `float`
    foreach(float f, i; chr) {}
    ^
fail_compilation/diag16976.d(112): Error: foreach: key cannot be of non-integral type `float`
    foreach(float f, dchar i; dyn) {}
    ^
fail_compilation/diag16976.d(113): Error: foreach: key cannot be of non-integral type `float`
    foreach(float f, dchar i; sta) {}
    ^
fail_compilation/diag16976.d(114): Error: foreach: key cannot be of non-integral type `float`
    foreach(float f, dchar i; str) {}
    ^
fail_compilation/diag16976.d(115): Error: foreach: key cannot be of non-integral type `float`
    foreach(float f, dchar i; chr) {}
    ^
fail_compilation/diag16976.d(116): Error: foreach: key cannot be of non-integral type `float`
    foreach_reverse(float f, i; dyn) {}
    ^
fail_compilation/diag16976.d(117): Error: foreach: key cannot be of non-integral type `float`
    foreach_reverse(float f, i; sta) {}
    ^
fail_compilation/diag16976.d(118): Error: foreach: key cannot be of non-integral type `float`
    foreach_reverse(float f, i; str) {}
    ^
fail_compilation/diag16976.d(119): Error: foreach: key cannot be of non-integral type `float`
    foreach_reverse(float f, i; chr) {}
    ^
fail_compilation/diag16976.d(120): Error: foreach: key cannot be of non-integral type `float`
    foreach_reverse(float f, dchar i; dyn) {}
    ^
fail_compilation/diag16976.d(121): Error: foreach: key cannot be of non-integral type `float`
    foreach_reverse(float f, dchar i; sta) {}
    ^
fail_compilation/diag16976.d(122): Error: foreach: key cannot be of non-integral type `float`
    foreach_reverse(float f, dchar i; str) {}
    ^
fail_compilation/diag16976.d(123): Error: foreach: key cannot be of non-integral type `float`
    foreach_reverse(float f, dchar i; chr) {}
    ^
fail_compilation/diag16976.d(129): Error: foreach: key cannot be of non-integral type `float`
    static foreach(float f, i; idyn) {}
    ^
fail_compilation/diag16976.d(130): Error: foreach: key cannot be of non-integral type `float`
    static foreach(float f, i; ista) {}
                               ^
fail_compilation/diag16976.d(131): Error: foreach: key cannot be of non-integral type `float`
    static foreach(float f, i; istr) {}
    ^
fail_compilation/diag16976.d(132): Error: foreach: key cannot be of non-integral type `float`
    static foreach(float f, i; ichr) {}
                               ^
fail_compilation/diag16976.d(133): Error: foreach: key cannot be of non-integral type `float`
    static foreach(float f, dchar i; idyn) {}
    ^
fail_compilation/diag16976.d(134): Error: foreach: key cannot be of non-integral type `float`
    static foreach(float f, dchar i; ista) {}
                                     ^
fail_compilation/diag16976.d(135): Error: foreach: key cannot be of non-integral type `float`
    static foreach(float f, dchar i; istr) {}
    ^
fail_compilation/diag16976.d(136): Error: foreach: key cannot be of non-integral type `float`
    static foreach(float f, dchar i; ichr) {}
                                     ^
fail_compilation/diag16976.d(137): Error: foreach: key cannot be of non-integral type `float`
    static foreach_reverse(float f, i; idyn) {}
    ^
fail_compilation/diag16976.d(138): Error: foreach: key cannot be of non-integral type `float`
    static foreach_reverse(float f, i; ista) {}
                                       ^
fail_compilation/diag16976.d(139): Error: foreach: key cannot be of non-integral type `float`
    static foreach_reverse(float f, i; istr) {}
    ^
fail_compilation/diag16976.d(140): Error: foreach: key cannot be of non-integral type `float`
    static foreach_reverse(float f, i; ichr) {}
                                       ^
fail_compilation/diag16976.d(141): Error: foreach: key cannot be of non-integral type `float`
    static foreach_reverse(float f, dchar i; idyn) {}
    ^
fail_compilation/diag16976.d(142): Error: foreach: key cannot be of non-integral type `float`
    static foreach_reverse(float f, dchar i; ista) {}
                                             ^
fail_compilation/diag16976.d(143): Error: foreach: key cannot be of non-integral type `float`
    static foreach_reverse(float f, dchar i; istr) {}
    ^
fail_compilation/diag16976.d(144): Error: foreach: key cannot be of non-integral type `float`
    static foreach_reverse(float f, dchar i; ichr) {}
                                             ^
---
*/

void main()
{
    int[]  dyn = [1,2,3,4,5];
    int[5] sta = [1,2,3,4,5];
    char[]  str = ['1','2','3','4','5'];
    char[5] chr = ['1','2','3','4','5'];
    foreach(float f, i; dyn) {}
    foreach(float f, i; sta) {}
    foreach(float f, i; str) {}
    foreach(float f, i; chr) {}
    foreach(float f, dchar i; dyn) {}
    foreach(float f, dchar i; sta) {}
    foreach(float f, dchar i; str) {}
    foreach(float f, dchar i; chr) {}
    foreach_reverse(float f, i; dyn) {}
    foreach_reverse(float f, i; sta) {}
    foreach_reverse(float f, i; str) {}
    foreach_reverse(float f, i; chr) {}
    foreach_reverse(float f, dchar i; dyn) {}
    foreach_reverse(float f, dchar i; sta) {}
    foreach_reverse(float f, dchar i; str) {}
    foreach_reverse(float f, dchar i; chr) {}

    immutable int[]  idyn = [1,2,3,4,5];
    immutable int[5] ista = [1,2,3,4,5];
    immutable char[]  istr = ['1','2','3','4','5'];
    immutable char[5] ichr = ['1','2','3','4','5'];
    static foreach(float f, i; idyn) {}
    static foreach(float f, i; ista) {}
    static foreach(float f, i; istr) {}
    static foreach(float f, i; ichr) {}
    static foreach(float f, dchar i; idyn) {}
    static foreach(float f, dchar i; ista) {}
    static foreach(float f, dchar i; istr) {}
    static foreach(float f, dchar i; ichr) {}
    static foreach_reverse(float f, i; idyn) {}
    static foreach_reverse(float f, i; ista) {}
    static foreach_reverse(float f, i; istr) {}
    static foreach_reverse(float f, i; ichr) {}
    static foreach_reverse(float f, dchar i; idyn) {}
    static foreach_reverse(float f, dchar i; ista) {}
    static foreach_reverse(float f, dchar i; istr) {}
    static foreach_reverse(float f, dchar i; ichr) {}
}
