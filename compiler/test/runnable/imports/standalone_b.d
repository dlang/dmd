module standalone_b;

import standalone_modctor;
import core.attribute : __standalone;

immutable int* y;

@__standalone @system shared static this()
{
    y = new int(2);
}
