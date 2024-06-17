import dshell;

int main()
{
	version (Windows)
	{
		auto cmd = "$DMD -m$MODEL -c $EXTRA_FILES" ~ SEP ~ "issue24111.c";
		run(cmd);

		import std.process: environment;
		environment.remove("INCLUDE");
		run(cmd);
	}
	return 0;
}
