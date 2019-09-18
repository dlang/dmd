// REQUIRED_ARGS: -preview=rvalueattribute

static if (0) // test the parser only
{
@rvalue ref int func(@rvalue ref int);
void func(in @rvalue ref int);

auto f = function @rvalue ref () {};
auto f = delegate @rvalue ref () {};
auto f = @rvalue ref () {};
auto f = function @rvalue ref () => 0;
auto f = delegate @rvalue ref () => 0;
auto f = @rvalue ref () => 0;

auto c = cast(@rvalue ref) 0;
}
