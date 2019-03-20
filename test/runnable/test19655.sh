cd runnable/test19655

dmd -c test19655a.d
dmd -c test19655b.d
dmd -c test19655c.d
dmd -c test19655d.d
dmd -c test19655e.d
dmd -c test19655f.d
dmd -c test19655g.d

dmd -oftest19655 test19655a.o test19655b.o test19655c.o \
    test19655d.o test19655e.o test19655f.o test19655g.o

./test19655
