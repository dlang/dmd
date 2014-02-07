// PERMUTE_ARGS: -inline
// REQUIRED_ARGS: -rb -Iimports
// EXTRA_SOURCES: extra-files/test9896b.d
module test9896a;

/** Ensure .di files are not compiled. */
import test9896b;

void main()
{
    assert(square(2) == 4);
}
