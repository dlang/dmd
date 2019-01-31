// REQUIRED_ARGS: -mixin=${RESULTS_DIR}/compilable/test19636.mixin

const string s = "int fun(int x)\r\n{ return x; }\r\n";

mixin(s);

int main()
{
    int a = fun(1);
    return 0;
}
