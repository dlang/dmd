// argufile.d ----------------------------------------------------

public:

import core.vararg;
import std.stdio;
import std.format;
import std.utf;

dstring formatstring(TypeInfo[] arguments, void *argptr) 
{

	dstring message = null; 

	void putc(dchar c)
	{
		message ~= c; 
	}


	std.format.doFormat(&putc, arguments, argptr);

	
	return message; 
}

string arguments(...) // turns a bunch of arguments into a formatted char[] string
{
	return std.utf.toUTF8(formatstring(_arguments, _argptr));
}

void useargs(...)
{
	string crashage = arguments("why is 8 scared of 7? because", 7,8,9); 
	
	//printf("%.*s\n", crashage); 
	writefln(crashage); 
}
