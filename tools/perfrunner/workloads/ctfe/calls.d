// CTFE workload: function calls and returns, with nothing else going on.
int fib(int n)
{
    return n < 2 ? n : fib(n - 1) + fib(n - 2);
}

// The baseline evaluates a trivial input, so that both compiles do the same
// semantic analysis and differ only in the interpreting.
version (Baseline)
    enum result = fib(1);
else
    enum result = fib(26);
