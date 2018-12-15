
/* Compiler implementation of the D programming language
 * Copyright (C) 1999-2018 by The D Language Foundation, All Rights Reserved
 * written by Dave Fladebo
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/dlang/dmd/blob/master/src/dmd/hdrgen.h
 */

#pragma once

#include "globals.h"
#include "dsymbol.h"
#include "mtype.h"

class Module;

void genhdrfile(Module *m);
void moduleToBuffer(OutBuffer *buf, Module *m);

const char *parametersTypeToChars(ParameterList pl);
const char *stcToChars(StorageClass& stc);
void trustToBuffer(OutBuffer *buf, TRUST trust);
const char *trustToChars(TRUST trust);
const char *linkageToChars(LINK linkage);
void protectionToBuffer(OutBuffer *buf, Prot prot);
const char *protectionToChars(Prot::Kind kind);
