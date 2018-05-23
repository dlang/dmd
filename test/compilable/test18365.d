struct FullCaseEntry
{
	dchar[3] seq;
	auto return value()
	{
		return seq[0..2];
	}
}
