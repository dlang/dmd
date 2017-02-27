// opcodes
#define ASM 0
#define NOP 1
#define ESCAPE 2
    // 8 is to leave room for opcodes to be in the range 0 .. 255
    // probably better off moving them to the high byte rather than second byte
    #define ESCAPEmask   0xff
    #define ESClinnum   (0 << 8)
    #define ESCadjesp   (1 << 8)
    #define ESCadjfpu   (2 << 8)
    #define ESCdctor    (3 << 8)      // D object is constructed
    #define ESCddtor    (4 << 8)      // D object is destructed

// registers

// base pointer
#define BP    0
// stack pointer
#define SP    1
// status word
#define PSW   2
// stack
#define STACK 3

#define NUMGENREGS 2
#define NUMREGS 1

#define NOREG 3

// which register is used for PIC code?
#define PICREG BP

// masks
#define mBP    (1 << BP)
#define mPSW   (1 << PSW)
#define mSTACK (1 << STACK)

// used in several generic parts of the code still
#define mES  0

#define mLSW 0
#define mMSW 0

#define IDXREGS 0
#define XMMREGS 0

#define FLOATREGS_16 0
#define FLOATREGS2_16 0
#define DOUBLEREGS_16 0
#define BYTEREGS_INIT 0

#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
extern regm_t ALLREGS;
extern regm_t BYTEREGS;
#define ALLREGS_INIT            0
#define ALLREGS_INIT_PIC        0
#define BYTEREGS_INIT           0
#define BYTEREGS_INIT_PIC       0
#else
#define ALLREGS                 0
#define ALLREGS_INIT            ALLREGS
#undef BYTEREGS
#define BYTEREGS                0
#endif

struct code
{
    code* next;
    unsigned Iop;                           // opcode
    unsigned Iflags;
      // eliminate these?
      #define CFpc32      (1 << 0)          // PC relative 32 bit fixup
      #define CFselfrel   (1 << 1)          // if self-relative
      #define CFoff       (1 << 2)          // get offset of immediate value
      #define CFoffset64  (1 << 3)          // offset is 64 bits
      #define CFseg       (1 << 4)          // get segment of immediate value
      #define CFswitch    (1 << 5)          // kludge for switch table fixups

    unsigned char IFL1;                     // FLavors of 1st operands
    union evc IEV1;                         // 1st operand, if any
      #define IEVsym1     IEV1.sp.Vsym
      #define IEVdsym1    IEV1.dsp.Vsym
      #define IEVlsym1    IEV1.lab.Vsym

    void setReg(unsigned) {}

    bool isJumpOP() { return false; }

    void print() {}
};

