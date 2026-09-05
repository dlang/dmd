module enumsunion_test;

import core.stdc.stdio;

// 1. Basic Unit & Positional Variants
enum union Option(T) {
    case Some(T),
    case None,
}

// 2. Hybrid Union: Bare Types, Records, and Unit Sentinels
enum union Response {
    case double,                           // Bare type
    case string,                           // Bare type
    case Timeout,                          // Unit variant
    case Success { int code; string payload; } // Record variant
}

// 3. RAII Resource Tracking
struct Resource {
    int id;
    static int liveCount = 0;
    this(int id) { this.id = id; liveCount++; }
    this(ref typeof(this) rhs) { this.id = rhs.id; liveCount++; }
    ~this() { liveCount--; }
}

enum union Managed {
    case Handle(Resource),
    case Empty,
}

// 4. Field access across variants
enum union Entity {
    case Player { int id; string name; },
    case Monster { int id; int hp; },
}

void main() {
    // Test Option Matching & Type Unification
    Option!int opt = Option!int.Some(42);
    int val = switch (opt) {
        case Some(v) => v * 2,
        case None    => 0,
    };
    assert(val == 84);

    // Test 'noreturn' arm unification
    int safeVal = switch (opt) {
        case Some(v) => v,
        case None    => throw new Exception("Empty"), // Unifies: LUB(int, noreturn) -> int
    };
    assert(safeVal == 42);

    // Test Bare Type Matching and Direct Construction
    Response r1 = 3.14;
    Response r2 = Response.Success(200, "OK");
    Response r3 = Response.Timeout;
    string status = switch (r1) {
        case double d             => "Floating-point",
        case string s             => "String",
        case Timeout              => "Timeout",
        case Success { code, .. } => "Success",
    };
    assert(status == "Floating-point");

    int successCode = switch (r2) {
        case double d             => -1,
        case string s             => -2,
        case Timeout              => -3,
        case Success { code, .. } => code,
    };
    assert(successCode == 200);

    // Test RAII Destruction and Re-tagging
    {
        assert(Resource.liveCount == 0);
        Managed m = Managed.Handle(Resource(1));
        assert(Resource.liveCount == 1);
        
        m = Managed.Empty; // Overwrite must invoke Resource.~this()
        assert(Resource.liveCount == 0);
    }
    assert(Resource.liveCount == 0);

    // Field access across variants goes through a switch, not direct `.field`.
    Entity e = Entity.Player(10, "Hero");
    int id = switch (e) {
        case Player { id, .. } => id,
        case Monster { id, .. } => id,
    };
    assert(id == 10);
}