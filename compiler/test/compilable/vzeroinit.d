/* REQUIRED_ARGS: -vzeroinit -betterC
TEST_OUTPUT:
---
compilable/vzeroinit.d(29): `vzeroinit.Fighter` has a non-zero default initializer, 4 bytes stored in the binary
compilable/vzeroinit.d(29):     field `Fighter.stance` of type `Stance`
compilable/vzeroinit.d(27):         enum `vzeroinit.Stance` defaults to its first member `Stance.LOW`, which is not zero
compilable/vzeroinit.d(30): `vzeroinit.Action` has a non-zero default initializer, 20 bytes stored in the binary
compilable/vzeroinit.d(30):     field `Action.dir` is initialized to `Vec(0, 0, 1)`
compilable/vzeroinit.d(31): `vzeroinit.Pos` has a non-zero default initializer, 8 bytes stored in the binary
compilable/vzeroinit.d(31):     field `Pos.x` of type `float`
compilable/vzeroinit.d(31):         type `float` defaults to `float.nan`
compilable/vzeroinit.d(33): `vzeroinit.World` has a non-zero default initializer, 1316 bytes stored in the binary
compilable/vzeroinit.d(33):     field `World.fighter` of type `Fighter[8]`
compilable/vzeroinit.d(29):         field `Fighter.stance` of type `Stance`
compilable/vzeroinit.d(27):             enum `vzeroinit.Stance` defaults to its first member `Stance.LOW`, which is not zero
compilable/vzeroinit.d(34): `vzeroinit.g_world` is default initialized to non-zero data, 1316 bytes stored in the binary
compilable/vzeroinit.d(33):     field `World.fighter` of type `Fighter[8]`
compilable/vzeroinit.d(29):         field `Fighter.stance` of type `Stance`
compilable/vzeroinit.d(27):             enum `vzeroinit.Stance` defaults to its first member `Stance.LOW`, which is not zero
---
*/

module vzeroinit;

struct Vec { int x, y, z; }
enum Side : ubyte { NEUTRAL, PLAYER }
enum Stance : ubyte { LOW = 1, HIGH }
struct Zero    { int a; Vec v; Side s; bool b; uint d = 0; int[4] arr = 0; float[0] none; }
struct Fighter { Stance stance; ushort id; }
struct Action  { int seq; Vec dir = Vec(0, 0, 1); int pad = void; }
struct Pos     { float x; int y = 0; }
union  U       { int i; float f; }
struct World   { Zero[32] zero; Fighter[8] fighter; U u; }
__gshared World g_world;
__gshared Zero g_zero;
__gshared Fighter g_explicit = Fighter(Stance.HIGH);
