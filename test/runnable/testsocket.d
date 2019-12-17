// PERMUTE_ARGS:
/*
TEST_OUTPUT:
---
runnable/testsocket.d(48): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
---
*/

import std.stdio;
import std.socket;

class Connection
{
        private
        {
                Socket sock;
        }

        void connect (string host, ushort port)
        {
                sock.connect (new InternetAddress (host, port));
        }

        void poll ()
        {
                SocketSet rset = new SocketSet (1); /** XXX: here is the bug */

                rset.reset ();
                rset.add (sock);
        }

        this ()
        {

                sock = new TcpSocket;
                sock.blocking = false;
        }
}

int main ()
{
        try
        {
            Connection ns;
            ns = new Connection ();
            ns.connect ("localhost", 80);
            ns.poll ();
            delete ns;
        }
        catch(SocketException e)
        {
        }
        return 0;
}


