#! /bin/bash
# patch spec.gmk in the JDK build directory so that we can use jdkbuildhack.sh. See
# the latter file for details.
#

if test $(uname) != "Linux"; then
    exit 0
fi

mydir=$(dirname $0)
hacker=$mydir/jdkbuildhack.sh

if grep -q IOI_HACKER spec.gmk; then
    echo spec.gmk is patched
else
    script=
   #for i in CXX LDCXX BUILD_CXX BUILD_LDCXX CP; do
    for i in CXX LDCXX BUILD_CXX BUILD_LDCXX; do
   #for i in CP; do
        script="${script} -e s/^$i\\s*:=/$i:=\${IOI_HACKER}\${SPACE}${i}\nexport\\\\\nIOI_ORIG_${i}:=/g"
    done
    mv spec.gmk spec.gmk.old
    echo "IOI_HACKER:=$hacker" >> spec.gmk.tmp
    cat spec.gmk.old | (set -x; sed $script) >> spec.gmk.tmp

    if [[ $(pwd) =~ productdebug$ || $(pwd) =~ pd$ ]]; then
        cat spec.gmk.tmp | sed -e 's/-Wl,-O1/@@@/g' | sed -e 's/[-]O[0-9s]/-O0/g' | sed -e 's/@@@/-Wl,-O1 -Wl,-z,now/g' > spec.gmk
        rm spec.gmk.tmp
    else
        mv spec.gmk.tmp  spec.gmk
    fi

    touch -r spec.gmk.old spec.gmk
fi
