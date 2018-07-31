// PERMUTE_ARGS:

import imports.test66a;

alias int TOK;

enum
{
	TOKmax
};

struct Token
{
    static char[][TOKmax] tochars;
}

class Lexer
{
    Token token;
}

