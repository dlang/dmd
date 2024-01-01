LIBS:=glu32 odbc32 opengl32 rpcrt4 shell32 version wininet winspool

.PHONY: implibs

implibs: $(addsuffix .lib,$(LIBS))

%.lib: %.def
	implib $@ $<
