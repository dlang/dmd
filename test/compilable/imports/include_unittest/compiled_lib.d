
unittest
{
	// This should trigger because this is a root module
	pragma(msg, "Compiling compiled_lib.unittests");
}

void someFunction()
{
	// This should trigger because this is a root module
	pragma(msg, "Compiling compiled_lib.someFunction");
}
