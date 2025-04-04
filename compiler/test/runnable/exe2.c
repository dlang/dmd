/*_ exe2.c   Tue Sep  5 1989   Modified by: Walter Bright */
/* Check out operator precedence and control structures.        */
/* Check out cgelem.c                                           */

#include        <stdio.h>
#include        <math.h>
#include        <assert.h>
#include        <string.h>
#include        <stdlib.h>

void switches()
{       int a,b,c;

        a = 3;
        b = 2;
        switch(5)
        {       case 1:
                        assert(0);
                        break;
                case 2:
                        assert(0);
                        break;
                default:
                        b = 4;
                        break;
        }
        switch (a)
        {       b = 5;
        }
        assert(b == 4);
        switch (a)
        {       default:
                        a = 4;
        }
        assert(a == 4);
        switch (a)
        {       case 4:
                        a--;
                        break;
                default:
                        assert(0);
        }
        switch (a)
        {       case 3:
                case 4:
                        a++;
                        break;
        }
        assert(a == 4);
        switch (a)
        {       case 3:
                case 5:
                case 6:
                        assert(0);
                case 4:
                        break;
        }
        switch (a)
        {       case 47:
                case 146:
                case -9878:
                default:
                        assert(0);
                case 4:
                        break;
        }
        switch (3)
        {       case 1:
                case 2:
                default:
                        assert(0);
                case 3:
                        break;
        }
        switch (a)
        {       case 1:
                case 4:
                if (a == 4)
                        case 2:
                        break;
                else
                        default:
                        assert(0);
                case 3:
                        break;
        }
}

void bigswitch()
{
    int i;
    unsigned u;

    i=1231;
    switch ( i )
    {
        default: printf(" default case\n");  break;
        case 1231:  printf(" case 1\n");       return;
        case 2131:  printf(" case 2\n");       break;
        case 3222:  printf(" case 3\n");       break;
        case 4323:  printf(" case 4\n");       break;
        case 5423:  printf(" case 5\n");       break;
        case 6143:  printf(" case 6\n");       break;
        case 7234:  printf(" case 7\n");       break;
        case 8432:  printf(" case 8\n");       break;
        case 9432:  printf(" case 9\n");       break;
        case 1034:  printf(" case10\n");       break;
        case 1143:  printf(" case11\n");       break;
        case 1224:  printf(" case12\n");       break;
        case 1354:  printf(" case13\n");       break;
        case 1436:  printf(" case14\n");       break;
        case 1546:  printf(" case15\n");       break;
        case 1676:  printf(" case16\n");       break;
        case 1723:  printf(" case17\n");       break;
        case 1887:  printf(" case18\n");       break;
        case 1923:  printf(" case19\n");       break;
        case 2045:  printf(" case20\n");       break;
        case 2123:  printf(" case21\n");       break;
        case 2245:  printf(" case22\n");       break;
        case 2354:  printf(" case23\n");       break;
        case 2423:  printf(" case24\n");       break;
        case 2534:  printf(" case25\n");       break;
        case 2645:  printf(" case26\n");       break;
        case 2756:  printf(" case27\n");       break;
        case 2867:  printf(" case28\n");       break;
        case 2978:  printf(" case29\n");       break;
        case 3045:  printf(" case30\n");       break;
        case 3134:  printf(" case31\n");       break;
        case 3223:  printf(" case32\n");       break;
        case 3345:  printf(" case33\n");       break;
        case 3456:  printf(" case34\n");       break;
        case 3556:  printf(" case35\n");       break;
        case 3634:  printf(" case36\n");       break;
        case 3723:  printf(" case37\n");       break;
        case 3865:  printf(" case38\n");       break;
        case 3976:  printf(" case39\n");       break;
        case 4087:  printf(" case40\n");       break;
        case 4154:  printf(" case41\n");       break;
        case 4298:  printf(" case42\n");       break;
        case 4343:  printf(" case43\n");       break;
        case 4456:  printf(" case44\n");       break;
        case 4545:  printf(" case45\n");       break;
        case 4634:  printf(" case46\n");       break;
        case 4723:  printf(" case47\n");       break;
        case 4865:  printf(" case48\n");       break;
        case 4976:  printf(" case49\n");       break;
        case 5087:  printf(" case50\n");       break;
        case 5198:  printf(" case51\n");       break;
        case 5265:  printf(" case52\n");       break;
        case 5378:  printf(" case53\n");       break;
        case 5498:  printf(" case54\n");       break;
        case 5509:  printf(" case55\n");       break;
        case 5676:  printf(" case56\n");       break;
        case 5734:  printf(" case57\n");       break;
        case 5823:  printf(" case58\n");       break;
        case 5934:  printf(" case59\n");       break;
        case 6045:  printf(" case60\n");       break;
        case 6167:  printf(" case61\n");       break;
        case 6278:  printf(" case62\n");       break;
        case 6398:  printf(" case63\n");       break;
        case 6465:  printf(" case64\n");       break;
        case 6554:  printf(" case65\n");       break;
        case 6643:  printf(" case66\n");       break;
        case 6732:  printf(" case67\n");       break;
        case 6843:  printf(" case68\n");       break;
        case 6956:  printf(" case69\n");       break;
        case 7076:  printf(" case70\n");       break;
        case 7187:  printf(" case71\n");       break;
        case 7298:  printf(" case72\n");       break;
        case 7309:  printf(" case73\n");       break;
        case 7489:  printf(" case74\n");       break;
        case 7565:  printf(" case75\n");       break;
        case 7654:  printf(" case76\n");       break;
        case 7734:  printf(" case77\n");       break;
        case 7845:  printf(" case78\n");       break;
        case 7976:  printf(" case79\n");       break;
        case 8000:
        case 8001:
        case 8002:
        case 8003:
        case 8004:
        case 8005:
        case 8006:
        case 8007:
        case 8008:
        case 8009:
        case 8010:
        case 8011:
        case 8012:
        case 8013:
        case 8014:
        case 8015:
        case 8016:
        case 8017:
        case 8018:
        case 8019:
        case 8020:
        case 8021:
        case 8022:
        case 8023:
        case 8024:
        case 8025:
        case 8026:
        case 8027:
        case 8028:
        case 8029:
        case 8030:
        case 8031:
        case 8032:
        case 8033:
        case 8034:
        case 8035:
        case 8036:
        case 8037:
        case 8038:
        case 8039:
        case 8040:
        case 8041:
        case 8042:
        case 8043:
        case 8044:
        case 8045:
        case 8046:
        case 8047:
        case 8048:
        case 8049:
        case 8050:
        case 8051:
        case 8052:
        case 8053:
        case 8054:
        case 8055:
        case 8056:
        case 8057:
        case 8058:
        case 8059:
        case 8060:
        case 8061:
        case 8062:
        case 8063:
        case 8064:
        case 8065:
        case 8066:
        case 8067:
        case 8068:
        case 8069:
        case 8070:
        case 8071:
        case 8072:
        case 8073:
        case 8074:
        case 8075:
        case 8076:
        case 8077:
        case 8078:
        case 8079:
        case 8080:
        case 8081:
        case 8082:
        case 8083:
        case 8084:
        case 8085:
        case 8086:
        case 8087:
        case 8088:
        case 8089:
        case 8090:
        case 8091:
        case 8092:
        case 8093:
        case 8094:
        case 8095:
        case 8096:
        case 8097:
        case 8098:
        case 8099:
        case 8100:
        case 8101:
        case 8102:
        case 8103:
        case 8104:
        case 8105:
        case 8106:
        case 8107:
        case 8108:
        case 8109:
        case 8110:
        case 8111:
        case 8112:
        case 8113:
        case 8114:
        case 8115:
        case 8116:
        case 8117:
        case 8118:
        case 8119:
        case 8120:
        case 8121:
        case 8122:
        case 8123:
        case 8124:
        case 8125:
        case 8126:
        case 8127:
        case 8128:
        case 8129:
        case 8130:
        case 8131:
        case 8132:
        case 8133:
        case 8134:
        case 8135:
        case 8136:
        case 8137:
        case 8138:
        case 8139:
        case 8140:
        case 8141:
        case 8142:
        case 8143:
        case 8144:
        case 8145:
        case 8146:
        case 8147:
        case 8148:
        case 8149:
        case 8150:
        case 8151:
        case 8152:
        case 8153:
        case 8154:
        case 8155:
        case 8156:
        case 8157:
        case 8158:
        case 8159:
        case 8160:
        case 8161:
        case 8162:
        case 8163:
        case 8164:
        case 8165:
        case 8166:
        case 8167:
        case 8168:
        case 8169:
        case 8170:
        case 8171:
        case 8172:
        case 8173:
        case 8174:
        case 8175:
        case 8176:
        case 8177:
        case 8178:
        case 8179:
                        printf("other cases\n");
                        break;
    }
    assert(0);
}

/*******************************************/

void bigswitch2()
{
    int i;

    i = atoi("-1");
    switch (i)
    {
        case 0:
        case 1:
        case 2:
        case 3:
        case 4:
        case 5:
        case 6:
        case 7:
        case 8:
        case 9:
        case 10:
        case 11:
        case 12:
        case 13:
        case 14:
        case 15:
        case 16:
        case 17:
        case 18:
        case 19:
        case 20:
        case 21:
        case 22:
        case 23:
        case 24:
        case 25:
        case 26:
        case 27:
        case 28:
        case 29:
        case 30:
        case 31:
        case 32:
        case 33:
        case 34:
        case 35:
        case 36:
        case 37:
        case 38:
        case 39:
        case 40:
        case 41:
        case 42:
        case 43:
        case 44:
        case 45:
        case 46:
        case 47:
        case 48:
        case 49:
        case 50:
        case 51:
        case 52:
        case 53:
        case 54:
        case 55:
        case 56:
        case 57:
        case 58:
        case 59:
        case 60:
        case 61:
        case 62:
        case 63:
        case 64:
        case 65:
        case 66:
        case 67:
        case 68:
        case 69:
        case 70:
        case 71:
        case 72:
        case 73:
        case 74:
        case 75:
        case 76:
        case 77:
        case 78:
        case 79:
        case 80:
        case 81:
        case 82:
        case 83:
        case 84:
        case 85:
        case 86:
        case 87:
        case 88:
        case 89:
        case 90:
        case 91:
        case 92:
        case 93:
        case 94:
        case 95:
        case 96:
        case 97:
        case 98:
        case 99:
        case 100:
        case 101:
        case 102:
        case 103:
        case 104:
        case 105:
        case 106:
        case 107:
        case 108:
        case 109:
        case 110:
        case 111:
        case 112:
        case 113:
        case 114:
        case 115:
        case 116:
        case 117:
        case 118:
        case 119:
        case 120:
        case 121:
        case 122:
        case 123:
        case 124:
        case 125:
        case 126:
        case 127:
        case 128:
        case 129:
        case 130:
        case 131:
        case 132:
        case 133:
        case 134:
        case 135:
        case 136:
        case 137:
        case 138:
        case 139:
        case 140:
        case 141:
        case 142:
        case 143:
        case 144:
        case 145:
        case 146:
        case 147:
        case 148:
        case 149:
        case 150:
        case 151:
        case 152:
        case 153:
        case 154:
        case 155:
        case 156:
        case 157:
        case 158:
        case 159:
        case 160:
        case 161:
        case 162:
        case 163:
        case 164:
        case 165:
        case 166:
        case 167:
        case 168:
        case 169:
        case 170:
        case 171:
        case 172:
        case 173:
        case 174:
        case 175:
        case 176:
        case 177:
        case 178:
        case 179:
        case 180:
        case 181:
        case 182:
        case 183:
        case 184:
        case 185:
        case 186:
        case 187:
        case 188:
        case 189:
        case 190:
        case 191:
        case 192:
        case 193:
        case 194:
        case 195:
        case 196:
        case 197:
        case 198:
        case 199:
        case 200:
        case 201:
        case 202:
        case 203:
        case 204:
        case 205:
        case 206:
        case 207:
        case 208:
        case 209:
        case 210:
        case 211:
        case 212:
        case 213:
        case 214:
        case 215:
        case 216:
        case 217:
        case 218:
        case 219:
        case 220:
        case 221:
        case 222:
        case 223:
        case 224:
        case 225:
        case 226:
        case 227:
        case 228:
        case 229:
        case 230:
        case 231:
        case 232:
        case 233:
        case 234:
        case 235:
        case 236:
        case 237:
        case 238:
        case 239:
        case 240:
        case 241:
        case 242:
        case 243:
        case 244:
        case 245:
        case 246:
        case 247:
        case 248:
        case 249:
        case 250:
        case 251:
        case 252:
        case 253:
        case 254:
        case 255:
        case 256:
        case 257:
        case 258:
        case 259:
                assert(0);
        default:
                break;
    }
}

/*******************************************/
/* Test switch (long)   */

long testlsw1(long l)
{
    switch (l)
    {   case 0x10001:       l++;            break;
        case 0x10002:       l += 2;         break;
        case 0x10003:       l += 3;         break;
        case 0x24004:       l += 4;         break;
        default:            l += 5;         break;
    }
    return l;
}

long testlsw2(long l)
{
    switch (l)
    {   case 0x10001:       l++;            break;
        case 0x10002:       l += 2;         break;
        case 0x10003:       l += 3;         break;
        case 0x14004:       l += 4;         break;
        default:            l += 5;         break;
    }
    return l;
}

long testlsw3(long l)
{
    switch (l)
    {   case 0x10001:       l++;            break;
        case 0x10002:       l += 2;         break;
        case 0x10003:       l += 3;         break;
        case 0x10004:       l += 4;         break;
        default:            l += 5;         break;
    }
    return l;
}

long testlsw4(long l)
{
    switch (l)
    {   case -2:            l++;            break;
        case -1:            l += 2;         break;
        case 0:             l += 3;         break;
        case 1:             l += 4;         break;
        default:            l += 5;         break;
    }
    return l;
}

long testlsw5(long l)
{
    switch (l)
    {   case 0xFFFF:        l++;            break;
        case 0x10000:       l += 2;         break;
        case 0x10001:       l += 3;         break;
        case 0x10002:       l += 4;         break;
        default:            l += 5;         break;
    }
    return l;
}

long testlsw6(long l)
{
    switch (l)
    {   case 0x10001:       l++;            break;
        case 0x10002:       l += 2;         break;
        case 0x24004:       l += 4;         break;
        default:            l += 5;         break;
    }
    return l;
}

long testlsw7(long l)
{
    switch (l)
    {   case 0x10001:       l++;            break;
        case 0x10002:       l += 2;         break;
        case 0x14004:       l += 4;         break;
        default:            l += 5;         break;
    }
    return l;
}

void testlswitch()
{
        assert(testlsw1(0x10001) == 0x10002);
        assert(testlsw1(0x10002) == 0x10004);
        assert(testlsw1(0x24004) == 0x24004 + 4);
        assert(testlsw1(0) == 5);

        assert(testlsw2(0x10001) == 0x10002);
        assert(testlsw2(0x10002) == 0x10004);
        assert(testlsw2(0x14004) == 0x14004 + 4);
        assert(testlsw2(6) == 11);

        assert(testlsw3(0x10001) == 0x10002);
        assert(testlsw3(0x10002) == 0x10004);
        assert(testlsw3(0x10004) == 0x10004 + 4);
        assert(testlsw3(6) == 11);

        assert(testlsw4(-2) == -2 + 1);
        assert(testlsw4(-1) == -1 + 2);
        assert(testlsw4(0) == 0 + 3);
        assert(testlsw4(1) == 1 + 4);
        assert(testlsw4(6) == 11);

        assert(testlsw5(0xFFFF) == (long)0xFFFF + 1);
        assert(testlsw5(0x10000) == 0x10000 + 2);
        assert(testlsw5(0x10001) == 0x10001 + 3);
        assert(testlsw5(0x10002) == 0x10002 + 4);
        assert(testlsw5(6) == 11);

        assert(testlsw6(0x10001) == 0x10002);
        assert(testlsw6(0x10002) == 0x10004);
        assert(testlsw6(0x24004) == 0x24004 + 4);
        assert(testlsw6(0) == 5);

        assert(testlsw7(0x10001) == 0x10002);
        assert(testlsw7(0x10002) == 0x10004);
        assert(testlsw7(0x14004) == 0x14004 + 4);
        assert(testlsw7(6) == 11);
}

/*******************************************/

void cgelem()
{       int a,b;

        a = (37,38);
        assert(a == 38);
        b = (a,50);
        assert(b == 50);
        b = (50,a);
        assert(b == 38);
        {
            int         *i;
            int         j;

            j = 5;
            i = (int *)(-(long)j);
        }
}

/* The following is exe8.c with alignment       */

#define bug(text,name,p) {printf("\n%s name (%%p) = %p\n",("text"),(name));}

typedef struct {
    char var1[10];
    struct {
        char var2[2];
        char var3[3];
        char var4[4];
        char var5[5];
        char var6;
        } inner;
} TYPE1;

struct {
    char var1[10];
    struct {
        char var2[2];
        char var3[3];
        char var4[4];
#if c_plusplus
        typedef const volatile int asdkfj(const i);
#endif
        char var5[5];
        char var6;
        } inner;
} str2;

TYPE1 buf1, *buf1p = &buf1;
TYPE1 arr[3];

typedef union
{       char var[7];
} TYPE2;

TYPE2 buf2, *buf2p = &buf2;

void alignment()                /* always compiled without -a */
{
        TYPE1 *buf1p2;
        TYPE2 *buf2p2;

        bug(should be 26:,(void*)sizeof(TYPE1),d)
#if __INTSIZE == 4
        printf("TYPE1 = %d\n",sizeof(TYPE1));
        assert(sizeof(TYPE1) == 25);
#else
        assert(sizeof(TYPE1) == 25);
#endif

        buf1p2 = buf1p + 1;
        assert(buf1p2 == (TYPE1 *) ((char *) buf1p + sizeof(TYPE1)));
        buf1p2 = buf1p + sizeof(TYPE1);
        assert((buf1p2 - buf1p) == sizeof(TYPE1));

        buf2p2 = buf2p + 1;
        assert(buf2p2 == (TYPE2 *) ((char *) buf2p + sizeof(TYPE2)));
        buf2p2 = buf2p + sizeof(TYPE2);
        assert((buf2p2 - buf2p) == sizeof(TYPE2));

        bug(should be 1:,(void*)sizeof(buf1p->inner.var6),d)
        assert(sizeof(buf1p->inner.var6) == 1);

        bug(should be 10:,(void*)sizeof(buf1p->var1),d)
        assert(sizeof(buf1p->var1) == 10);
        bug(should be 1:,(void*)sizeof(buf1.var1[2]),d)
        assert(sizeof(buf1.var1[2]) == 1);
        bug(should be 10:,(void*)sizeof(str2.var1),d)
        assert(sizeof(str2.var1) == 10);

        bug(should be 5:,(void*)sizeof(buf1p->inner.var5),d)
        assert(sizeof(buf1p->inner.var5) == 5);
        bug(should be 1:,(void*)sizeof(*buf1.inner.var5),d)
        assert(sizeof(*buf1.inner.var5) == 1);
        bug(should be 5:,(void*)sizeof(str2.inner.var5),d)
        assert(sizeof(str2.inner.var5) == 5);

        /* ideally, this should be true to match hardware structs */
        bug(should be 78 when compiled without -a:,(void*)sizeof(arr),d)
        /*printf("%d\n",sizeof(arr));*/
#if __INTSIZE == 4
        assert(sizeof(arr) == 75);
#else
        assert(sizeof(arr) == 75);
#endif
}

void preprocessor()
{       int i = 0;
#if 1
        i = 3;
#elif 0
        assert(0);
#else
        assert(0);
#endif
        assert(i == 3);

#if 0
        assert(0);
#elif 1
        i = 4;
#else
        assert(0);
#endif
        assert(i == 4);

#if 0
        assert(0);
#elif 0
        assert(0);
#else
        i = 5;
#endif
        assert(i == 5);
}

/********** COMPILE-ONLY CODE *****************/

typedef struct linechg_
  { int                lineseen  : 1;
    int                firstchg  :15;
    int                lastchg;
  }    LINECHG;

struct welement_ { int a,b; };

typedef struct window_
  { struct welement_ **winmap;

    int                wm_top,
                       wm_left,
                       sw_top,
                       sw_left,
                       rows,
                       cols,
                       maxrows,
                       maxcols,
                       curs_row,
                       curs_col;
    char               def_atrb;
    struct window_    *owner,
                      *parent;
    struct linechg_   *line;
  }    WINDOW;

void scrollup(winptr,amt)
  WINDOW *winptr;
  int amt;
{
  LINECHG  *wline;
  int       row, maxrow, midrow,
            col, maxcol,
            top, left,
            moveamt;

  left         = winptr->sw_left;
  midrow       = winptr->rows;
  wline        = winptr->owner->line;

  for (row = 0; row < midrow; row++)
  { int x;
    memmove(&winptr->winmap[row+amt][left],&x,0);
    if (wline[row].firstchg > left)
      wline[row].firstchg = left;
  }
}

/***************** COMPILE-ONLY TESTS *******************/

int in_bug()
{
        return(0);
label:
        return(0);
        goto label;
}

#if 0 // doesn't work with ImportC
#ifndef __cplusplus
void proto1()
{       int proto2();

        /* this exposed bugs in automatic prototype generation  */
        proto2(proto2(1,2),3);
}


int proto2(a,b)
{
}
#endif
#endif

/* Bug in circular definition of unnamed struct. Happens during */
/* automatic prototype generation when function is called.      */
typedef struct {
        int (*tra_setfn)();

} TRANSACTION;

int vread(xdesc)
TRANSACTION *xdesc;
{
        (*(xdesc->tra_setfn))(xdesc);
}

/********* COMPILE ONLY ***********/

typedef int ValFunc(int *);
ValFunc *fptr;

typedef enum { a, b, } Type;
typedef enum { x, } asd;

/********* COMPILE ONLY ***********/

typedef struct
{
        char names[10][10];
} NAMES;

NAMES *xx;

void fooblah()
{   int i;
    if (i == 1 && xx->names[0])
        ++i;
}

/********* COMPILE ONLY ***********/

struct WBUF     {
        int a;
};

void dumpall()
{
        struct WBUF **wia;
        int i;

        if (wia[i] ++) {
                }
}

/********* COMPILE ONLY ***********/

int xread()
{       int total;

        (void) 0;
        return(total);
}

/********* COMPILE ONLY ***********/

int funxc(c)
unsigned char c;
{
}

int (*f)(int) = funxc;

/********* COMPILE ONLY ***********/

union two_halves {
  struct {
    unsigned rh,lh;
    } v1;
  } ;

union memory_word {
  union two_halves hh;
  } ;

union memory_word *n_mem(int x, ...)
{
}

void get_node()
{
  static unsigned q;
  static long t;
#define new_mem(x) (n_mem(x))
#define link(x) ((union two_halves *)new_mem(x))->v1.rh
#define info(x) ((union two_halves *)new_mem(x))->v1.lh
      link(((union two_halves *)new_mem(q + 1))->v1.lh + 1) = t;
      link(info(q + 1) + 1) = t;
  }

#undef new_mem
double new_mem();

/********* COMPILE ONLY ***********/

struct INT_DATA
{       int abc,def;
};

int funcdata(struct INT_DATA *pd)
{
        return 1;
}

/**************************************/

void testbyte(int x)
{
        if ((x & 0xFF) == 0)
                return;
        assert(0);
}

/**************************************/

void testbyte2(int x)
{       char c = x & 0xFF;

        if (c == 0)
                return;
        assert(0);
}

/**************************************/

char *mem_malloc()
{   static char abc[10];
    return abc;
}

void internal_symbol()
{
    char rmatrix[50];
    int msize = 0;
    char *r;

    r = (msize) ? mem_malloc() : rmatrix;
    assert(r == rmatrix);
}

/**************************************/

void testtrans()
{       long trans_gimage(long,int);
        long def;
        long abc = 0x12345678;

#if __INTSIZE == 2
        def = trans_gimage((long)(void *)(&abc) - 2,5);
        assert(def == abc);
#endif
}

long trans_gimage(tree, obj)
long    tree;
int     obj;
{       long    obspec;

#if __INTSIZE == 2
        obspec = (*(long *)(tree+2));
#endif
        return obspec;
}

/**************************************/

int abcdef;             /* tentative definition         */

void testinit()
{
        assert(abcdef == 5);
}

int abcdef = 5;

/**************************************/

void testautoinit()
{
        struct A { int a,b,c; };
        struct A a = { 4,5,6 };
        int i = { 1 };
        int array[3] = { 8,9,10 };

        assert(a.a == 4 && a.b == 5 && a.c == 6);
        assert(i == 1);
        assert(array[0] == 8 && array[1] == 9 && array[2] == 10);
}

/********* COMPILE ONLY ***********/

struct foo
{
        char *name;
        void (*dummy)();
};

void lollygag()
{
        ;
}

struct foo names[] =
{ {"lollygag",lollygag, },
  {"lollygag",lollygag },
  {"lollygag", },
  {"lollygag" },
  "lollygag",lollygag,
  0
};

/********* COMPILE ONLY ***********/

int dg_displaybox[4];
typedef struct ENTRY entry_t;
static entry_t *cmdline_entry;

void cmdline_msg(entry_t *e)
{   int clip[4];

    memcpy(clip,dg_displaybox,sizeof(int[4]));
}

void t_cursor_toggle()
{   static int on = 1;

    cmdline_msg(on ? 0L : cmdline_entry);
}

/********* COMPILE ONLY ***********/

void f2(work_out,p)
int *work_out;
char *p;
{
        long l;

#if __INTSIZE == 2
        l = (long)((char *)(work_out+45));
        *((char *) ((long) p + 0L)) = '\0';
#endif
}

/********* COMPILE ONLY ***********/

/* Linkage rules from ANSI C draft      */

int i1 = 1;
static int i2 = 2;
extern int i3 = 3;
int i4;
static int i5;

#if 0 // errors with ImportC
int i1;
/*int i2;*/     /* should generate error message        */
int i3;
int i4;
/*int i5;*/     /* should generate error message        */
#endif

#if 0 // errors with ImportC
extern int i1;
extern int i2;
extern int i3;
extern int i4;
extern int i5;
#endif

/********* COMPILE ONLY ***********/

/* Test short circuit evaluation in preprocessor        */
#define as 0
#if as != 0 && 4 / as
#endif
#if as == 0 || 4 / as
#endif
#if as ? 4 / as : 3
#endif
#if !as ? 3 : 4 / as
#endif

/********* COMPILE ONLY ***********/

typedef struct {
     char    ch;
     char    *ptr;
} THING;

THING *testasdfasd(ep, fp)
THING *ep, *fp;
{
     THING te[1];

     *te = *fp;
     *fp = *ep;
#ifndef __cplusplus
     *ep = *te;
#endif
     return ep;
}

/********* COMPILE ONLY ***********/

static void cb()
{
    unsigned *p;
    int i;

    (void)  ( p [(i >>  5 ) + 1] |= 1 <<  (i & 31) ) ;
}

/********* COMPILE ONLY ***********/

void junk() {}

void joes_bug(char *ptr, char cc)
{
  do
  {
    do
    {
      cc++;
    } while (!cc && ptr);
  } while (!cc && ptr);

  while (!cc)
    junk ();
}

/********* COMPILE ONLY ***********/

#if 0

#if __INTSIZE == 2 || __cplusplus
#define MK_FP(seg,offset) \
        ((void *)(((unsigned long)(seg)<<16) | (unsigned)(offset)))
#else
extern void *MK_FP(unsigned short,unsigned long);
#endif

void abuf(int i)
{
        char *fp = (char *)MK_FP(0xb800,0x0000);
        char *fp2 = (char *)MK_FP(0xb000,0x0000);

        for (i = 0; i < 100; i++)
        {
                fp2[i] = fp[i];
                *(fp + i + 1) = *(fp2 + i + 1);
        }

    {
        char *fp = (char *)MK_FP(0xb800,0x0000);
        fp[i] = 0;
    }
}

#endif

/***************************************/

void testc()
{       /* Had some trouble with elbitwise()    */
        struct TESTC
        {   struct TESTC *next;
            unsigned char a,b;
            signed char c,d;
        };

        struct TESTC c;
        struct TESTC *p;

        p = &c;
        c.next = 0;
        c.a = 0xF1;
        c.b = 0x7F;
        c.c = 0xF3;
        c.d = 0xD7;

        assert(p->a == 0xF1);
        assert((p->b & 0xF0) == 0x70);
        assert((p->c & 0xF0) == 0xF0);
        assert(p->c == (~0xF | 3));
}

/***************************************/

int main()
{
        int     a=3,b=2,c,d=1,e;
        int i;
        extern int exintg;

        printf("Test file '%s'\n",__FILE__);
        c = a > b ? a : b;
        assert(c == 3);

        e = d > c ? d : a < b ? a : b;
        assert(e == 2);
        if (e != 2)
                goto a;

        i = 0 ? a ^= 1 | 1 : 100;
        assert(i == 100);

        switches();
        bigswitch();
        testlswitch();
        cgelem();
        alignment();
        preprocessor();
        testbyte((int) 0xFF00);
        internal_symbol();
        testtrans();
        testinit();
        testautoinit();
        testc();
        printf("SUCCESS\n");
        exit(EXIT_SUCCESS);
a:      assert(0);
}
