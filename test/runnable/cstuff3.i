# 1 "runnable/extra-files/cstuff3.c"
# 1 "<built-in>"
# 1 "<command-line>"
# 31 "<command-line>"
# 1 "/usr/include/stdc-predef.h" 1 3 4
# 32 "<command-line>" 2
# 1 "runnable/extra-files/cstuff3.c"




# 1 "/usr/lib/gcc/x86_64-linux-gnu/10/include/stdbool.h" 1 3 4
# 6 "runnable/extra-files/cstuff3.c" 2

int printf(const char *, ...);
void exit(int);


# 10 "runnable/extra-files/cstuff3.c" 3 4
_Bool 
# 10 "runnable/extra-files/cstuff3.c"
    useBoolAnd(
# 10 "runnable/extra-files/cstuff3.c" 3 4
               _Bool 
# 10 "runnable/extra-files/cstuff3.c"
                    a, 
# 10 "runnable/extra-files/cstuff3.c" 3 4
                       _Bool 
# 10 "runnable/extra-files/cstuff3.c"
                            b)
{
 return a && b;
}


# 15 "runnable/extra-files/cstuff3.c" 3 4
_Bool 
# 15 "runnable/extra-files/cstuff3.c"
    useBoolOr(
# 15 "runnable/extra-files/cstuff3.c" 3 4
              _Bool 
# 15 "runnable/extra-files/cstuff3.c"
                   a, 
# 15 "runnable/extra-files/cstuff3.c" 3 4
                      _Bool 
# 15 "runnable/extra-files/cstuff3.c"
                           b)
{
 return a || b;
}


# 20 "runnable/extra-files/cstuff3.c" 3 4
_Bool 
# 20 "runnable/extra-files/cstuff3.c"
    useBoolXor(
# 20 "runnable/extra-files/cstuff3.c" 3 4
               _Bool 
# 20 "runnable/extra-files/cstuff3.c"
                    a, 
# 20 "runnable/extra-files/cstuff3.c" 3 4
                       _Bool 
# 20 "runnable/extra-files/cstuff3.c"
                            b)
{
 return a != b;
}



int main()
{
 
# 29 "runnable/extra-files/cstuff3.c" 3 4
_Bool 
# 29 "runnable/extra-files/cstuff3.c"
     baf, bat;
 bat = useBoolAnd( 
# 30 "runnable/extra-files/cstuff3.c" 3 4
                  1
# 30 "runnable/extra-files/cstuff3.c"
                      , 
# 30 "runnable/extra-files/cstuff3.c" 3 4
                        1 
# 30 "runnable/extra-files/cstuff3.c"
                             );
 if ( bat != 
# 31 "runnable/extra-files/cstuff3.c" 3 4
            1 
# 31 "runnable/extra-files/cstuff3.c"
                 ) { printf("error 1"); exit(1); }
 baf = useBoolAnd( 
# 32 "runnable/extra-files/cstuff3.c" 3 4
                  1
# 32 "runnable/extra-files/cstuff3.c"
                      , 
# 32 "runnable/extra-files/cstuff3.c" 3 4
                        0 
# 32 "runnable/extra-files/cstuff3.c"
                              );
 if ( baf == 
# 33 "runnable/extra-files/cstuff3.c" 3 4
            1 
# 33 "runnable/extra-files/cstuff3.c"
                 ) { printf("error 1a"); exit(1); }
 baf = useBoolAnd( 
# 34 "runnable/extra-files/cstuff3.c" 3 4
                  0
# 34 "runnable/extra-files/cstuff3.c"
                       , 
# 34 "runnable/extra-files/cstuff3.c" 3 4
                         1 
# 34 "runnable/extra-files/cstuff3.c"
                              );
 if ( baf == 
# 35 "runnable/extra-files/cstuff3.c" 3 4
            1 
# 35 "runnable/extra-files/cstuff3.c"
                 ) { printf("error 1b"); exit(1); }
 baf = useBoolAnd( 
# 36 "runnable/extra-files/cstuff3.c" 3 4
                  0
# 36 "runnable/extra-files/cstuff3.c"
                       , 
# 36 "runnable/extra-files/cstuff3.c" 3 4
                         0 
# 36 "runnable/extra-files/cstuff3.c"
                               );
 if ( baf == 
# 37 "runnable/extra-files/cstuff3.c" 3 4
            1 
# 37 "runnable/extra-files/cstuff3.c"
                 ) { printf("error 1c"); exit(1); }

 
# 39 "runnable/extra-files/cstuff3.c" 3 4
_Bool 
# 39 "runnable/extra-files/cstuff3.c"
     bbf, bbt;
 bbt = useBoolOr( 
# 40 "runnable/extra-files/cstuff3.c" 3 4
                 1
# 40 "runnable/extra-files/cstuff3.c"
                     , 
# 40 "runnable/extra-files/cstuff3.c" 3 4
                       1 
# 40 "runnable/extra-files/cstuff3.c"
                            );
 if ( bbt != 
# 41 "runnable/extra-files/cstuff3.c" 3 4
            1 
# 41 "runnable/extra-files/cstuff3.c"
                 ) { printf("error 2a"); exit(1); }
 bbt = useBoolOr( 
# 42 "runnable/extra-files/cstuff3.c" 3 4
                 1
# 42 "runnable/extra-files/cstuff3.c"
                     , 
# 42 "runnable/extra-files/cstuff3.c" 3 4
                       0 
# 42 "runnable/extra-files/cstuff3.c"
                             );
 if ( bbt != 
# 43 "runnable/extra-files/cstuff3.c" 3 4
            1 
# 43 "runnable/extra-files/cstuff3.c"
                 ) { printf("error 2b"); exit(1); }
 bbt = useBoolOr( 
# 44 "runnable/extra-files/cstuff3.c" 3 4
                 0
# 44 "runnable/extra-files/cstuff3.c"
                      , 
# 44 "runnable/extra-files/cstuff3.c" 3 4
                        1 
# 44 "runnable/extra-files/cstuff3.c"
                             );
 if ( bbt != 
# 45 "runnable/extra-files/cstuff3.c" 3 4
            1 
# 45 "runnable/extra-files/cstuff3.c"
                 ) { printf("error 2c"); exit(1); }
 bbf = useBoolOr( 
# 46 "runnable/extra-files/cstuff3.c" 3 4
                 0
# 46 "runnable/extra-files/cstuff3.c"
                      , 
# 46 "runnable/extra-files/cstuff3.c" 3 4
                        0 
# 46 "runnable/extra-files/cstuff3.c"
                              );
 if ( bbf != 
# 47 "runnable/extra-files/cstuff3.c" 3 4
            0 
# 47 "runnable/extra-files/cstuff3.c"
                  ) { printf("error 2"); exit(1); }

 
# 49 "runnable/extra-files/cstuff3.c" 3 4
_Bool 
# 49 "runnable/extra-files/cstuff3.c"
     bcf, bct;
 bct = useBoolXor( 
# 50 "runnable/extra-files/cstuff3.c" 3 4
                  1
# 50 "runnable/extra-files/cstuff3.c"
                      , 
# 50 "runnable/extra-files/cstuff3.c" 3 4
                        0 
# 50 "runnable/extra-files/cstuff3.c"
                              );
 if ( bct != 
# 51 "runnable/extra-files/cstuff3.c" 3 4
            1 
# 51 "runnable/extra-files/cstuff3.c"
                 ) { printf("error 3a"); exit(1); }
 bct = useBoolXor( 
# 52 "runnable/extra-files/cstuff3.c" 3 4
                  0
# 52 "runnable/extra-files/cstuff3.c"
                       , 
# 52 "runnable/extra-files/cstuff3.c" 3 4
                         1 
# 52 "runnable/extra-files/cstuff3.c"
                              );
 if ( bct == 
# 53 "runnable/extra-files/cstuff3.c" 3 4
            0 
# 53 "runnable/extra-files/cstuff3.c"
                  ) { printf("error 3b"); exit(1); }

 bcf = useBoolXor( 
# 55 "runnable/extra-files/cstuff3.c" 3 4
                  1
# 55 "runnable/extra-files/cstuff3.c"
                      , 
# 55 "runnable/extra-files/cstuff3.c" 3 4
                        1 
# 55 "runnable/extra-files/cstuff3.c"
                             );
 if ( bcf != 
# 56 "runnable/extra-files/cstuff3.c" 3 4
            0 
# 56 "runnable/extra-files/cstuff3.c"
                  ) { printf("error 3c"); exit(1); }
 bcf = useBoolXor( 
# 57 "runnable/extra-files/cstuff3.c" 3 4
                  0
# 57 "runnable/extra-files/cstuff3.c"
                       , 
# 57 "runnable/extra-files/cstuff3.c" 3 4
                         0 
# 57 "runnable/extra-files/cstuff3.c"
                               );
 if ( bcf == 
# 58 "runnable/extra-files/cstuff3.c" 3 4
            1 
# 58 "runnable/extra-files/cstuff3.c"
                 ) { printf("error 3d"); exit(1); }

    return 0;
}
