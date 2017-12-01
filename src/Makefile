# Includes the respective Makefile depending on the OS
# Have a look at either posix.mak, win32.mak or win64.mak for a list of available commands.

include ./osmodel.mak

ifeq (Windows_NT,$(OS))
    ifeq ($(findstring WOW64, $(shell uname)),WOW64)
	OS:=win64
	MODEL:=64
    else
	OS:=win32
	MODEL:=32
    endif
endif
ifeq (Win_32,$(OS))
    OS:=win32
    MODEL:=32
endif
ifeq (Win_64,$(OS))
    OS:=win64
    MODEL:=64
endif

ifeq ($(findstring win,$(OS)),win)
ifeq (Win_32,$(OS))
	include ./win32.mak
else
	include ./win64.mak
endif
else
	include ./posix.mak
endif
