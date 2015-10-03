import ae.utils.aa;

import std.exception;
import std.file;
import std.path;
import std.range.primitives;
import std.stdio;
import std.string;

void main()
{
	foreach (de; `..\..\src\core\sys\windows`.dirEntries("*.d", SpanMode.shallow))
	{
		scope(failure) stderr.writeln("Error with file: ", de.name);
		auto lines = de.name.readText.splitLines();
		if (lines.front != `/***********************************************************************\`)
			continue;
		lines.popFront();

		string[] description;
		OrderedMap!(string, string) fields;

		while (!lines.empty)
		{
			auto line = lines.front; lines.popFront();
			auto oline = line;
			scope(failure) stderr.writeln("Error with line: ", oline);

			if (line == `\***********************************************************************/`)
				break;

			enforce(line[0] == '*' && line[$-1] == '*');
			line = line[1..$-1].strip();

			if (line == de.baseName)
				{}
			else
			if (line == "Placed into public domain")
				fields["License"] = line;
			else
			if (line.startsWith("by "))
				fields["Authors"] = line[3..$];
			else
			if (line == "Windows API header module"
			 || line == "Translated from MinGW Windows headers"
			 || line.startsWith("Translated from MinGW API for MS-Windows ")
			)
				description ~= line;
			else
			if (!line.length)
				{} //f.writeln(" *");
			else
			{
				description ~= line;
				stderr.writeln("Unknown header line: " ~ line);
			}
		}

		auto f = File("temp.d", "wt");
		f.writeln("/**");
		foreach (line; description)
		{
			f.writeln(" * ", line);
			f.writeln(" *");
		}
		foreach (name, value; fields)
			f.writeln(" * ", name, ": ", value);
		f.writeln(" * Source: $(DRUNTIMESRC src/core/sys/windows/_", de.baseName, ")");
		f.writeln(" */");
		foreach (l; lines)
			f.writeln(l);
		f.close();
		"temp.d".rename("out/" ~ de.baseName);
		//break;
	}
}


/***********************************************************************\
*                              docobj.d                                 *
*                                                                       *
*                       Windows API header module                       *
*                                                                       *
*                 Translated from MinGW Windows headers                 *
*                                                                       *
*                       Placed into public domain                       *
\***********************************************************************/


/**
 * This module provides OS specific helper function for DLL support
 *
 * Copyright: Copyright Digital Mars 2010 - 2012.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Rainer Schuetze
 * Source: $(DRUNTIMESRC src/core/sys/windows/_dll.d)
 */

