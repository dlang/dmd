module test11081;

T ifThrown2(E : Throwable, T)(T delegate(E) errorHandler)
{
	return errorHandler();
}

static if (__traits(compiles, ifThrown2!Exception(e => 0))) //This will only work with a fix that was not yet pulled
{
}

static if (__traits(compiles, ifThrown2!Exception(e => 0))) //This will only work with a fix that was not yet pulled
{
}

void main()
{
}
