/*
EXTRA_SOURCES: imports/A16a.d
RUN_OUTPUT:
---
class AA16
class B16
---
*/

import std.stdio;

class AA16
{
  protected:
    this()
    {
        printf("class AA16\n");
    }
}
