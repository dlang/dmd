/+
Useful to test performance stats based on flags, eg:

gtime -v dmd -unittest -version=StdUnittest -version=import_std -main -o- -i=std test/runnable/imports/import_world.d

TODO: also add blocks with:
`version (import_core)`
etc
+/

version (import_std)
{
    // adapted from rdmd importWorld
    import std.stdio, std.algorithm, std.array, std.ascii, std.base64,
        std.bigint, std.bitmanip, std.compiler, std.complex, std.concurrency,
        std.container, std.conv, std.csv, std.datetime, std.demangle,
        std.digest.md, std.encoding, std.exception, std.file, std.format,
        std.functional, std.getopt, std.json, std.math, std.mathspecial,
        std.mmfile, std.numeric, std.outbuffer, std.parallelism, std.path,
        std.process, std.random, std.range, std.regex, std.signals, std.socket,
        std.stdint, std.stdio, std.string, std.windows.syserror, std.system,
        std.traits, std.typecons, std.typetuple, std.uni, std.uri, std.utf,
        std.variant, std.xml, std.zip, std.zlib;
}

