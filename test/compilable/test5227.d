
enum cif = 5 ^^ 6.25f;
enum cid = 5 ^^ 6.25;
enum cil = 5 ^^ 6.25L;

enum cff = 5.42f ^^ 6.25f;
enum cfd = 5.42f ^^ 6.25;
enum cfl = 5.42f ^^ 6.25L;

enum cdf = 5.42 ^^ 6.25f;
enum cdd = 5.42 ^^ 6.25;
enum cdl = 5.42 ^^ 6.25L;

enum clf = 5.42L ^^ 6.25f;
enum cld = 5.42L ^^ 6.25;
enum cll = 5.42L ^^ 6.25L;

float  funcFloat(float x, float y)    { return x ^^ y; }
double funcDouble(double x, double y) { return x ^^ y; }
real   funcReal(real x, real y)       { return x ^^ y; }

enum funcValueF = funcFloat(5.42f, 6.25f);
enum funcValueD = funcDouble(5.42, 6.25);
enum funcValueL = funcReal(5.42L, 6.25L);
