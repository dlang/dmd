import std.algorithm.iteration;
import std.algorithm.searching;
import std.algorithm.sorting;
import std.array;
import std.conv;
import std.demangle;
import std.file;
import std.format;
import std.process;
import std.range;
import std.stdio;

import ae.sys.persistence;
import ae.utils.array;
import ae.utils.json;
import ae.utils.text;

int main()
{
	static struct Member
	{
		string file, name, kind;
		uint line;
	@JSONName("char")
		uint char_;

		string protection;
		string[] selective;
		string[] storageClass;
		string deco;
		string originalType;
		Member[] parameters;
		string init;
		Member[] members;
		string type;
		uint endline, endchar;
		uint offset = uint.max;
	@JSONName("default")
		string default_;
		string defaultDeco;
		string defaultValue;
		string base;
		string baseDeco;
		string specValue;
		string defaultAlias;
	@JSONName("in")
		Member* in_;
	@JSONName("out")
		Member* out_;
		string[] overrides;
		string[string] renamed;
		string[] interfaces;
	@JSONName("alias")
		string alias_;
	@JSONName("align")
		uint align_;
		string specAlias;
		string value;
		string constraint;
	}

	bool[string][string][2] sets;

	auto exclusions = PersistentStringSet("exclusions.txt");

	auto modules =
		"druntime.json".readText.jsonParse!(Member[]) ~
		"phobos.json"  .readText.jsonParse!(Member[]);
	foreach (m; modules)
	{
		if (!m.name.length || !(m.name.startsWith("core.") || m.name.startsWith("std.") || m.name.startsWith("etc.")) || m.name in exclusions)
			continue;
		int setIndex =
			(m.name.startsWith("core.sys.windows.")
		 && !m.name.split(".")[3].isOneOf("com", "dbghelp", "dll", "stacktrace", "stat", "threadaux", "winsock2"))
		 	? 0 : 1;

		foreach (d; m.members)
			if (!d.kind.isOneOf("import") && (m.name ~ "." ~ d.name) !in exclusions)
				sets[setIndex][d.name][m.name] = true;
	}

	auto o = File("duptests.d", "wb");

	bool[string][2] neededModules;
	foreach (name; sets[0].byKey)
		if (name in sets[1])
			foreach (set; sets)
				foreach (i, m; set[name].keys)
					neededModules[i][m] = true;

	foreach (set; neededModules)
	{
		foreach (name; set.keys.sort())
			o.writefln("import %s;", name);
		o.writeln();
	}

	foreach (name; sets[0].byKeyValue.array.sort!((a, b) => a.value.byKey.front < b.value.byKey.front).map!(pair => pair.key))
		if (name in sets[1])
		{
			o.writefln("// Duplicate symbol: %s (%-(%s, %) / %-(%s, %))", name, sets[0][name].byKey, sets[1][name].byKey);
			o.writefln("alias local_%s = %s;", name, name);
			o.writeln();
		}

	o.close();

	return spawnProcess(["dmd", "-I../../src", "-o-", "-d", "duptests.d"]).wait();
}
