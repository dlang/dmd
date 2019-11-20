// REQUIRED_ARGS: -preview=rvaluetype

static if (0) // test the parser only
{

@rvalue const T a;

@rvalue(T) a;
const(@rvalue(shared(int))) a;

__rvalue(T) a;

__rvalue(int) func(@rvalue int a) {}
@rvalue f = function @rvalue(@rvalue a) {};
__rvalue f = delegate @rvalue(__rvalue(T)[@rvalue(T)]) {};

void fun()
{
    foreach(@rvalue a, const b, __rvalue c; r)
    {
    }
}

struct S { @rvalue a = 0; }

auto a = cast(const shared @rvalue)a;
auto a = cast(__rvalue)a;

auto b = is(T == @rvalue);
auto b = is(T == __rvalue);

alias T = @rvalue(int) delegate();

}
