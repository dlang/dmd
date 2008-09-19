/**
 * D header file for POSIX.
 *
 * Copyright: Public Domain
 * License:   Public Domain
 * Authors:   Sean Kelly
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */
module stdc.posix.termios;

private import stdc.posix.config;
public import stdc.posix.sys.types; // for pid_t

extern (C):

//
// Required
//
/*
cc_t
speed_t
tcflag_t

NCCS

struct termios
{
    tcflag_t   c_iflag;
    tcflag_t   c_oflag;
    tcflag_t   c_cflag;
    tcflag_t   c_lflag;
    cc_t[NCCS] c_cc;
}

VEOF
VEOL
VERASE
VINTR
VKILL
VMIN
VQUIT
VSTART
VSTOP
VSUSP
VTIME

BRKINT
ICRNL
IGNBRK
IGNCR
IGNPAR
INLCR
INPCK
ISTRIP
IXOFF
IXON
PARMRK

OPOST

B0
B50
B75
B110
B134
B150
B200
B300
B600
B1200
B1800
B2400
B4800
B9600
B19200
B38400

CSIZE
    CS5
    CS6
    CS7
    CS8
CSTOPB
CREAD
PARENB
PARODD
HUPCL
CLOCAL

ECHO
ECHOE
ECHOK
ECHONL
ICANON
IEXTEN
ISIG
NOFLSH
TOSTOP

TCSANOW
TCSADRAIN
TCSAFLUSH

TCIFLUSH
TCIOFLUSH
TCOFLUSH

TCIOFF
TCION
TCOOFF
TCOON

speed_t cfgetispeed(in termios*);
speed_t cfgetospeed(in termios*);
int     cfsetispeed(termios*, speed_t);
int     cfsetospeed(termios*, speed_t);
int     tcdrain(int);
int     tcflow(int, int);
int     tcflush(int, int);
int     tcgetattr(int, termios*);
int     tcsendbreak(int, int);
int     tcsetattr(int, int, in termios*);
*/

version ( darwin)
{
    alias ubyte cc_t;
    alias uint  speed_t;
    alias uint  tcflag_t;

    const NCCS  = 20;

    struct termios
    {
        tcflag_t   c_iflag;
        tcflag_t   c_oflag;
        tcflag_t   c_cflag;
        tcflag_t   c_lflag;
        cc_t[NCCS] c_cc;
        speed_t    c_ispeed;
        speed_t    c_ospeed;
    }

    const VEOF      = 0;
    const VEOL      = 1;
    const VERASE    = 3;
    const VINTR     = 8;
    const VKILL     = 5;
    const VMIN      = 16;
    const VQUIT     = 9;
    const VSTART    = 12;
    const VSTOP     = 13;
    const VSUSP     = 10;
    const VTIME     = 17;

    const BRKINT    = 0x0000002;
    const ICRNL     = 0x0000100;
    const IGNBRK    = 0x0000001;
    const IGNCR     = 0x0000080;
    const IGNPAR    = 0x0000004;
    const INLCR     = 0x0000040;
    const INPCK     = 0x0000010;
    const ISTRIP    = 0x0000020;
    const IXOFF     = 0x0000400;
    const IXON      = 0x0000200;
    const PARMRK    = 0x0000008;

    const OPOST     = 0x0000001;

    const B0        = 0;
    const B50       = 50;
    const B75       = 75;
    const B110      = 110;
    const B134      = 134;
    const B150      = 150;
    const B200      = 200;
    const B300      = 300;
    const B600      = 600;
    const B1200     = 1200;
    const B1800     = 1800;
    const B2400     = 2400;
    const B4800     = 4800;
    const B9600     = 9600;
    const B19200    = 19200;
    const B38400    = 38400;

    const CSIZE     = 0x0000300;
    const   CS5     = 0x0000000;
    const   CS6     = 0x0000100;
    const   CS7     = 0x0000200;
    const   CS8     = 0x0000300;
    const CSTOPB    = 0x0000400;
    const CREAD     = 0x0000800;
    const PARENB    = 0x0001000;
    const PARODD    = 0x0002000;
    const HUPCL     = 0x0004000;
    const CLOCAL    = 0x0008000;

    const ECHO      = 0x00000008;
    const ECHOE     = 0x00000002;
    const ECHOK     = 0x00000004;
    const ECHONL    = 0x00000010;
    const ICANON    = 0x00000100;
    const IEXTEN    = 0x00000400;
    const ISIG      = 0x00000080;
    const NOFLSH    = 0x80000000;
    const TOSTOP    = 0x00400000;

    const TCSANOW   = 0;
    const TCSADRAIN = 1;
    const TCSAFLUSH = 2;

    const TCIFLUSH  = 1;
    const TCOFLUSH  = 2;
    const TCIOFLUSH = 3;

    const TCIOFF    = 3;
    const TCION     = 4;
    const TCOOFF    = 1;
    const TCOON     = 2;

    speed_t cfgetispeed(in termios*);
    speed_t cfgetospeed(in termios*);
    int     cfsetispeed(termios*, speed_t);
    int     cfsetospeed(termios*, speed_t);
    int     tcdrain(int);
    int     tcflow(int, int);
    int     tcflush(int, int);
    int     tcgetattr(int, termios*);
    int     tcsendbreak(int, int);
    int     tcsetattr(int, int, in termios*);

}

version( linux )
{
    alias ubyte cc_t;
    alias uint  speed_t;
    alias uint  tcflag_t;

    const NCCS  = 32;

    struct termios
    {
        tcflag_t   c_iflag;
        tcflag_t   c_oflag;
        tcflag_t   c_cflag;
        tcflag_t   c_lflag;
        cc_t       c_line;
        cc_t[NCCS] c_cc;
        speed_t    c_ispeed;
        speed_t    c_ospeed;
    }

    const VEOF      = 4;
    const VEOL      = 11;
    const VERASE    = 2;
    const VINTR     = 0;
    const VKILL     = 3;
    const VMIN      = 6;
    const VQUIT     = 1;
    const VSTART    = 8;
    const VSTOP     = 9;
    const VSUSP     = 10;
    const VTIME     = 5;

    const BRKINT    = 0000002;
    const ICRNL     = 0000400;
    const IGNBRK    = 0000001;
    const IGNCR     = 0000200;
    const IGNPAR    = 0000004;
    const INLCR     = 0000100;
    const INPCK     = 0000020;
    const ISTRIP    = 0000040;
    const IXOFF     = 0010000;
    const IXON      = 0002000;
    const PARMRK    = 0000010;

    const OPOST     = 0000001;

    const B0        = 0000000;
    const B50       = 0000001;
    const B75       = 0000002;
    const B110      = 0000003;
    const B134      = 0000004;
    const B150      = 0000005;
    const B200      = 0000006;
    const B300      = 0000007;
    const B600      = 0000010;
    const B1200     = 0000011;
    const B1800     = 0000012;
    const B2400     = 0000013;
    const B4800     = 0000014;
    const B9600     = 0000015;
    const B19200    = 0000016;
    const B38400    = 0000017;

    const CSIZE     = 0000060;
    const   CS5     = 0000000;
    const   CS6     = 0000020;
    const   CS7     = 0000040;
    const   CS8     = 0000060;
    const CSTOPB    = 0000100;
    const CREAD     = 0000200;
    const PARENB    = 0000400;
    const PARODD    = 0001000;
    const HUPCL     = 0002000;
    const CLOCAL    = 0004000;

    const ECHO      = 0000010;
    const ECHOE     = 0000020;
    const ECHOK     = 0000040;
    const ECHONL    = 0000100;
    const ICANON    = 0000002;
    const IEXTEN    = 0100000;
    const ISIG      = 0000001;
    const NOFLSH    = 0000200;
    const TOSTOP    = 0000400;

    const TCSANOW   = 0;
    const TCSADRAIN = 1;
    const TCSAFLUSH = 2;

    const TCIFLUSH  = 0;
    const TCOFLUSH  = 1;
    const TCIOFLUSH = 2;

    const TCIOFF    = 2;
    const TCION     = 3;
    const TCOOFF    = 0;
    const TCOON     = 1;

    speed_t cfgetispeed(in termios*);
    speed_t cfgetospeed(in termios*);
    int     cfsetispeed(termios*, speed_t);
    int     cfsetospeed(termios*, speed_t);
    int     tcdrain(int);
    int     tcflow(int, int);
    int     tcflush(int, int);
    int     tcgetattr(int, termios*);
    int     tcsendbreak(int, int);
    int     tcsetattr(int, int, in termios*);
}

//
// XOpen (XSI)
//
/*
IXANY

ONLCR
OCRNL
ONOCR
ONLRET
OFILL
NLDLY
    NL0
    NL1
CRDLY
    CR0
    CR1
    CR2
    CR3
TABDLY
    TAB0
    TAB1
    TAB2
    TAB3
BSDLY
    BS0
    BS1
VTDLY
    VT0
    VT1
FFDLY
    FF0
    FF1

pid_t   tcgetsid(int);
*/

version( linux )
{
    const IXANY     = 0004000;

    const ONLCR     = 0000004;
    const OCRNL     = 0000010;
    const ONOCR     = 0000020;
    const ONLRET    = 0000040;
    const OFILL     = 0000100;
    const NLDLY     = 0000400;
    const   NL0     = 0000000;
    const   NL1     = 0000400;
    const CRDLY     = 0003000;
    const   CR0     = 0000000;
    const   CR1     = 0001000;
    const   CR2     = 0002000;
    const   CR3     = 0003000;
    const TABDLY    = 0014000;
    const   TAB0    = 0000000;
    const   TAB1    = 0004000;
    const   TAB2    = 0010000;
    const   TAB3    = 0014000;
    const BSDLY     = 0020000;
    const   BS0     = 0000000;
    const   BS1     = 0020000;
    const VTDLY     = 0040000;
    const   VT0     = 0000000;
    const   VT1     = 0040000;
    const FFDLY     = 0100000;
    const   FF0     = 0000000;
    const   FF1     = 0100000;

    pid_t   tcgetsid(int);
}
