module lib.ignores.unittests;

pragma(msg, "Found module with skipped unittests");

unittest
{
    // Shouldn't be parsed because we're in a non-root module
	static assert(false, "Semantic on unittest in non-root module!");
}

void someFunction()
{
    // This shouldn't be evaluated, no semantic for the body in non-root modules
	static assert(false, "Semantic on function body in non-root module!");
}
