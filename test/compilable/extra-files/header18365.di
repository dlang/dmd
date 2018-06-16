struct FullCaseEntry
{
	dchar[3] seq;
	ubyte n;
	ubyte size;
	ubyte entry_len;
	auto const pure nothrow @nogc @property @trusted value() return
	{
		return seq[0..entry_len];
	}
}
