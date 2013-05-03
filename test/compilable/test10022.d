
// EXTRA_SOURCES: imports/package10022/package imports/package10022/a imports/package10022/b imports/package10022/c

import imports.package10022;

void main()
{
    funa();
    funb();
    static assert(!is(typeof(func())));
}
