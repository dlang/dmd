#!/usr/bin/env bash

GREP="$(command -v grep)"

# grep -q can exit with a 141 on early exits
function grep() {
    cat - | "$GREP" "$1" > /dev/null 2>&1
}

################################################################################
# -check
################################################################################

for w in "check" "check=" ; do
    output="$(! $DMD "-${w}" 2>&1)"
    echo "$output" | grep "Enable or disable specific checks:"
    echo "$output" | grep "=on                   Enable all assertion checking"
    echo "$output" | grep "Error: \`-check=<action>\` requires an action"
done

for w in "check=?" "check=h" "check=help" ; do
    output="$($DMD "-${w}")"
    echo "$output" | grep "Enable or disable specific checks:"
done

output="$(! $DMD -check=foo 2>&1)"
echo "$output" | grep "Error: Switch \`-check=foo\` is invalid"
echo "$output" | grep "Enable or disable specific checks:"
echo "$output" | grep "=on                   Enable all assertion checking"

output="$(! $DMD -checkf 2>&1)"
echo "$output" | grep "Error: unrecognized switch '-checkf'"

################################################################################
# -checkaction
################################################################################

for w in "checkaction" "checkaction=" ; do
    output="$(! $DMD "-${w}" 2>&1)"
    echo "$output" | grep "Behavior on assert/boundscheck/finalswitch failure:"
    echo "$output" | grep "=D             Usual D behavior of throwing an AssertError"
    echo "$output" | grep "Error: \`-check=<behavior>\` requires a behavior"
done


for w in "checkaction=?" "checkaction=h" "checkaction=help" ; do
    output="$($DMD "-${w}")"
    echo "$output" | grep "Behavior on assert/boundscheck/finalswitch failure:"
done

output="$(! $DMD -checkaction=foo 2>&1)"
echo "$output" | grep "Error: Switch \`-checkaction=foo\` is invalid"
echo "$output" | grep "Behavior on assert/boundscheck/finalswitch failure:"
echo "$output" | grep "=D             Usual D behavior of throwing an AssertError"

output="$(! $DMD -checkactionf 2>&1)"
echo "$output" | grep "Error: unrecognized switch '-checkactionf'"

################################################################################
# -mcpu
################################################################################

for w in "mcpu" "mcpu=" ; do
    output="$(! $DMD "-${w}" 2>&1)"
    echo "$output" | grep "CPU architectures supported by -mcpu=id:"
    echo "$output" | grep "=avx           use AVX 1 instructions"
    echo "$output" | grep "Error: \`-mcpu=<architecture>\` requires an architecture"
done

for w in "mcpu=?" "mcpu=h" "mcpu=help" ; do
    output="$($DMD "-${w}")"
    echo "$output" | grep "CPU architectures supported by -mcpu=id:"
    echo "$output" | grep "=avx           use AVX 1 instructions"
done

output="$(! $DMD -mcpu=foo 2>&1)"
echo "$output" | grep "Error: Switch \`-mcpu=foo\` is invalid"
echo "$output" | grep "CPU architectures supported by -mcpu=id:"
echo "$output" | grep "=avx           use AVX 1 instructions"

output="$(! $DMD -mcpuf 2>&1)"
echo "$output" | grep "Error: unrecognized switch '-mcpuf'"

################################################################################
# -transition
################################################################################

for w in "transition" "transition=" ; do
    output="$(! $DMD "-${w}" 2>&1)"
    echo "$output" | grep "Language transitions listed by -transition=name:"
    echo "$output" | grep "=vmarkdown        list instances of Markdown replacements in Ddoc"
    echo "$output" | grep "Error: \`-transition=<name>\` requires a name"
done

for w in "transition=?" "transition=h" "transition=help" ; do
    output="$($DMD "-${w}")"
    echo "$output" | grep "Language transitions listed by -transition=name:"
    echo "$output" | grep "=vmarkdown        list instances of Markdown replacements in Ddoc"
done

output="$(! $DMD -transition=foo 2>&1)"
echo "$output" | grep "Error: Transition \`-transition=foo\` is invalid"
echo "$output" | grep "Language transitions listed by -transition=name:"
echo "$output" | grep "=vmarkdown        list instances of Markdown replacements in Ddoc"

output="$(! $DMD -transition=123 2>&1)"
echo "$output" | grep "Error: Transition \`-transition=123\` is invalid"
echo "$output" | grep "Language transitions listed by -transition=name:"
echo "$output" | grep "=vmarkdown        list instances of Markdown replacements in Ddoc"

output="$(! $DMD -transitionf 2>&1)"
echo "$output" |  grep "Error: unrecognized switch '-transitionf'"

################################################################################
# -color
################################################################################

output="$(! $DMD -color=foo 2>&1)"
echo "$output" | grep "Error: Switch \`-color=foo\` is invalid"
echo "$output" | grep "Available options for \`-color\` are \`on\`, \`off\` and \`auto\`"

################################################################################
# -extern-std
################################################################################

for w in "extern-std" "extern-std=" ; do
    output="$(! $DMD "-${w}" 2>&1)"
    echo "$output" | grep "Available C++ standards:"
    echo "$output" | grep "=c++98                Sets \`__traits(getTargetInfo, \"cppStd\")\` to \`199711\`"
    echo "$output" | grep "Error: \`-extern-std=<standard>\` requires a standard"
done

for w in "extern-std=?" "extern-std=h" "extern-std=help" ; do
    output="$($DMD "-${w}")"
    echo "$output" | grep "Available C++ standards:"
    echo "$output" | grep "=c++98                Sets \`__traits(getTargetInfo, \"cppStd\")\` to \`199711\`"
done

output="$(! $DMD -extern-std=foo 2>&1)"
echo "$output" | grep "Error: Switch \`-extern-std=foo\` is invalid"
echo "$output" | grep "Available C++ standards:"
echo "$output" | grep "=c++98                Sets \`__traits(getTargetInfo, \"cppStd\")\` to \`199711\`"

################################################################################
# -profile
################################################################################

output="$(! $DMD -profile=foo 2>&1)"
echo "$output" | grep "Error: Switch \`-profile=foo\` is invalid"
echo "$output" | grep "Only \`gc\` is allowed for \`-profile\`"

################################################################################
# -cov
################################################################################

output="$(! $DMD -cov=foo 2>&1)"
echo "$output" | grep "Error: Switch \`-cov=foo\` is invalid"
echo "$output" | grep "Only a number can be passed to \`-cov=<num>\`"

################################################################################
# -verrors
################################################################################

output="$(! $DMD -verrors=foo 2>&1)"
echo "$output" | grep "Error: Switch \`-verrors=foo\` is invalid"
echo "$output" | grep "Only number, \`spec\`, or \`context\` are allowed for \`-verrors\`"
