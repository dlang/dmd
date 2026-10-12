// CTFE workload: function calls and returns, with nothing else going on.
int fib(int n)
{
    return n < 2 ? n : fib(n - 1) + fib(n - 2);
}

version (Baseline) {} else
enum result = fib(26);
