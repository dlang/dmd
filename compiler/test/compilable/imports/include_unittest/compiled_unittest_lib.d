module lib.with_.unittests;

void someFunction()
{
	// This should trigger because this is a root module
	pragma(msg, "Compiling lib.with_.unittests.someFunction");
}

unittest
{
	// This should trigger because this is a root module
	pragma(msg, "Compiling lib.with_.unittests.unittest");
}
