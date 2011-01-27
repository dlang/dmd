
// Compiler implementation of the D programming language
// Copyright (c) 1999-2006 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef DMD_DOC_H
#define DMD_DOC_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

void escapeDdocString(OutBuffer *buf, unsigned start);

#endif
