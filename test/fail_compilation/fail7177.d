/*
TEST_OUTPUT:
---
fail_compilation/fail7177.d(21): Error: X1 only defines opDollar for one dimension
fail_compilation/fail7177.d(21): Error: X1 only defines opDollar for one dimension
fail_compilation/fail7177.d(28): Error: function fail7177.main.X2.opDollar is not callable because it is annotated with @disable
fail_compilation/fail7177.d(35): Error: multi-dimensional opDollar for X3 is not found
fail_compilation/fail7177.d(35): Error: multi-dimensional opDollar for X3 is not found
fail_compilation/fail7177.d(42): Error: multi-dimensional opDollar for X4 is not found
fail_compilation/fail7177.d(42): Error: multi-dimensional opDollar for X4 is not found
---
*/

void main()
{
    struct X1
    {
        @property size_t opDollar() const { return 1; }
        void opIndex(size_t i, size_t j) {}
    }
    X1.init[$, $];

    struct X2
    {
        @disable size_t opDollar();
        int opIndex(size_t i) { return 1; }
    }
    X2.init[$ - 1];

    struct X3
    {
        @property size_t length() const { return 1; }
        void opIndex(size_t i, size_t j) {}
    }
    X3.init[$, $];

    struct X4
    {
        @property size_t length()() const { return 1; }
        void opIndex(size_t i, size_t j) {}
    }
    X4.init[$, $];

}

size_t opDollar(R)(R r) { return r.length; }
