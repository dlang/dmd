/* REQUIRED_ARGS: -m64
TEST_OUTPUT:
---
compilable/b16976.d(73): Deprecation: foreach: loop index implicitly converted from `size_t` to `int`
    foreach(int i, v; dyn) { }
    ^
compilable/b16976.d(74): Deprecation: foreach: loop index implicitly converted from `size_t` to `int`
    foreach_reverse(int i, v; dyn) { }
    ^
compilable/b16976.d(75): Deprecation: foreach: loop index implicitly converted from `size_t` to `char`
    foreach(char i, v; dyn) { }
    ^
compilable/b16976.d(76): Deprecation: foreach: loop index implicitly converted from `size_t` to `char`
    foreach_reverse(char i, v; dyn) { }
    ^
compilable/b16976.d(81): Deprecation: foreach: loop index implicitly converted from `size_t` to `int`
    foreach(int i, v; str) { }
    ^
compilable/b16976.d(82): Deprecation: foreach: loop index implicitly converted from `size_t` to `int`
    foreach_reverse(int i, v; str) { }
    ^
compilable/b16976.d(83): Deprecation: foreach: loop index implicitly converted from `size_t` to `char`
    foreach(char i, v; str) { }
    ^
compilable/b16976.d(84): Deprecation: foreach: loop index implicitly converted from `size_t` to `char`
    foreach_reverse(char i, v; str) { }
    ^
compilable/b16976.d(90): Deprecation: foreach: loop index implicitly converted from `size_t` to `int`
    foreach(int i, dchar v; dyn) { }
    ^
compilable/b16976.d(91): Deprecation: foreach: loop index implicitly converted from `size_t` to `int`
    foreach_reverse(int i, dchar v; dyn) { }
    ^
compilable/b16976.d(92): Deprecation: foreach: loop index implicitly converted from `size_t` to `char`
    foreach(char i, dchar v; dyn) { }
    ^
compilable/b16976.d(93): Deprecation: foreach: loop index implicitly converted from `size_t` to `char`
    foreach_reverse(char i, dchar v; dyn) { }
    ^
compilable/b16976.d(98): Deprecation: foreach: loop index implicitly converted from `size_t` to `int`
    foreach(int i, dchar v; str) { }
    ^
compilable/b16976.d(99): Deprecation: foreach: loop index implicitly converted from `size_t` to `int`
    foreach_reverse(int i, dchar v; str) { }
    ^
compilable/b16976.d(100): Deprecation: foreach: loop index implicitly converted from `size_t` to `char`
    foreach(char i, dchar v; str) { }
    ^
compilable/b16976.d(101): Deprecation: foreach: loop index implicitly converted from `size_t` to `char`
    foreach_reverse(char i, dchar v; str) { }
    ^
compilable/b16976.d(102): Deprecation: foreach: loop index implicitly converted from `size_t` to `int`
    foreach(int i, dchar v; chr) { }
    ^
compilable/b16976.d(103): Deprecation: foreach: loop index implicitly converted from `size_t` to `int`
    foreach_reverse(int i, dchar v; chr) { }
    ^
compilable/b16976.d(104): Deprecation: foreach: loop index implicitly converted from `size_t` to `char`
    foreach(char i, dchar v; chr) { }
    ^
compilable/b16976.d(105): Deprecation: foreach: loop index implicitly converted from `size_t` to `char`
    foreach_reverse(char i, dchar v; chr) { }
    ^
---
*/
void main()
{
    int[]  dyn = [1,2,3,4,5];
    int[5] sta = [1,2,3,4,5];
    char[]  str = ['1','2','3','4','5'];
    char[5] chr = ['1','2','3','4','5'];

    foreach(int i, v; dyn) { }
    foreach_reverse(int i, v; dyn) { }
    foreach(char i, v; dyn) { }
    foreach_reverse(char i, v; dyn) { }
    foreach(int i, v; sta) { }
    foreach_reverse(int i, v; sta) { }
    foreach(char i, v; sta) { }
    foreach_reverse(char i, v; sta) { }
    foreach(int i, v; str) { }
    foreach_reverse(int i, v; str) { }
    foreach(char i, v; str) { }
    foreach_reverse(char i, v; str) { }
    foreach(int i, v; chr) { }
    foreach_reverse(int i, v; chr) { }
    foreach(char i, v; chr) { }
    foreach_reverse(char i, v; chr) { }

    foreach(int i, dchar v; dyn) { }
    foreach_reverse(int i, dchar v; dyn) { }
    foreach(char i, dchar v; dyn) { }
    foreach_reverse(char i, dchar v; dyn) { }
    foreach(int i, dchar v; sta) { }
    foreach_reverse(int i, dchar v; sta) { }
    foreach(char i, dchar v; sta) { }
    foreach_reverse(char i, dchar v; sta) { }
    foreach(int i, dchar v; str) { }
    foreach_reverse(int i, dchar v; str) { }
    foreach(char i, dchar v; str) { }
    foreach_reverse(char i, dchar v; str) { }
    foreach(int i, dchar v; chr) { }
    foreach_reverse(int i, dchar v; chr) { }
    foreach(char i, dchar v; chr) { }
    foreach_reverse(char i, dchar v; chr) { }
}
