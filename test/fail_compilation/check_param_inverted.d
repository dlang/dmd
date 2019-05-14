/* TEST_OUTPUT:
---
fail_compilation/check_param_inverted.d(36): Error: function `check_param_inverted.fun(int[] a, int b)` is not callable using argument types `(int, void[])`
fail_compilation/check_param_inverted.d(36):        cannot pass argument `0` of type `int` to parameter `int[] a`
fail_compilation/check_param_inverted.d(36):        Could the order of arguments be inverted ?
fail_compilation/check_param_inverted.d(37): Error: function `check_param_inverted.lol(int[] a, int b, int c)` is not callable using argument types `(int, void[])`
fail_compilation/check_param_inverted.d(37):        cannot pass argument `0` of type `int` to parameter `int[] a`
fail_compilation/check_param_inverted.d(38): Error: template `check_param_inverted.cat` cannot deduce function from argument types `!()(int, char[][])`, candidates are:
fail_compilation/check_param_inverted.d(26):        `check_param_inverted.cat(T : char[][], U : int)(T a, U b)`
fail_compilation/check_param_inverted.d(38):        Could the order of arguments be inverted ?
fail_compilation/check_param_inverted.d(39): Error: function `check_param_inverted.fun(int[] a, int b)` is not callable using argument types `(int, void[])`
fail_compilation/check_param_inverted.d(39):        cannot pass argument `0` of type `int` to parameter `int[] a`
fail_compilation/check_param_inverted.d(39):        Could the order of arguments be inverted ?
fail_compilation/check_param_inverted.d(40): Error: function `check_param_inverted.Box.fill(int[] a, int b)` is not callable using argument types `(int, void[])`
fail_compilation/check_param_inverted.d(40):        cannot pass argument `0` of type `int` to parameter `int[] a`
fail_compilation/check_param_inverted.d(40):        Could the order of arguments be inverted ?
fail_compilation/check_param_inverted.d(41): Error: function `check_param_inverted.Box.close(int[] a, int b)` is not callable using argument types `(int, void[])`
fail_compilation/check_param_inverted.d(41):        cannot pass argument `0` of type `int` to parameter `int[] a`
fail_compilation/check_param_inverted.d(41):        Could the order of arguments be inverted ?
---
*/
module check_param_inverted;

void fun(int[] a, int b){}
void lol(int[] a, int b, int c){}
void cat(T : char[][], U : int)(T a, U b){}

struct Box
{
    void fill(int[] a, int b) {}
    static void close(int[] a, int b) {}
}

void main()
{
    fun(0, []);
    lol(0, []);
    cat(0, new char[][](0));
    0.fun([]);
    (new Box).fill(0, []);
    Box.close(0, []);
}
