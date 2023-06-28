/+
ARG_SETS: -version=Unoptimized
ARG_SETS: -O
+/

version (Unoptimized)
{
    version (D_Optimized)
        static assert(0);
}
else
{
    version (D_Optimized) { /* expected */ } else
        static assert(0);
}
