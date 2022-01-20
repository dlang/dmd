// https://issues.dlang.org/show_bug.cgi?id=15467
// PERMUTE_ARGS:
// TRANSFORM_OUTPUT: remove_lines(.*)

void error()
{
	throw new Exception("msg");
}

void main()
{
	try
	{
		scope (failure)
		{
		}
		error();
	}
	catch (Exception) {} // was falsely eliminated
}
