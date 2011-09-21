// http://www.digitalmars.com/d/archives/digitalmars/D/bugs/2372.html
// allegedly crashes, but cannot reproduce

import core.stdc.stdio : printf;

void main()
{
 for (int t=0; t<33; t++)
  printf("sizeof bittest_T(0) %i\n", (bool[t]).sizeof );
}
