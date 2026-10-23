@"
// Test for Issue 22848
// Undefined reference to static function in unused mixin lambda

mixin template Main(alias mainFunction) {}

mixin Main!(
    ()
    {
        static bool pred(char c) => false;
        accept!pred;
    }
);

char accept(alias pred)() => pred(0);

void main()
{
}
"@
