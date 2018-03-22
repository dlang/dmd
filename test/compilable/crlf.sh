#!/usr/bin/env bash

# Test CRLF and mixed line ending handling in D lexer.


dir=${RESULTS_DIR}/compilable
fn=${TEST_DIR}/${TEST_NAME}.d

printf '%s\r\n' \
       '#!/usr/bin/env dmd -run' \
       '' \
       '#line 4' \
       '' \
       'void main()' \
       '{' \
       '}' \
       '' \
       '// single-line comment' \
       '' \
       '/*' \
       '  multi-line comment' \
       '*/' \
       '' \
       '/+' \
       '  nested comment' \
       '+/' \
       '' \
       '/**' \
       '  doc comment' \
       '*/' \
       'void documentee() {}' \
       > ${fn}

printf '// mixed\n// line\n// endings\n' >> ${fn}
printf 'void fun()\n{\n}\n' >> ${fn}

printf 'enum str = "\r\nfoo\r\nbar\nbaz\r\n";\n' >> ${fn}
printf 'static assert(str == "%s");\n' '\nfoo\nbar\nbaz\n' >> ${fn}

printf 'enum bstr = `\r\nfoo\r\nbar\nbaz\r\n`;\n' >> ${fn}
printf 'static assert(bstr == "%s");\n' '\nfoo\nbar\nbaz\n' >> ${fn}

printf 'enum wstr = q"EOF\r\nfoo\r\nbar\nbaz\r\nEOF";\n' >> ${fn}
printf 'static assert(wstr == "%s");\n' 'foo\nbar\nbaz\n' >> ${fn}

printf 'enum dstr = q"(\r\nfoo\r\nbar\nbaz\r\n)";\n' >> ${fn}
printf 'static assert(dstr == "%s");\n' '\nfoo\nbar\nbaz\n' >> ${fn}

$DMD -c -D -Dd${TEST_DIR} -m${MODEL} -of${TEST_DIR}/${TEST_NAME}a${OBJ} ${fn}

rm -f ${TEST_DIR}/${TEST_NAME}a${OBJ} ${TEST_DIR}/${TEST_NAME}.html ${fn}
