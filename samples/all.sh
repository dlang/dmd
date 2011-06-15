
# Little shell script to compile, link, and run all the samples.
# Use \dmd\bin\shell.exe to execute.

DMD=\dmd\bin\dmd
DFLAGS=

$(DMD) hello $(DFLAGS)
hello
del hello.obj hello.exe hello.map

$(DMD) sieve $(DFLAGS)
sieve

$(DMD) pi $(DFLAGS)
pi 1000

$(DMD) dhry $(DFLAGS)
dhry

$(DMD) wc $(DFLAGS)
wc wc.d
-wc foo

$(DMD) wc2 $(DFLAGS)
wc2 wc2.d
del wc2.obj wc2.exe

$(DMD) hello2.html $(DFLAGS)
hello2
del hello2.obj hello2.exe

# COM client/server example

$(DMD) -c dserver -release $(DFLAGS)
$(DMD) -c chello $(DFLAGS)
$(DMD) dserver.obj chello.obj uuid.lib ole32.lib advapi32.lib kernel32.lib user32.lib dserver.def -L/map
$(DMD) dclient $(DFLAGS) ole32.lib uuid.lib

