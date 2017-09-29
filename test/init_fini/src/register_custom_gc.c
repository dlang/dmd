extern void register_mygc();

__attribute__((constructor)) static void xxx_ctor()
{
    register_mygc();
}
