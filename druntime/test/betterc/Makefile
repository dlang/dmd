TESTS:=test18828 test19416 test19421 test19561 test20088 test20613 test19924 test22336 test19933
include ../common.mak

$(OBJDIR)/%.done: extra_dflags += -betterC
$(OBJDIR)/%.done: extra_ldlibs.d =

# for the Windows MinGW CI job:
ifneq (,$(findstring -mscrtlib=msvcrt120,$(DFLAGS) $(LDFLAGS.d)))
# DFLAGS=-mscrtlib=msvcrt120 takes precedence over any command line flags, so
# specify vcruntime140.lib explicitly for using mingw with Universal CRT.
$(OBJDIR)/test19933$(DOTEXE): extra_ldflags.d = -L/NODEFAULTLIB:msvcrt120.lib
$(OBJDIR)/test19933$(DOTEXE): extra_ldlibs.d = -Lvcruntime140.lib -Llegacy_stdio_definitions.lib
endif
