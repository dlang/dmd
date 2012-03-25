
# Little shell script to compile, link, and run all the samples.
# Use ..\bin\shell.exe to execute.

MARS=..\dmd
O=(|-inline) (|-release) (|-g) (|-O) (|-unittest)

$(MARS) -c mydll
$(MARS) mydll.obj ..\druntime\lib\gcstub.obj mydll.def -L/map
implib /noi /system mydll.lib mydll.dll
$(MARS) testmydll mydll.lib
testmydll
$(MARS) testmydll -version=DYNAMIC_LOAD
testmydll
del mydll.obj mydll.dll mydll.map mydll.lib
del testmydll.obj testmydll.exe testmydll.map

$(MARS) -g -d -ofmydll2.dll -version=use_patch mydll2.d dll2.d mydll2.def

implib /system mydll2.lib mydll2.dll

$(MARS) -g -d testmydll2.d mydll2.lib
testmydll2

$(MARS) -g -d -oftestdyn.exe -version=dynload testmydll2.d
testdyn

$(MARS) -g -d -ofteststat.exe testmydll2.d mydll2.d
teststat

del mydll2.obj mydll2.dll mydll2.map mydll2.lib
del testmydll2.obj testmydll2.exe testmydll2.map
del testdyn.exe testdyn.map
del teststat.exe teststat.map


