// REQUIRED_ARGS: -O

import core.stdc.math;

int screenNum()
{
    return 1;
}

void XTranslateCoordinates(int*) {}

void processNextEvent()
{
    int rx;
    XTranslateCoordinates(&rx);

    float scale = screenNum();
    int fx = cast(int) ceill(rx / cast(double) scale);
    int fw = cast(int) ceil(cast(double) scale);
}
