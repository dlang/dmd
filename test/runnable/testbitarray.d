// PERMUTE_ARGS:

import std.bitmanip;

void main() {
        BitArray a;
        a.length = 5;
        foreach (ref bool b; a) {
                assert (b == 0);
                b = true;
        }
        foreach (bool b; a)
                assert (b == true); // FAILS, they're all 0
}


