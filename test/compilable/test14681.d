// REQUIRED_ARGS: -J:hello=world -J:x= "-J:string=some thing"

static assert(import(":hello") == "world");
static assert(import(":x") == "");
static assert(import(":string") == "some thing");

void main()
{
}
