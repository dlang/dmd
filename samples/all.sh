
# Little shell script to compile, link, and run all the samples.
# Use dmd\windows\bin\shell.exe to execute.

DMD=..\..\windows\bin\dmd
DFLAGS=
CLEAN=clean.bat



#~ $(DMD) chello $(DFLAGS) # which compilation flags?
#~ chello

$(DMD) d2html $(DFLAGS)
d2html d2html.d

$(DMD) dhry $(DFLAGS)
dhry

$(DMD) hello $(DFLAGS)
hello

#~ $(DMD) htmlget $(DFLAGS) # broken

#~ $(DMD) listener $(DFLAGS) # broken


$(DMD) pi $(DFLAGS)
pi 1000

$(DMD) sieve $(DFLAGS)
sieve

$(DMD) wc $(DFLAGS)
wc wc.d

$(DMD) wc2 $(DFLAGS)
wc2 wc2.d

$(DMD) winsamp gdi32.lib winsamp.def
winsamp

# COM client/server example
$(DMD) -c dserver -release $(DFLAGS)
$(DMD) -c chello $(DFLAGS)
$(DMD) dserver.obj chello.obj uuid.lib ole32.lib advapi32.lib kernel32.lib user32.lib dserver.def
#dclient will faill unless run with administrator rights
$(DMD) dclient $(DFLAGS) ole32.lib uuid.lib
dclient

$(CLEAN)
