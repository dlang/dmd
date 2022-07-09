..\..\..\windows\bin\dmd -ofmydll.dll -L/IMPLIB mydll.d dll.d mydll.def
..\..\..\windows\bin\dmd test.d mydll.lib
