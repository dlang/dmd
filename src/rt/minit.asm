;_ minit.asm
;  Module initialization support.
;
;  Copyright: Copyright Digital Mars 2000 - 2010.
;  License:   $(WEB http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
;  Authors:   Walter Bright
;
;           Copyright Digital Mars 2000 - 2010.
;  Distributed under the Boost Software License, Version 1.0.
;     (See accompanying file LICENSE or copy at
;           http://www.boost.org/LICENSE_1_0.txt)
;
include macros.asm

ifdef _WIN32
  DATAGRP      EQU     FLAT
else
  DATAGRP      EQU     DGROUP
endif

; Provide a default resolution for weak extern records, no way in C
; to define an omf symbol with a specific value
public __nullext
__nullext   equ 0

    extrn   __moduleinfo_array:near

; This bit of assembler is needed because, from C or D, one cannot
; specify the names of data segments. Why does this matter?
; All the ModuleInfo pointers are placed into a segment named 'FM'.
; The order in which they are placed in 'FM' is arbitrarily up to the linker.
; In order to walk all the pointers, we need to be able to find the
; beginning and the end of the 'FM' segment.
; This is done by bracketing the 'FM' segment with two other, empty,
; segments named 'FMB' and 'FME'. Since this module is the only one that
; ever refers to 'FMB' and 'FME', we get to control the order in which
; these segments appear relative to 'FM' by using a GROUP statement.
; So, we have in memory:
;   FMB empty segment
;   FM  contains all the pointers
;   FME empty segment
; and finding the limits of FM is as easy as taking the address of FMB
; and the address of FME.

; These segments bracket FM, which contains the list of ModuleInfo pointers
FMB     segment dword use32 public 'DATA'
FMB     ends
FM      segment dword use32 public 'DATA'
FM      ends
FME     segment dword use32 public 'DATA'
FME     ends

; This leaves room in the _fatexit() list for _moduleDtor()
XOB     segment dword use32 public 'BSS'
XOB     ends
XO      segment dword use32 public 'BSS'
    dd  ?
XO      ends
XOE     segment dword use32 public 'BSS'
XOE     ends

DGROUP         group   FMB,FM,FME

    begcode minit

; extern (C) void _minit();
; Converts array of ModuleInfo pointers to a D dynamic array of them,
; so they can be accessed via D.
; Result is written to:
; extern (C) ModuleInfo[] _moduleinfo_array;

    public  __minit
__minit proc    near
    mov EDX,offset DATAGRP:FMB
    mov EAX,offset DATAGRP:FME
    mov dword ptr __moduleinfo_array+4,EDX
    sub EAX,EDX         ; size in bytes of FM segment
    shr EAX,2           ; convert to array length
    mov dword ptr __moduleinfo_array,EAX
    ret
__minit endp

    endcode minit

    end
