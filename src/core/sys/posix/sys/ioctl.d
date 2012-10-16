/**
 * D header file for POSIX.
 *
 * Copyright: Copyright Alex Rønne Petersen 2011 - 2012.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Alex Rønne Petersen
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */

/*          Copyright Alex Rønne Petersen 2011 - 2012.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.sys.posix.sys.ioctl;

import core.stdc.config;

version (Posix):

extern (C):
@system:
nothrow:

version (linux)
{
    struct winsize
    {
        ushort ws_row;
        ushort ws_col;
        ushort ws_xpixel;
        ushort ws_ypixel;
    }

    enum NCC = 8;

    struct termio
    {
        ushort c_iflag;
        ushort c_oflag;
        ushort c_cflag;
        ushort c_lflag;
        ubyte c_line;
        ubyte[NCC] c_cc;
    }

    enum TIOCM_LE = 0x001;
    enum TIOCM_DTR = 0x002;
    enum TIOCM_RTS = 0x004;
    enum TIOCM_ST = 0x008;
    enum TIOCM_SR = 0x010;
    enum TIOCM_CTS = 0x020;
    enum TIOCM_CAR = 0x040;
    enum TIOCM_RNG = 0x080;
    enum TIOCM_DSR = 0x100;
    enum TIOCM_CD = TIOCM_CAR;
    enum TIOCM_RI = TIOCM_RNG;

    enum N_TTY = 0;
    enum N_SLIP = 1;
    enum N_MOUSE = 2;
    enum N_PPP = 3;
    enum N_STRIP = 4;
    enum N_AX25 = 5;
    enum N_X25 = 6;
    enum N_6PACK = 7;
    enum N_MASC = 8;
    enum N_R3964 = 9;
    enum N_PROFIBUS_FDL = 10;
    enum N_IRDA = 11;
    enum N_SMSBLOCK = 12;
    enum N_HDLC = 13;
    enum N_SYNC_PPP = 14;
    enum N_HCI = 15;

    enum TCGETS = 0x5401;
    enum TCSETS = 0x5402;
    enum TCSETSW = 0x5403;
    enum TCSETSF = 0x5404;
    enum TCGETA = 0x5405;
    enum TCSETA = 0x5406;
    enum TCSETAW = 0x5407;
    enum TCSETAF = 0x5408;
    enum TCSBRK = 0x5409;
    enum TCXONC = 0x540A;
    enum TCFLSH = 0x540B;
    enum TIOCEXCL = 0x540C;
    enum TIOCNXCL = 0x540D;
    enum TIOCSCTTY = 0x540E;
    enum TIOCGPGRP = 0x540F;
    enum TIOCSPGRP = 0x5410;
    enum TIOCOUTQ = 0x5411;
    enum TIOCSTI = 0x5412;
    enum TIOCGWINSZ = 0x5413;
    enum TIOCSWINSZ = 0x5414;
    enum TIOCMGET = 0x5415;
    enum TIOCMBIS = 0x5416;
    enum TIOCMBIC = 0x5417;
    enum TIOCMSET = 0x5418;
    enum TIOCGSOFTCAR = 0x5419;
    enum TIOCSSOFTCAR = 0x541A;
    enum FIONREAD = 0x541B;
    enum TIOCINQ = FIONREAD;
    enum TIOCLINUX = 0x541C;
    enum TIOCCONS = 0x541D;
    enum TIOCGSERIAL = 0x541E;
    enum TIOCSSERIAL = 0x541F;
    enum TIOCPKT = 0x5420;
    enum FIONBIO = 0x5421;
    enum TIOCNOTTY = 0x5422;
    enum TIOCSETD = 0x5423;
    enum TIOCGETD = 0x5424;
    enum TCSBRKP = 0x5425;
    enum TIOCSBRK = 0x5427;
    enum TIOCCBRK = 0x5428;
    enum TIOCGSID = 0x5429;

    //enum TCGETS2  _IOR('T', 0x2A, struct termios2)
    //enum TCSETS2  _IOW('T', 0x2B, struct termios2)
    //enum TCSETSW2 _IOW('T', 0x2C, struct termios2)
    //enum TCSETSF2 _IOW('T', 0x2D, struct termios2)

    enum TIOCGRS485 = 0x542E;
    enum TIOCSRS485 = 0x542F;

    //enum TIOCGPTN   _IOR('T', 0x30, unsigned int)
    //enum TIOCSPTLCK _IOW('T', 0x31, int)
    //enum TIOCGDEV   _IOR('T', 0x32, unsigned int)

    enum TCGETX = 0x5432;
    enum TCSETX = 0x5433;
    enum TCSETXF = 0x5434;
    enum TCSETXW = 0x5435;

    //enum TIOCSIG _IOW('T', 0x36, int)

    enum TIOCVHANGUP = 0x5437;

    enum FIONCLEX = 0x5450;
    enum FIOCLEX = 0x5451;
    enum FIOASYNC = 0x5452;
    enum TIOCSERCONFIG = 0x5453;
    enum TIOCSERGWILD = 0x5454;
    enum TIOCSERSWILD = 0x5455;
    enum TIOCGLCKTRMIOS = 0x5456;
    enum TIOCSLCKTRMIOS = 0x5457;
    enum TIOCSERGSTRUCT = 0x5458;
    enum TIOCSERGETLSR = 0x5459;
    enum TIOCSERGETMULTI = 0x545A;
    enum TIOCSERSETMULTI = 0x545B;

    enum TIOCMIWAIT = 0x545C;
    enum TIOCGICOUNT = 0x545D;

    enum FIOQSIZE = 0x5460;

    enum TIOCPKT_DATA = 0;
    enum TIOCPKT_FLUSHREAD = 1;
    enum TIOCPKT_FLUSHWRITE = 2;
    enum TIOCPKT_STOP = 4;
    enum TIOCPKT_START = 8;
    enum TIOCPKT_NOSTOP = 16;
    enum TIOCPKT_DOSTOP = 32;
    enum TIOCPKT_IOCTL = 64;

    enum TIOCSER_TEMT = 0x01;

    enum SIOCADDRT = 0x890B;
    enum SIOCDELRT = 0x890C;
    enum SIOCRTMSG = 0x890D;

    enum SIOCGIFNAME = 0x8910;
    enum SIOCSIFLINK = 0x8911;
    enum SIOCGIFCONF = 0x8912;
    enum SIOCGIFFLAGS = 0x8913;
    enum SIOCSIFFLAGS = 0x8914;
    enum SIOCGIFADDR = 0x8915;
    enum SIOCSIFADDR = 0x8916;
    enum SIOCGIFDSTADDR = 0x8917;
    enum SIOCSIFDSTADDR = 0x8918;
    enum SIOCGIFBRDADDR = 0x8919;
    enum SIOCSIFBRDADDR = 0x891a;
    enum SIOCGIFNETMASK = 0x891b;
    enum SIOCSIFNETMASK = 0x891c;
    enum SIOCGIFMETRIC = 0x891d;
    enum SIOCSIFMETRIC = 0x891e;
    enum SIOCGIFMEM = 0x891f;
    enum SIOCSIFMEM = 0x8920;
    enum SIOCGIFMTU = 0x8921;
    enum SIOCSIFMTU = 0x8922;
    enum SIOCSIFNAME = 0x8923;
    enum SIOCSIFHWADDR = 0x8924;
    enum SIOCGIFENCAP = 0x8925;
    enum SIOCSIFENCAP = 0x8926;
    enum SIOCGIFHWADDR = 0x8927;
    enum SIOCGIFSLAVE = 0x8929;
    enum SIOCSIFSLAVE = 0x8930;
    enum SIOCADDMULTI = 0x8931;
    enum SIOCDELMULTI = 0x8932;
    enum SIOCGIFINDEX = 0x8933;
    enum SIOGIFINDEX = SIOCGIFINDEX;
    enum SIOCSIFPFLAGS = 0x8934;
    enum SIOCGIFPFLAGS = 0x8935;
    enum SIOCDIFADDR = 0x8936;
    enum SIOCSIFHWBROADCAST = 0x8937;
    enum SIOCGIFCOUNT = 0x8938;

    enum SIOCGIFBR = 0x8940;
    enum SIOCSIFBR = 0x8941;

    enum SIOCGIFTXQLEN = 0x8942;
    enum SIOCSIFTXQLEN = 0x8943;

    enum SIOCDARP = 0x8953;
    enum SIOCGARP = 0x8954;
    enum SIOCSARP = 0x8955;

    enum SIOCDRARP = 0x8960;
    enum SIOCGRARP = 0x8961;
    enum SIOCSRARP = 0x8962;

    enum SIOCGIFMAP = 0x8970;
    enum SIOCSIFMAP = 0x8971;

    enum SIOCADDDLCI = 0x8980;
    enum SIOCDELDLCI = 0x8981;

    enum SIOCDEVPRIVATE = 0x89F0;

    enum SIOCPROTOPRIVATE = 0x89E0;

    int ioctl(int __fd, c_ulong __request, ...);
}
else version (OSX)
{
    int ioctl(int fildes, c_ulong request, ...);
}
else version (FreeBSD)
{
    int ioctl(int, c_ulong, ...);
}
else version (Solaris)
{
    int ioctl(int fildes, int request, ...);
}
else
{
    static assert(false, "Unsupported platform");
}
