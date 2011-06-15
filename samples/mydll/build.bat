..\..\..\bin\dmd -ofmydll.dll mydll2.d dll.d mydll.def
implib/system mydll.lib mydll.dll
..\..\..\bin\dmd test.d mydll.lib
