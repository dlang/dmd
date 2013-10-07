
/*
        D listener written by Christopher E. Miller
        This code is public domain.
        You may use it for any purpose.
        This code has no warranties and is provided 'as-is'.
 */

import std.conv, std.socket, std.stdio;

int main(char[][] args)
{
    ushort port;

    if (args.length >= 2)
        port = to!ushort(args[1]);
    else
        port = 4444;

    Socket listener = new TcpSocket;
    assert(listener.isAlive);
    listener.blocking = false;
    listener.bind(new InternetAddress(port));
    listener.listen(10);
    writefln("Listening on port %d.", port);

    const int MAX_CONNECTIONS = 60;
    SocketSet sset = new SocketSet(MAX_CONNECTIONS + 1);     // Room for listener.
    Socket[]  reads;

    for (;; sset.reset())
    {
        sset.add(listener);

        foreach (Socket each; reads)
        {
            sset.add(each);
        }

        Socket.select(sset, null, null);

        int i;

        for (i = 0;; i++)
        {
next:
            if (i == reads.length)
                break;

            if (sset.isSet(reads[i]))
            {
                char[1024] buf;
                auto read = reads[i].receive(buf);

                if (Socket.ERROR == read)
                {
                    writeln("Connection error.");
                    goto sock_down;
                }
                else if (0 == read)
                {
                    try
                    {
                        // if the connection closed due to an error, remoteAddress() could fail
                        writefln("Connection from %s closed.", reads[i].remoteAddress().toString());
                    }
                    catch (SocketException)
                    {
                        writeln("Connection closed.");
                    }

sock_down:
                    reads[i].close();                     // release socket resources now

                    // remove from -reads-
                    if (i != reads.length - 1)
                        reads[i] = reads[reads.length - 1];

                    reads = reads[0 .. reads.length - 1];

                    writefln("\tTotal connections: %d", reads.length);

                    goto next;                     // -i- is still the next index
                }
                else
                {
                    writefln("Received %d bytes from %s: \"%s\"", read, reads[i].remoteAddress().toString(), buf[0 .. read]);
                }
            }
        }

        if (sset.isSet(listener))        // connection request
        {
            Socket sn;
            try
            {
                if (reads.length < MAX_CONNECTIONS)
                {
                    sn = listener.accept();
                    writefln("Connection from %s established.", sn.remoteAddress().toString());
                    assert(sn.isAlive);
                    assert(listener.isAlive);

                    reads ~= sn;
                    writefln("\tTotal connections: %d", reads.length);
                }
                else
                {
                    sn = listener.accept();
                    writefln("Rejected connection from %s; too many connections.", sn.remoteAddress().toString());
                    assert(sn.isAlive);

                    sn.close();
                    assert(!sn.isAlive);
                    assert(listener.isAlive);
                }
            }
            catch (Exception e)
            {
                writefln("Error accepting: %s", e.toString());

                if (sn)
                    sn.close();
            }
        }
    }

    return 0;
}
