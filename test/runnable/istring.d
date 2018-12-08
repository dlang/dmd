/*
PERMUTE_ARGS:
REQUIRED_ARGS: -transition=interpolate
*/
import std.conv : text;

static assert(i"$()".length == 0);
static assert(i"$(/* a comment!*/)".length == 0);
static assert(i"$(// another comment)".length == 0);
static assert(i"$(/+ yet another comment+/)".length == 0);

void main()
{
    int a = 42;
    assert("a is 42" == text(i"a is $(a)"));
    assert("a + 23 is 65" == text(i"a + 23 is $(a + 23)"));

    // test each type of string literal
    int b = 93;
    assert("42 + 93 = 135" == text(  i"$(a) + $(b) = $(a + b)"));  // double-quote
    assert("42 + 93 = 135" == text( ir"$(a) + $(b) = $(a + b)"));  // wysiwyg
    assert("42 + 93 = 135" == text(  i`$(a) + $(b) = $(a + b)`));  // wysiwyg (alt)
    assert("42 + 93 = 135" == text( iq{$(a) + $(b) = $(a + b)}));  // token
    assert("42 + 93 = 135" == text(iq"!$(a) + $(b) = $(a + b)!")); // delimited (char)
    assert("42 + 93 = 135\n" == text(iq"ABC
$(a) + $(b) = $(a + b)
ABC")); // delimited (heredoc)

    // Escaping double dollar
    assert("$" == i"$$"[0]);
    assert(" $ " == i" $$ "[0]);
    assert(" $(just raw string) " == i" $$(just raw string) "[0]);
    assert("Double dollar $$ becomes $" == text(  i"Double dollar $$$$ becomes $$"));  // double-quote
    assert("Double dollar $$ becomes $" == text( ir"Double dollar $$$$ becomes $$"));  // wysiwyg
    assert("Double dollar $$ becomes $" == text(  i`Double dollar $$$$ becomes $$`));  // wysiwyg (alt)
    assert("Double dollar $$ becomes $" == text( iq{Double dollar $$$$ becomes $$}));  // token
    assert("Double dollar $$ becomes $" == text(iq"!Double dollar $$$$ becomes $$!")); // delimited

    assert(928 == add(900, 28));
}

string funcCode(string attributes, string returnType, string name, string args, string body)
{
    return text(iq{
    $(attributes) $(returnType) $(name)($(args))
    {
        $(body)
    }
    });
}
mixin(funcCode("pragma(inline)", "int", "add", "int a, int b", "return a + b;"));

// Test interpolated strings with escape sequences
static assert(i" foo \n bar".length == 1);
static assert(i"foo \x0a bar".length == 1);
static assert(i"foo \xC2\xA2 bar".length == 1);
static assert(i"foo \u042f bar".length == 1);
static assert(i"foo \U00010f063 bar".length == 1);
static assert(i"foo \0 bar".length == 1);
static assert(i"foo \1 bar".length == 1);
static assert(i"foo \7 bar".length == 1);
static assert(i"foo \01 bar".length == 1);
static assert(i"foo \001 bar".length == 1);
static assert(i"foo \377 bar".length == 1);
static assert(i"foo &quot; bar".length == 1);

// Test string literals with odd newlines
static assert(i"
".length == 1);
// test carriage return
static assert(i"
".length == 1);
