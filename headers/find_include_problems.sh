# find_include_problems.sh --
#
# This script can be used to find:
#
# [1] Missing includes:
#
#     A HotSpot source file should explicitly use #include "xxx/foo.hpp" if it uses
#     any symbols exported by this header. However, sometimes the #include is missing
#     because foo.hpp was indirectly included.
#
#     When the indirect inclusion disappear (because other header files are modified)
#     the source file will fail to compile.
#
#
# [2] Unnecessary includes:
#
#     A HotSpot source file uses #include "xxx/foo.hpp", but doesn't use any symbols
#     exported by this header
#
# USAGE:
#
# [a] Modify the bottom of the file to call "findthem" with required patterns.
#   
# [b] cd src/hotspot; bash /path/to/find_include_problems.sh




# $3 = <empty>:  print unnecessary includes
#      -m     :  print missing includes
function _findthem () {
    local a=$1
    local b=$2
    if test "$3" = "-m"; then
        a=$2
        b=$1
        echo "===== Missing includes ====="
    else
        echo "===== Unnecessary includes ====="
    fi

    for i in $(find . -name \*.\?pp | xargs egrep -l "$a"); do
        if egrep -q "$b" "$i"; then
            true
        else
            echo $i
        fi
    done
}


# $1 = name of the header file.
# $2 = regexp pattern for symbols exported by this header
function findthem () {
    _findthem $1 $2
    echo ""
    _findthem $1 $2 -m
}

#findthem 'arguments.hpp' 'Arguments::' $1
#findthem 'fieldInfo.hpp' '[^A-Za-z_]FieldInfo' $1
#findthem 'oopMap.hpp' 'OopMap' $1
findthem bytecodeHistogram.hpp '(BytecodeCounter)|(BytecodeHistogram)(BytecodePairHistogram)'
