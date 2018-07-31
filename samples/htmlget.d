
/*
        HTMLget written by Christopher E. Miller
        This code is public domain.
        You may use it for any purpose.
        This code has no warranties and is provided 'as-is'.
 */

debug = HTMLGET;

import std.string, std.conv, std.stdio;
import std.socket;

int main(string[] args)
{
    if (args.length < 2)
    {
        writeln("Usage:");
        writeln("   htmlget <web-page>");
        return 0;
    }

    string url = args[1];
    auto i = indexOf(url, "://");

    if (i != -1)
    {
        if (icmp(url[0 .. i], "http"))
            throw new Exception("http:// expected");
        url = url[i + 3 .. $];
    }

    i = indexOf(url, '#');

    if (i != -1)    // Remove anchor ref.
        url = url[0 .. i];

    i = indexOf(url, '/');
    string domain;

    if (i == -1)
    {
        domain = url;
        url    = "/";
    }
    else
    {
        domain = url[0 .. i];
        url    = url[i .. $];
    }

    ushort port;
    i = indexOf(domain, ':');

    if (i == -1)
    {
        port = 80;         // Default HTTP port.
    }
    else
    {
        port   = to!ushort(domain[i + 1 .. $]);
        domain = domain[0 .. i];
    }

    debug (HTMLGET)
        writefln("Connecting to %s on port %d...", domain, port);

    Socket sock = new TcpSocket(new InternetAddress(domain, port));
    scope(exit) sock.close();

    debug (HTMLGET)
        writefln("Connected! Requesting URL \"%s\"...", url);

    if (port != 80)
        domain = domain ~ ":" ~ to!string(port);

    sock.send("GET " ~ url ~ " HTTP/1.0\r\n" ~
                   "Host: " ~ domain ~ "\r\n" ~
                   "\r\n");

    // Skip HTTP header.
    while (true)
    {
        char[] line;
        char[1] buf;
        while(sock.receive(buf))
        {
            line ~= buf;
            if (buf[0] == '\n')
                break;
        }

        if (!line.length)
            break;

        write(line);

        enum CONTENT_TYPE_NAME = "Content-Type: ";

        if (line.length > CONTENT_TYPE_NAME.length &&
            !icmp(CONTENT_TYPE_NAME, line[0 .. CONTENT_TYPE_NAME.length]))
        {
            auto type = line[CONTENT_TYPE_NAME.length .. $];

            if (type.length <= 5 || icmp("text/", type[0 .. 5]))
                throw new Exception("URL is not text");
        }
    }

    return 0;
}
