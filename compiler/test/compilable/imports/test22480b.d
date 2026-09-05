module immports.test22480b;

auto parseAA()
{
	bool[string] aa;
	aa["key"] = true;
	assert("key" in aa);
	assert(aa["key"]);
	assert(aa.length == 1);
	assert(aa == aa);
	aa.rehash();
	return true;
}
