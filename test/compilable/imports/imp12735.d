module imports.imp12735;

mixin template Mix12735()
{
    import imports.imp1b;   // bar function
}
mixin Mix12735!();

void check12735()
{
    string str = "abc";
    assert(bar() == 2);  // accessible
}
