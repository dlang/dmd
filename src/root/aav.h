
// Copyright (c) 2010-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

typedef void* Value;
typedef void* Key;

struct AA;

size_t _aaLen(AA* aa);
Value* _aaGet(AA** aa, Key key);
Value _aaGetRvalue(AA* aa, Key key);
void _aaRehash(AA** paa);

