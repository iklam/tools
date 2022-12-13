#! /bin/bash
# patch spec.gmk in the JDK build directory so that we can use jdkbuildhack.sh. See
# the latter file for details.
#

if test $(uname) != "Linux"; then
    exit 0
fi

mydir=$(dirname $0)
hacker=$mydir/jdkbuildhack.sh

for SPEC in spec hotspot-spec; do
    if test ! -f $SPEC.gmk; then
        continue
    fi
    if grep -q IOI_HACKER $SPEC.gmk; then
        echo $SPEC.gmk is patched
    else
        echo patching $SPEC.gmk
        script=
       #for i in CXX LDCXX BUILD_CXX BUILD_LDCXX CP; do
        for i in CXX LDCXX BUILD_CXX BUILD_LDCXX; do
      #for i in CP; do
            script="${script} -e s/^$i\\s*:=/$i:=\${IOI_HACKER}\${SPACE}${i}\nexport\\\\\nIOI_ORIG_${i}:=/g"
        done

        mv $SPEC.gmk $SPEC.gmk.old
        echo "IOI_HACKER:=$hacker" >> $SPEC.gmk.tmp
        cat $SPEC.gmk.old | (set -x; sed $script) >> $SPEC.gmk.tmp

        if [[ $(pwd) =~ productdebug$ || $(pwd) =~ pd$ ]]; then
            cat $SPEC.gmk.tmp | sed -e 's/-Wl,-O1/@@@/g' | sed -e 's/[-]O[0-9s]/-O0/g' | sed -e 's/@@@/-Wl,-O1 -Wl,-z,now/g' > $SPEC.gmk
            rm $SPEC.gmk.tmp
        else
            mv $SPEC.gmk.tmp  $SPEC.gmk
        fi

        touch -r $SPEC.gmk.old $SPEC.gmk
    fi
done
