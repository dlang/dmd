// PERMUTE_ARGS: -inline
// REQUIRED_ARGS: -rb
module test9896;

import imports.test9896a;

void main()
{
    static assert(square(2) == 4);
    assert(square(2) == 4);
}
