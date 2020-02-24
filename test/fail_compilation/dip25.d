/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/dip25.d(13): Deprecation: returning `this.buffer[]` escapes a reference to parameter `this`, perhaps annotate with `return`
---
*/
struct Data
{
    char[256] buffer;
    @property const(char)[] filename() const pure nothrow
    {
        return buffer[];
    }
}

void main()
{
    Data d;
    const f = d.filename;
}
