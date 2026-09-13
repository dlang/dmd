/*
TEST_OUTPUT:
---
fail_compilation/enum_union_too_many_variants.d(8): Error: enum union cannot have more than 256 variants
---
*/

enum union TooMany
{
    case V0(), case V1(), case V2(), case V3(), case V4(), case V5(), case V6(), case V7(),
    case V8(), case V9(), case V10(), case V11(), case V12(), case V13(), case V14(), case V15(),
    case V16(), case V17(), case V18(), case V19(), case V20(), case V21(), case V22(), case V23(),
    case V24(), case V25(), case V26(), case V27(), case V28(), case V29(), case V30(), case V31(),
    case V32(), case V33(), case V34(), case V35(), case V36(), case V37(), case V38(), case V39(),
    case V40(), case V41(), case V42(), case V43(), case V44(), case V45(), case V46(), case V47(),
    case V48(), case V49(), case V50(), case V51(), case V52(), case V53(), case V54(), case V55(),
    case V56(), case V57(), case V58(), case V59(), case V60(), case V61(), case V62(), case V63(),
    case V64(), case V65(), case V66(), case V67(), case V68(), case V69(), case V70(), case V71(),
    case V72(), case V73(), case V74(), case V75(), case V76(), case V77(), case V78(), case V79(),
    case V80(), case V81(), case V82(), case V83(), case V84(), case V85(), case V86(), case V87(),
    case V88(), case V89(), case V90(), case V91(), case V92(), case V93(), case V94(), case V95(),
    case V96(), case V97(), case V98(), case V99(), case V100(), case V101(), case V102(), case V103(),
    case V104(), case V105(), case V106(), case V107(), case V108(), case V109(), case V110(), case V111(),
    case V112(), case V113(), case V114(), case V115(), case V116(), case V117(), case V118(), case V119(),
    case V120(), case V121(), case V122(), case V123(), case V124(), case V125(), case V126(), case V127(),
    case V128(), case V129(), case V130(), case V131(), case V132(), case V133(), case V134(), case V135(),
    case V136(), case V137(), case V138(), case V139(), case V140(), case V141(), case V142(), case V143(),
    case V144(), case V145(), case V146(), case V147(), case V148(), case V149(), case V150(), case V151(),
    case V152(), case V153(), case V154(), case V155(), case V156(), case V157(), case V158(), case V159(),
    case V160(), case V161(), case V162(), case V163(), case V164(), case V165(), case V166(), case V167(),
    case V168(), case V169(), case V170(), case V171(), case V172(), case V173(), case V174(), case V175(),
    case V176(), case V177(), case V178(), case V179(), case V180(), case V181(), case V182(), case V183(),
    case V184(), case V185(), case V186(), case V187(), case V188(), case V189(), case V190(), case V191(),
    case V192(), case V193(), case V194(), case V195(), case V196(), case V197(), case V198(), case V199(),
    case V200(), case V201(), case V202(), case V203(), case V204(), case V205(), case V206(), case V207(),
    case V208(), case V209(), case V210(), case V211(), case V212(), case V213(), case V214(), case V215(),
    case V216(), case V217(), case V218(), case V219(), case V220(), case V221(), case V222(), case V223(),
    case V224(), case V225(), case V226(), case V227(), case V228(), case V229(), case V230(), case V231(),
    case V232(), case V233(), case V234(), case V235(), case V236(), case V237(), case V238(), case V239(),
    case V240(), case V241(), case V242(), case V243(), case V244(), case V245(), case V246(), case V247(),
    case V248(), case V249(), case V250(), case V251(), case V252(), case V253(), case V254(), case V255(),
    case V256(),
}