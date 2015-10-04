import std.algorithm.searching;
import std.array;
import std.demangle;
import std.file;
import std.format;
import std.process;
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

	auto exclusions = PersistentStringSet("exclusions.txt");

	foreach (model; ["32", "64"])
	{
		auto fn = "wintest" ~ model ~ ".d";
		File o = File(fn, "wb");
		o.writeln("import std.format : format;");

		auto fnB = "wintest" ~ model ~ "b.d";
		File b = File(fnB, "wb");

		void typeCheck(string name, string typeA, string typeB)
		{
			o.writefln("\tstatic if(!is(%s == %s)) pragma(msg, \"%%s(%%d): Error: type of %s is:\\n%%s\\nbut should be:\\n%%s\\n\".format(__FILE__, __LINE__, %s.stringof, %s.stringof));",
				typeA, typeB, name, typeA, typeB);
		}

		auto modules = ("druntime" ~ model ~ ".json").readText.jsonParse!(Member[]);
		foreach (m; modules)
		{
			if (m.name != "core.sys.windows.windows")
				continue;

			o.writefln("struct test_%s", m.name.replace(".", "_"));
			o.writeln("{");
			o.writefln("\tstatic import %s;", m.name);
			b.writefln("\timport %s;", m.name);

			void handleMembers(string[] prefix, Member[] members)
			{
				foreach (d; members)
				{
					scope(failure) stderr.writefln("Error processing member %s:", d.name);
					auto qname = (prefix ~ d.name).join(".");
					auto lname = qname.replace(".", "_");
					o.writefln("\talias %s = %s.%s;", lname, (m.name ~ prefix).join("."), d.name); // check existence
					b.writefln("\talias local_%s = %s;", lname, qname);
					if (qname in exclusions) o.writeln("/+");
					switch (d.kind)
					{
						case "function":
						{
							auto type = d.deco.demangleFunctionType().functionToFunctionPointerType();
							if (type.isValidDType())
							{
								o.writefln("\talias typeof_%s = %s;", lname, type);
								typeCheck(qname, "typeof(&%s)".format(lname), "typeof_%s".format(lname));
							}
							if (d.originalType)
							{
								o.writefln("\talias typeof_orig_%s = %s;", lname, d.originalType.functionToFunctionPointerType());
								typeCheck(qname, "typeof(&%s)".format(lname), "typeof_orig_%s".format(lname));
							}
							break;
						}
						case "enum member":
							o.writefln("\tstatic assert(%s == (%s));", lname, d.value);
							break;
						case "variable":
							o.writefln("\talias typeof_%s = %s;", lname, d.deco.demangleType());
							o.writefln("\tstatic assert(is(typeof(%s) == typeof_%s));", lname, lname);
							if (d.originalType)
							{
								o.writefln("\talias typeof_orig_%s = %s;", lname, d.originalType);
								o.writefln("\tstatic assert(is(typeof(%s) == typeof_orig_%s));", lname, lname);
							}
							break;
						case "alias":
							o.writefln("\talias aliasof_%s = %s;", lname, d.deco.demangleType());
							typeCheck(qname, lname, "aliasof_" ~ lname);
							break;
						case "struct":
						case "union":
						case "enum":
							// will descend to d.members below
							break;
						default:
							stderr.writeln("Unknown kind: ", d.kind);
							break;
					}

					if (d.offset != uint.max)
						o.writefln("\tstatic assert(%s.offsetof == %d);", lname, d.offset);
					if (qname in exclusions) o.writeln("+/");

					handleMembers(prefix ~ d.name, d.members);
				}
			}

			handleMembers([], m.members);

			o.writeln("}");
			o.writeln("");
		}

		o.close();
		b.close();

		if (spawnProcess(["dmd", "-m" ~ model, "-I../../src", "-o-", fn, fnB]).wait() != 0)
			return 1;
	}
	return 0;
}

/// nothrow @nogc extern (Windows) BOOL(LPCSTR lpPathName)
/// -- to --
/// nothrow @nogc extern (Windows) BOOL function(LPCSTR lpPathName)
string functionToFunctionPointerType(string type)
{
	if (type.contains(" @trusted"))
		type = type.replace(" @trusted", "") ~ " @trusted";

	int parens;
	foreach_reverse (i, char c; type)
		if (c == ')')
			parens++;
		else
		if (c == '(')
		{
			parens--;
			if (!parens)
				return type[0..i] ~ " function" ~ type[i..$];
		}
	assert(false, "Not a function type: " ~ type);
}

string demangleType(string mangledType)
{
	auto result = demangle("_D1x" ~ mangledType)[0..$-2];
	if (result.endsWith("*") && result.canFind(" function("))
		result = result[0..$-1]; // https://issues.dlang.org/show_bug.cgi?id=15143
	return result;
}

string demangleFunctionType(string mangledType)
{
	auto placeholder = "dftPlaceholder";
	return "_D%s%s%s"
		.format(placeholder.length, placeholder, mangledType)
		.demangle()
		.replace(" " ~ placeholder, "")
	;
}

/// Filter types unrepresentable in D grammar
bool isValidDType(string type)
{
	if (type.contains("* function"))
		return false; // function returning function pointer

	int parenLevel;
	foreach (i, c; type)
	{
		if (c == '(')
			parenLevel++;
		else
		if (c == ')')
			parenLevel++;
		else
		if (parenLevel && type[i..$].startsWith("extern ("))
			return false;
	}

	return true;
}
