
// Copyright (c) 2012 by Digital Mars
// All Rights Reserved
// written by David Held
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.
//---------------------------------------------------------------------------
#include <cppunit/extensions/HelperMacros.h>
#include <cppunit/ui/text/TestRunner.h>
#include "..\UTF.h"
//---------------------------------------------------------------------------
class UTFIsValidTest : public CppUnit::TestFixture
{
public:             // Tests
    void            testIsValidTooLarge()
    {
        CPPUNIT_ASSERT(!utf_isValidDchar(0x00201234));
    }

    void            testIsValidSurrogate()
    {
        CPPUNIT_ASSERT(!utf_isValidDchar(0xD900D800));
    }

    void            testIsValidNonCharacter1()
    {
        CPPUNIT_ASSERT(!utf_isValidDchar(0x03FFFE));
    }

    void            testIsValidNonCharacter2()
    {
        CPPUNIT_ASSERT(!utf_isValidDchar(0x00FDD9));
    }

    void            testIsValidPrivateUse1()
    {
        CPPUNIT_ASSERT(!utf_isValidDchar(0x00E123));
    }

    void            testIsValidPrivateUse2()
    {
        CPPUNIT_ASSERT(!utf_isValidDchar(0x0F1234));
    }

    void            testIsValidPrivateUse3()
    {
        CPPUNIT_ASSERT(!utf_isValidDchar(0x101234));
    }

    void            testIsValidASCII()
    {
        CPPUNIT_ASSERT(utf_isValidDchar('A'));
    }

    void            testIsValidNonASCII()
    {
        CPPUNIT_ASSERT(utf_isValidDchar(0x001234));
    }

public:             // Implementation
CPPUNIT_TEST_SUITE(UTFIsValidTest);
CPPUNIT_TEST(testIsValidTooLarge);
CPPUNIT_TEST(testIsValidSurrogate);
CPPUNIT_TEST(testIsValidNonCharacter1);
CPPUNIT_TEST(testIsValidNonCharacter2);
CPPUNIT_TEST(testIsValidPrivateUse1);
CPPUNIT_TEST(testIsValidPrivateUse2);
CPPUNIT_TEST(testIsValidPrivateUse3);
CPPUNIT_TEST(testIsValidASCII);
CPPUNIT_TEST(testIsValidNonASCII);
CPPUNIT_TEST_SUITE_END();
};
//---------------------------------------------------------------------------
class UTFDecodeTest : public CppUnit::TestFixture
{
public:             // Interface
    void            setUp()
    {
        i_ = 0;
        c_ = 0;
    }

public:             // Tests
    void            testDecodeCharASCII()
    {
        static utf8_t const VALUE[] = "X";
        CPPUNIT_ASSERT(utf_decodeChar(VALUE, sizeof(VALUE) - 1, &i_, &c_) == NULL);
        CPPUNIT_ASSERT_EQUAL(size_t(1), i_);
        CPPUNIT_ASSERT_EQUAL(dchar_t('X'), c_);
    }

    void            testDecodeCharOutsideCodeSpace()
    {
        static utf8_t const VALUE[] = { 0xF9, 0x81, 0x92, 0xA3, 0xB4, 0x00 };
        CPPUNIT_ASSERT_EQUAL(
            UTF8_DECODE_OUTSIDE_CODE_SPACE,
            utf_decodeChar(VALUE, sizeof(VALUE) - 1, &i_, &c_)
        );
    }

    void            testDecodeCharTruncatedSequence()
    {
        static utf8_t const VALUE[] = { 0xF0, 0x81, 0x92, 0xA3 };
        CPPUNIT_ASSERT_EQUAL(
            UTF8_DECODE_TRUNCATED_SEQUENCE,
            utf_decodeChar(VALUE, sizeof(VALUE) - 1, &i_, &c_)
        );
    }

    void            testDecodeCharOverlong()
    {
        static utf8_t const VALUE[] = { 0xC0, 0x81, 0x00 };
        CPPUNIT_ASSERT_EQUAL(
            UTF8_DECODE_OVERLONG,
            utf_decodeChar(VALUE, sizeof(VALUE) - 1, &i_, &c_)
        );
    }

    void            testDecodeCharInvalidTrailer()
    {
        static utf8_t const VALUE[] = { 0xC2, 0x23, 0x00 };
        CPPUNIT_ASSERT_EQUAL(
            UTF8_DECODE_INVALID_TRAILER,
            utf_decodeChar(VALUE, sizeof(VALUE) - 1, &i_, &c_)
        );
    }

    void            testDecodeCharInvalidCodePoint()
    {
        static utf8_t const VALUE[] = { 0xEF, 0xBF, 0xBF, 0x00 };
        CPPUNIT_ASSERT_EQUAL(
            UTF8_DECODE_INVALID_CODE_POINT,
            utf_decodeChar(VALUE, sizeof(VALUE) - 1, &i_, &c_)
        );
    }

    void            testDecodeChar2Byte()
    {
        static utf8_t const VALUE[] = { 0xD3, 0x93, 0x00 };
        CPPUNIT_ASSERT(
            utf_decodeChar(VALUE, sizeof(VALUE) - 1, &i_, &c_) == NULL
        );
        CPPUNIT_ASSERT_EQUAL(size_t(2), i_);
        CPPUNIT_ASSERT_EQUAL(dchar_t(0x04D3), c_);
    }

    void            testDecodeChar3Byte()
    {
        static utf8_t const VALUE[] = { 0xE3, 0x93, 0xA4, 0x00 };
        CPPUNIT_ASSERT(
            utf_decodeChar(VALUE, sizeof(VALUE) - 1, &i_, &c_) == NULL
        );
        CPPUNIT_ASSERT_EQUAL(size_t(3), i_);
        CPPUNIT_ASSERT_EQUAL(dchar_t(0x34E4), c_);
    }

    void            testDecodeChar4Byte()
    {
        static utf8_t const VALUE[] = { 0xF3, 0x93, 0xA4, 0xB5, 0x00 };
        CPPUNIT_ASSERT(
            utf_decodeChar(VALUE, sizeof(VALUE) - 1, &i_, &c_) == NULL
        );
        CPPUNIT_ASSERT_EQUAL(size_t(4), i_);
        CPPUNIT_ASSERT_EQUAL(dchar_t(0x0D3935), c_);
    }

private:            // Implementation
    size_t          i_;
    dchar_t         c_;

public:             // Implementation
CPPUNIT_TEST_SUITE(UTFDecodeTest);
CPPUNIT_TEST(testDecodeCharASCII);
CPPUNIT_TEST(testDecodeCharOutsideCodeSpace);
CPPUNIT_TEST(testDecodeCharTruncatedSequence);
CPPUNIT_TEST(testDecodeCharOverlong);
CPPUNIT_TEST(testDecodeCharInvalidTrailer);
CPPUNIT_TEST(testDecodeCharInvalidCodePoint);
CPPUNIT_TEST(testDecodeChar2Byte);
CPPUNIT_TEST(testDecodeChar3Byte);
CPPUNIT_TEST(testDecodeChar4Byte);
CPPUNIT_TEST_SUITE_END();
};
//---------------------------------------------------------------------------
int main()
{
    CppUnit::TextUi::TestRunner runner;
    runner.addTest(UTFIsValidTest::suite());
    runner.addTest(UTFDecodeTest::suite());
    return runner.run();
}
//---------------------------------------------------------------------------
