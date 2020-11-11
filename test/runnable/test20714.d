// https://issues.dlang.org/show_bug.cgi?id=20714

struct Blitter
{
    int payload;
    this(this){}
}

struct Adder
{
    Blitter blitter;
    this(int payload) {this.blitter.payload = payload;}
    this(ref Adder rhs) {this.blitter.payload = rhs.blitter.payload + 1;}
}

void main()
{
    Adder piece1 = 1;
    auto piece2 = piece1;

    assert(piece2.blitter.payload == 2);
}
