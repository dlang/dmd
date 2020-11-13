//https://issues.dlang.org/show_bug.cgi?id=21378
version(D_Coverage)
    enum do_inline = true;
else
    enum do_inline = false;


pragma(inline, do_inline)
void stuff(){}

void stuff2()
{
    pragma(inline, do_inline);
}
