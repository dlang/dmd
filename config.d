/+
dub.sdl:
    name "config"
    targetPath "generated/dub"
+/
/**
Generates the compiler version, the version printed with `dmd --version`.

Outputs a file with the generated version which is imported as a string literal
in the compiler source code.
*/
module config;

void main(const string[] args)
{
    import std.file : mkdirRecurse, readText;
    import std.path : buildPath;

    const outputDirectory = args[1];
    const versionFile = args[2];

    version (Posix)
        const sysConfigDirectory = args[3];

    mkdirRecurse(outputDirectory);
    const version_ = generateVersion(versionFile);

    updateIfChanged(buildPath(outputDirectory, "VERSION"), version_);

    version (Posix)
    {
        const path = buildPath(outputDirectory, "SYSCONFDIR.imp");
        updateIfChanged(path, sysConfigDirectory);
    }
}

/**
Generates the version for the compiler.

If anything goes wrong in the process the contents of the file
`versionFile` will be returned.

Params:
    versionFile = a file containing a version, used for backup if generating the
        version fails

Returns: the generated version, or the content of `versionFile`
*/
string generateVersion(const string versionFile)
{
    import std.process : execute;
    import std.file : readText;
    import std.path : dirName;
    import std.string : strip;

    enum workDir = __FILE_FULL_PATH__.dirName;
    const result = execute(["git", "-C", workDir, "describe", "--dirty"]);

    return result.status == 0 ? result.output.strip : versionFile.readText;
}

/**
Writes given the content to the given file.

The content will only be written to the file specified in `path` if that file
doesn't exist, or the content of the existing file is different from the given
content.

This makes sure the timestamp of the file is only updated when the
content has changed. This will avoid rebuilding when the content hasn't changed.

Params:
    path = the path to the file to write the content to
    content = the content to write to the file
*/
void updateIfChanged(const string path, const string content)
{
    import std.file : exists, readText, write;

    const existingContent = path.exists ? path.readText : "";

    if (content != existingContent)
        write(path, content);
}
