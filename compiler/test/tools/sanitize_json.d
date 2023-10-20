import std.exception : assumeUnique;
import std.conv : text;
import std.range : take, chain, drop;
import std.string : startsWith, replace;
import std.format : formattedWrite, format;
import std.uni : asCapitalized;
import std.json;
import std.getopt;
import std.file : readText;
import std.path : dirName;
import std.stdio;

bool keepDeco = false;
enum rootDir = __FILE_FULL_PATH__.dirName.dirName;

// JSONType has been introduced in 2.082
static if (__VERSION__ <= 2081) {
    alias JSONType = JSON_TYPE;
    alias JSON_TYPE_NULL = JSON_TYPE.NULL;
    alias JSON_TYPE_OBJECT = JSON_TYPE.OBJECT;
    alias JSON_TYPE_STRING = JSON_TYPE.STRING;
    alias JSON_TYPE_ARRAY = JSON_TYPE.ARRAY;
    alias JSON_TYPE_INTEGER = JSON_TYPE.INTEGER;
    alias JSON_TYPE_UINTEGER = JSON_TYPE.UINTEGER;
} else {
    alias JSON_TYPE_NULL = JSONType.null_;
    alias JSON_TYPE_OBJECT = JSONType.object;
    alias JSON_TYPE_STRING = JSONType.string;
    alias JSON_TYPE_ARRAY = JSONType.array;
    alias JSON_TYPE_INTEGER = JSONType.integer;
    alias JSON_TYPE_UINTEGER = JSONType.uinteger;
}

void usage()
{
    writeln("Usage: santize_json [--keep-deco] <input-json> [<output-json>]");
}
// This module may be imported from d_do_test
version (NoMain) {} else
int main(string[] args)
{
    getopt(args,
        "keep-deco", &keepDeco);
    args = args[1 .. $];
    if (args.length == 0)
    {
        usage();
        return 1;
    }
    string inFilename = args[0];
    File outFile;
    if(args.length == 1)
    {
        outFile = stdout;
    }
    else if(args.length == 2)
    {
        outFile = File(args[1], "w");
    }
    else
    {
        writeln("Error: too many command line arguments");
        return 1;
    }

    auto json = readText(inFilename);
    sanitize(json);

    outFile.writeln(json);
    return 0;
}

string capitalize(string s)
{
    return text(s.take(1).asCapitalized.chain(s.drop(1)));
}

void sanitize(ref string text)
{
    auto json = parseJSON(text);
    sanitize(json);
    text = json.toJSON(true, JSONOptions.doNotEscapeSlashes);
}

void sanitize(JSONValue root)
{
    if (root.type == JSON_TYPE_ARRAY)
    {
        sanitizeSyntaxNode(root);
    }
    else
    {
        assert(root.type == JSON_TYPE_OBJECT);
        auto rootObject = root.object;
        static foreach (name; ["compilerInfo", "buildInfo", "semantics"])
        {{
            auto node = rootObject.get(name, JSONValue.init);
            if (node.type != JSON_TYPE_NULL)
            {
                mixin("sanitize" ~ name.capitalize ~ "(node.object);");
            }
        }}
        {
            auto modules = rootObject.get("modules", JSONValue.init);
            if (modules.type != JSON_TYPE_NULL)
            {
                sanitizeSyntaxNode(modules);
            }
        }
    }
}

void removeString(JSONValue* value)
{
    assert(value.type == JSON_TYPE_STRING|| value.type == JSON_TYPE_NULL);
    *value = JSONValue("VALUE_REMOVED_FOR_TEST");
}
void removeNumber(JSONValue* value)
{
    assert(value.type == JSON_TYPE_INTEGER || value.type == JSON_TYPE_UINTEGER);
    *value = JSONValue(0);
}
void removeStringIfExists(JSONValue* value)
{
    if (value !is null)
        removeString(value);
}
void removeArray(JSONValue* value)
{
    assert(value.type == JSON_TYPE_ARRAY);
    *value = JSONValue([JSONValue("VALUES_REMOVED_FOR_TEST")]);
}

void sanitizeCompilerInfo(ref JSONValue[string] buildInfo)
{
    removeString(&buildInfo["version"]);
    removeNumber(&buildInfo["__VERSION__"]);
    removeString(&buildInfo["vendor"]);
    removeNumber(&buildInfo["size_t"]);
    removeArray(&buildInfo["platforms"]);
    removeArray(&buildInfo["architectures"]);
    removeArray(&buildInfo["predefinedVersions"]);
}
void sanitizeBuildInfo(ref JSONValue[string] buildInfo)
{
    removeString(&buildInfo["cwd"]);
    removeString(&buildInfo["argv0"]);
    removeString(&buildInfo["config"]);
    removeString(&buildInfo["libName"]);
    {
        auto importPaths = buildInfo["importPaths"].array;
        foreach(ref path; importPaths)
        {
            path = JSONValue(normalizeFile(path.str));
        }
    }
    removeArray(&buildInfo["objectFiles"]);
    removeArray(&buildInfo["libraryFiles"]);
    removeString(&buildInfo["mapFile"]);
}
void sanitizeSyntaxNode(ref JSONValue value)
{
    if (value.type == JSON_TYPE_ARRAY)
    {
        foreach (ref element; value.array)
        {
            sanitizeSyntaxNode(element);
        }
    }
    else if(value.type == JSON_TYPE_OBJECT)
    {
        foreach (name; value.object.byKey)
        {
            if (name == "file")
                removeString(&value.object[name]);
            else if (name == "offset")
                removeNumber(&value.object[name]);
            else if (!keepDeco && name == "deco")
                removeString(&value.object[name]);
            else
                sanitizeSyntaxNode(value.object[name]);
        }
    }
}

string getOptionalString(ref JSONValue[string] obj, string name)
{
    auto node = obj.get(name, JSONValue.init);
    if (node.type == JSON_TYPE_NULL)
        return null;
    assert(node.type == JSON_TYPE_STRING, format("got %s where STRING was expected", node.type));
    return node.str;
}

void sanitizeSemantics(ref JSONValue[string] semantics)
{
    import std.array : appender;

    auto modulesArrayPtr = &semantics["modules"].array();
    auto newModules = appender!(JSONValue[])();
    foreach (ref semanticModuleNode; *modulesArrayPtr)
    {
        auto semanticModule = semanticModuleNode.object();
        auto moduleName = semanticModule.getOptionalString("name");
        if(moduleName.startsWith("std.", "core.", "etc.", "rt.") || moduleName == "object")
        {
           // remove druntime/phobos modules since they can change for each
           // platform
           continue;
        }
        auto fileNode = &semanticModule["file"];
        *fileNode = JSONValue(normalizeFile(fileNode.str));
        newModules.put(JSONValue(semanticModule));
    }
    *modulesArrayPtr = newModules.data;
}

auto normalizeFile(string file)
{
    import std.path : buildNormalizedPath, relativePath;
    file = file.buildNormalizedPath.relativePath(rootDir);
    version(Windows)
        return file.replace("\\", "/");
    return file;
}
