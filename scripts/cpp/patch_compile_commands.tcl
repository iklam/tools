proc main {} {
    if {![file exists compile_commands.json]} {
        puts "compile_commands.json doesn't exist"
        exit 1
    }

    if {[file exists compile_commands.json.orig] &&
        [file mtime compile_commands.json.orig] < [file mtime compile_commands.json]} {
        puts "Already up to date"
    }

    # make sure timestamp is different
    #after 1100

    set in [open compile_commands.json]
    set out [open compile_commands.json.patched w+]
    while {![eof $in]} {
        set line [gets $in]
        if {[string first "\{ \"directory\":" $line] == 0} {
            puts $out "$line"
            maybe_add $out $line hpp
            maybe_add $out $line inline.hpp
        } else {
            puts $out "$line"
        }
    }

    close $in
    close $out

    file rename -force compile_commands.json compile_commands.json.orig
    file rename -force compile_commands.json.patched compile_commands.json
}

proc maybe_add {out line suffix} {
    set pat "(\[^ \]+/src/hotspot/\[^ \]+)\[.\]cpp"
    set pat1 "\"$pat\""
    set pat2 " $pat"
    if {[regexp $pat1 $line dummy stem]} {
        if {[file exists $stem.$suffix]} {
            regsub $pat1 $line \"$stem.$suffix\" line
            regsub $pat2 $line " $stem.$suffix" line

            global count
            incr count
            if {$count > 24300} {
                return
            }
            puts $out $line
        }
    }
}

main
puts $count

