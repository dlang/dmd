/*
TEST_OUTPUT:
---
fail_compilation/fail7177.d(21): Error: X1 only defines length for one dimension
fail_compilation/fail7177.d(21): Error: X1 only defines length for one dimension
fail_compilation/fail7177.d(28): Error: X2 only defines length for one dimension
fail_compilation/fail7177.d(28): Error: X2 only defines length for one dimension
fail_compilation/fail7177.d(35): Error: X3 only defines opDollar for one dimension
fail_compilation/fail7177.d(35): Error: X3 only defines opDollar for one dimension
fail_compilation/fail7177.d(42): Error: function fail7177.main.X4.opDollar is not callable because it is annotated with @disable
---
*/

void main()
{
    struct X1
    {
        @property size_t length() const { return 1; }
        void opIndex(size_t i, size_t j) {}
    }
    X1.init[$, $];

    struct X2
    {
        @property size_t length()() const { return 1; }
        void opIndex(size_t i, size_t j) {}
    }
    X2.init[$, $];

    struct X3
    {
        @property size_t opDollar() const { return 1; }
        void opIndex(size_t i, size_t j) {}
    }
    X3.init[$, $];

    struct X4
    {
        @disable size_t opDollar();
        int opIndex(size_t i) { return 1; }
    }
    X4.init[$ - 1];
}
