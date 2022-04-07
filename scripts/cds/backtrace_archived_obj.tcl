# backtrace_archived_obj.tcl -- find out why an object is included in the CDS archived heap
# 
#
# Example:
#    https://bugs.openjdk.java.net/browse/JDK-8284336
#    We have an object 0x00000000b239c518 of type MethodHandleNatives$CallSiteContext
#    in the archived heap.
#
#
#    $ java -Xshare:dump -Xlog:cds+heap=trace:file=cds.heap.log:none:filesize=0
#    $ tclsh backtrace_archived_obj.tcl 0x00000000b239c518 < cds.heap.log
#    [  0] 0x00000000b239c518 java/lang/invoke/MethodHandleNatives$CallSiteContext
#    [  1] 0x00000000b239c3e8 jdk/internal/ref/CleanerImpl$PhantomCleanableRef::action
#    [  2] 0x00000000b239c418 jdk/internal/ref/CleanerImpl$PhantomCleanableRef::discovered
#    [  3] 0x00000000b2327f88 java/lang/ref/SoftReference::discovered
#    [  4] 0x00000000b2326550 jdk/internal/loader/ClassLoaders$BootClassLoader::resourceCache
#    [  5] 0x00000000b22ce610 jdk/internal/loader/ArchivedClassLoaders::bootLoader

while {![eof stdin]} {
    set line [gets stdin]
    if {[regexp {[(]([0-9]+)[)] updating} $line]} {
        continue
    }
    if {[regexp {\{(0x[0-9a-f]+)\} - klass: (.*)} $line dummy addr type]} {
        regsub -all ' $type "" type
        #puts "$addr $type"
        set typeof($addr) $type
        while {![eof stdin]} {
            set line [gets stdin]
            if {![regexp {^ } $line]} {
                break;
            }

            if {[regexp {^ - .* '(.*)' '.*' \@[0-9]+  a .*\{(0x[0-9a-f]+)\}} $line dummy field pointee]} {
                if {![info exists owner($pointee)]} {
                    set owner($pointee) $addr
                    set offsets($pointee) "\:\:$field"
                }
            } elseif {[regexp {^ - .* \@([0-9])+  a .*\{(0x[0-9a-f]+)\}} $line dummy offset pointee]} {
                #puts "  \[$offset\]  -> $pointee"
                if {![info exists owner($pointee)]} {
                    set owner($pointee) $addr
                    set offsets($pointee) \[$offset\]
                }
            }
        }
    }
}

foreach obj $argv {
    set level 0
    set offset ""
    while 1 {
        set type ""
        catch {
            set type $typeof($obj)
        }
        puts "\[[format %3d $level]\] $obj $type$offset"
        if {![info exists owner($obj)]} {
            break
        }
        incr level
        set offset ""
        catch {
            set offset $offsets($obj)
        }
        set obj $owner($obj)
    }
}
