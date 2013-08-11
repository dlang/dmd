module imports.b4481;

import imports.a4481;

class Font
{
public:
    int charHeight(dchar c) { return 0; }
    int textHeight(in string text)
    {
        auto maxHeight = (dchar ch) { return charHeight(ch); };
        return reduce!(maxHeight)(text);
    }
}
