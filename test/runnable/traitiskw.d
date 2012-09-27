void doAssert(S ...)()
{
    foreach (s; S)
        static assert(__traits(isKeyword, s));
}

void main()
{
    doAssert!("abstract", "alias", "align", "asm",
              "assert", "auto", "body", "bool",
              "break", "byte", "case", "cast",
              "catch", "char", "class", "const",
              "continue", "dchar", "debug", "default",
              "delegate", "deprecated", "do",
              "double", "else", "enum", "export",
              "extern", "false", "final", "finally",
              "float", "for", "foreach", "function",
              "goto", "if", "immutable", "import", "in",
              "inout", "int", "interface", "invariant",
              "is", "lazy", "long", "macro", "mixin",
              "module", "new", "nothrow", "null", "out",
              "override", "package", "pragma", "private",
              "protected", "public", "pure", "real",
              "ref", "return", "scope", "shared", "short",
              "static", "struct", "super", "switch",
              "synchronized", "template", "this", "throw",
              "true", "try", "typeid", "typeof", "ubyte",
              "uint", "ulong", "union", "unittest",
              "ushort", "version", "void", "wchar",
              "while", "with", "__FILE__", "__LINE__",
              "__gshared", "__traits", "__vector",

              // keywords to be deprecated
              "cdouble", "cfloat", "creal", "foreach_reverse",
              "idouble", "ifloat", "ireal", "typedef",
              "__thread",

              // internal keywords
              "__argTypes", "__parameters", "__overloadset",

              // keywords with an uncertain future
              "cent", "ucent")();
}
