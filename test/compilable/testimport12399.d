import imports.imp12399stream : Stream;
static import imports.imp12399stream;

import imports.imp12399stdio;

void main()
{
    File f;
    static assert(is(typeof(f) == struct));

    imports.imp12399stream.Stream s;
    static assert(is(typeof(s) == class));

    imports.imp12399stream.File fs;
    static assert(is(typeof(fs) == class));
}
