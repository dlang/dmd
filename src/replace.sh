replacements=(
"PROTundefined undefined"
"PROTnone none"
"PROTprivate private_"
"PROTpackage package_"
"PROTprotected protected_"
"PROTpublic public_"
"PROTexport export_"
)

for r in "${replacements[@]}" ; do
    w=($r)
    sed "s/${w[0]}/Protection.${w[1]}/g" -i **/*.d
done
sed "s/PROTKIND/Protection/g" -i **/*.d
