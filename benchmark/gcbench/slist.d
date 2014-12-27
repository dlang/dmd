/**
 * Copyright: Copyright Rainer Schuetze 2014.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Rainer Schuetze
 *
 * This test reads a text file, then splits the result into white space delimited words.
 * The result is a single linked list of strings referencing the full text.
 * Regarding GC activity, this test probes collection of linked lists.
 */
import std.stdio;
import std.conv;
import std.file;
import std.string;
import std.exception;

struct Node
{
    string token;
    Node* next;
}

void main(string[] args)
{
    string txt = cast(string) std.file.read(args.length > 1 ? args[1] : "extra-files/dante.txt");
    uint cnt = args.length > 2 ? to!uint(args[2]) : 100;
    uint allwords = 0;
    for(uint i = 0; i < cnt; i++)
    {
        Node* firstNode;
        auto words = txt.split();
        foreach(w; words)
        {
            Node* n = new Node;
            n.token = w;
            n.next = firstNode;
            firstNode = n;
        }

        for(Node* p = firstNode; p; p = p.next)
            allwords++;
    }
    enforce(allwords == (args.length > 3 ? to!size_t(args[3]) : 9767600));
}
