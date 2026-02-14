// https://github.com/dlang/dmd/issues/22501

struct A {
    ubyte[16] bytes;

    enum something = A(cast(ubyte[16])[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]);

    @nogc nothrow pure
    bool isB() const {
        return bytes[0..12] == something.bytes[0..12];
    }
}
