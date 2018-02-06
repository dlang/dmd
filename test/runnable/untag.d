// PERMUTE_ARGS:

import std.algorithm, std.ascii, std.conv, std.exception,
    std.file, std.getopt, std.path, std.range, std.stdio,
    std.string, std.traits;

auto binaryFun(string pred, T, U)(T a, U b)
{
    return(mixin(pred));
}

/**
If $(D startsWith(r1, r2)), consume the corresponding elements off $(D
r1) and return $(D true). Otherwise, leave $(D r1) unchanged and
return $(D false).
*/
bool startsWithConsume(alias pred = "a == b", R1, R2)(ref R1 r1, R2 r2)
{
    auto r = r1; // .save();
    while (!r2.empty && !r.empty && binaryFun!pred(r.front, r2.front))
    {
        r.popFront();
        r2.popFront();
    }
    return r2.empty ? (){ r1 = r; return true;}() : false;
}


uint bug = 1;

int main(string args[]) {
    getopt(args, "bug", &bug);
    enforce(bug <= 2);
    auto txt = readText("runnable/extra-files/untag.html");
    untag(txt, "runnable/extra-files/untag.html");
    return 0;
}

void untag(string txt, string filename) {
    string currentParagraph;
    string origtxt = txt;
    string origtxtcopy = txt.idup;

    // Find beginning of content
    txt = std.algorithm.find(txt, "<!-- start content -->\n");

    // Ancillary function that commits the current paragraph for
    // writing
    void commit() {
        writeParagraph(strip(currentParagraph));
    }

    void writeChar(dchar c) {
        immutable lastWritten = currentParagraph.length
            ? currentParagraph.back
            : dchar.init;
        if (lastWritten == ' ' && c == ' ') {
            // Two consecutive spaces fused
        } else {
            // Normal case
            currentParagraph ~= c;
        }
    }

    void writeWords(string s) {
        if (bug == 0) {
            foreach (dchar c; s) {
                currentParagraph ~= c;
            }
        } else if (bug == 1) {
            reserve(currentParagraph, currentParagraph.length + s.length);
            currentParagraph ~= s;
        } else {
            currentParagraph = currentParagraph ~ s;
        }
    }

    // Parse the content
    while (!txt.empty) {
        size_t i = 0;
        while (i < txt.length && txt[i] != '<' && txt[i] != '&') {
            ++i;
        }
        writeWords(txt[0 .. i]);
        if (i == txt.length) {
            commit();
            return;
        }
        txt = txt[i .. $];
        auto c = txt[0];
        txt = txt[1 .. $];
        if (c == '<') { // This is a tag
            if (startsWithConsume(txt, `/p>`) ||
                    startsWithConsume(txt, `/li>`)) {
                // End of paragraph
                commit();
            } else {
                // This is an uninteresting tag
                enforce(findConsume(txt, '>'),
                        "Could not find closing tag: "~txt);
            }
        } else {
            auto app = appender!string();
            findConsume(txt, ';', app);
            switch (app.data) {
            case "#160;": case "#32;": case "reg;": case "nbsp;":
                writeChar(' ');
                break;
            case "amp;":
                writeChar('&');
                break;
            case "gt;":
                writeChar('>');
                break;
            case "lt;":
                writeChar('<');
                break;
            case "quot;":
                writeChar('"');
                break;
            default:
                throw new Exception(text("Unknown code: &", app.data));
                break;
            }
        }
    }
}

void writeParagraph(string sentence) {
    static bool isSeparator(dchar a) {
        return !(isAlpha(a) /*|| a == '.'*/);
    }

    foreach (string cand; std.algorithm.splitter(sentence, ' ')) {
        cand = toLower(cand);
    }
}

/**
If $(D r2) can not be found in $(D r1), leave $(D r1) unchanged and
return $(D false). Otherwise, consume elements in $(D r1) until $(D
startsWithConsume(r1, r2)), and return $(D true). Effectively
positions $(D r1) right after $(D r2).
 */
bool findConsume(R1, R2)(ref R1 r1, R2 r2) if (isForwardRange!R2) {
    auto r = r1; // .save();
    while (!r.empty) {
        if (startsWithConsume(r, r2)) {
            r1 = r;
            return true;
        }
        r.popFront();
    }
    return false;
}

/**
If $(D r2) can not be found in $(D r1), leave $(D r1) unchanged and
return $(D false). Otherwise, consume elements in $(D r1) until $(D
startsWith(r1, r2)), and return $(D true).
 */
bool findConsume(R, E)(ref R r, E e) if (is(typeof(r.front == e))) {
    auto r1 = std.algorithm.find(r, e);
    if (r1.empty) return false;
    r = r1;
    r.popFront();
    return true;
}

/**
If $(D r2) can not be found in $(D r1), leave $(D r1) unchanged and
return $(D false). Otherwise, consume elements in $(D r1) until $(D
startsWith(r1, r2)), and return $(D true).
 */
bool findConsume(R1, E, R2)(ref R1 r1, E e, R2 r2) if (is(typeof(r1.front == e))) {
    auto r = r1;
    while (!r.empty) {
        r2.put(r.front);
        if (r.front == e) {
            r.popFront();
            r1 = r;
            return true;
        }
        r.popFront();
    }
    return false;
}

