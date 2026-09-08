module net.event_processor;

import core.stdc.stdio;
import std.format : format;

// 1. Hybrid Tagged Union: Primitives, Slices, Tuples, and Named Records
enum union NetworkEvent
{
    // Bare primitive & slice types (types act directly as discriminant tags)
    case int,                    // Raw error code
    case ubyte[],                // Unparsed raw payload buffer

    // Unit variants
    case Disconnected,
    case Heartbeat,

    // Positional (tuple-like) variants
    case Ping(ulong timestamp, ushort sequenceId),

    // Named record variants
    case HttpRequest { string method; string path; ushort statusCode; };

    // Embedded methods
    string summary() const @safe
    {
        // Switch expression with fat-arrow arms and comma separators
        return switch (this)
        {
            case int errCode               => format("Socket Error: %d", errCode),
            case ubyte[] data              => format("Raw Frame (%d bytes)", data.length),
            case Disconnected              => "Connection Closed",
            case Heartbeat                 => "Keep-Alive ACK",
            case Ping(ts, seq)             => format("Ping [seq=%d, ts=%d]", seq, ts),
            case HttpRequest { method, path, statusCode } => format("%s %s -> %d", method, path, statusCode),
        };
    }
}

// 2. Request Dispatcher demonstrating elimination and return type unification
struct ConnectionHandler
{
    ulong activeSessionId;

    // Dispatches an incoming event and computes an action response code
    int handleEvent(NetworkEvent event) @safe
    {
        // All arms strictly unify via Least Upper Bound (LUB)
        return switch (event)
        {
            case int err => err < 0 ? err : -1,
            case ubyte[] frame => processFrame(frame),
            case Heartbeat => 0,
            case Ping(ts, seq) => sendPong(ts, seq),
            case HttpRequest { statusCode, .. } => cast(int) statusCode, // Partial record destructuring
            case Disconnected => throw new Exception("Terminating disconnected session"),
        };
    }

    private int processFrame(const ubyte[] frame) @safe pure nothrow => 200;
    private int sendPong(ulong ts, ushort seq) @safe nothrow => 1;
}

void main()
{
    // Supports assignment-style construction
    NetworkEvent e1 = 404;
    ubyte[] payload = [0xDE, 0xAD, 0xBE, 0xEF];
    NetworkEvent e2 = payload;

    // Labeled variant construction via synthesized static factories for named case variants
    NetworkEvent e3 = NetworkEvent.Heartbeat;
    NetworkEvent e4 = NetworkEvent.Ping(1_700_000_000, 42);
    NetworkEvent e5 = NetworkEvent.HttpRequest("GET", "/api/v1/status", 200);

    auto handler = ConnectionHandler(1001);

    assert(handler.handleEvent(e1) == -1);
    assert(handler.handleEvent(e3) == 0);
    assert(handler.handleEvent(e4) == 1);
    assert(handler.handleEvent(e5) == 200);
    assert(e2.summary() == "Raw Frame (4 bytes)");
    assert(e5.summary() == "GET /api/v1/status -> 200");
}