// 4375: Dangling else

version (A)
    version (B)
        struct G3 {}
else
    struct G4 {}

