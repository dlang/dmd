/*
TEST_OUTPUT:
---
fail_compilation/b6226.d(13): Error: cannot implicitly convert expression `400000000` of type `int` to `ubyte`
fail_compilation/b6226.d(19): Error: cannot implicitly convert expression `200` of type `int` to `byte`
---
*/

void main() {
    ubyte c;
    switch (c) {
        case 'a': break;
        case 400000000: break;
        default:
    }
    byte x;
    switch (x) {
        case 10: break;
        case 200: break;
        default:
    }
}
