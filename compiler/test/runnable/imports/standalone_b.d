module standalone_b;

import standalone_modctor;
import core.attribute : standalone;

immutable int* y;

__gshared int bCount;

@standalone @system shared static this()
{
    y = new int(2);
    ++bCount;
}
