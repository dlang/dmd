// PERMUTE_ARGS:
// REQUIRED_ARGS: -o- -Icompilable/extra-files

module testDIP37_10354;
import pkgDIP37_10354.mfoo;
void main()
{
    import pkgDIP37_10354;
    foo!string();   // OK
    bar!string();   // OK <- ICE
}
