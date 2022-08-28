MODEL=32
DMD=..\..\windows\bin\dmd
DFLAGS=-m$(MODEL)

EXAMPLES = hello d2html dhry pi sieve wc wc2 \
	winsamp dserver$(MODEL) mydll$(MODEL) htmlget listener

auto-tester-test:
	echo "Windows builds have been disabled"

all: $(EXAMPLES)
	echo done

d2html:
	$(DMD) d2html $(DFLAGS)
	.\d2html.exe d2html.d

dhry:
	$(DMD) dhry $(DFLAGS)
	.\dhry.exe

hello:
	$(DMD) hello $(DFLAGS)
	.\hello.exe

htmlget:
	$(DMD) htmlget $(DFLAGS)
	.\htmlget.exe www.dlang.org/index.html

listener:
	$(DMD) listener $(DFLAGS)
	# .\listener.exe

pi:
	$(DMD) pi $(DFLAGS)
	.\pi.exe 1000

sieve:
	$(DMD) sieve $(DFLAGS)
	.\sieve.exe

wc:
	$(DMD) wc $(DFLAGS)
	.\wc.exe wc.d

wc2:
	$(DMD) wc2 $(DFLAGS)
	.\wc2.exe wc2.d

winsamp:
	$(DMD) winsamp $(DFLAGS) gdi32.lib user32.lib winsamp.def
	# .\winsamp.exe

# COM client/server example
# dclient will fail unless run with administrator rights
dserver32:
	$(DMD) dserver.d chello.d $(DFLAGS) dserver.def advapi32.lib ole32.lib user32.lib
	$(DMD) dclient $(DFLAGS) ole32.lib uuid.lib
	.\dclient.exe

dserver64 dserver32mscoff:
	$(DMD) dserver.d chello.d $(DFLAGS) -L/DLL dserver64.def advapi32.lib ole32.lib user32.lib
	$(DMD) dclient $(DFLAGS) ole32.lib uuid.lib
	.\dclient.exe

mydll32:
	$(DMD) $(DFLAGS) -ofmydll.dll -L/IMPLIB mydll\mydll.d mydll\dll.d mydll\mydll.def
	$(DMD) $(DFLAGS) -ofdlltest.exe mydll\test.d mydll\mydll.di mydll.lib
	.\dlltest.exe

mydll64 mydll32mscoff:
	$(DMD) $(DFLAGS) -ofmydll.dll mydll\mydll.d mydll\dll.d -L/DLL
	$(DMD) $(DFLAGS) -ofdlltest.exe mydll\test.d mydll\mydll.di mydll.lib
	.\dlltest.exe

clean:
	clean.bat
