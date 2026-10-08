foreach f [lsort [glob -nocomplain GP* GOPR*]] {    
    if {[regexp {^GP([0-9][0-9])([0-9][0-9][0-9][0-9])([.]...)$} $f dummy a b c]} {
        set newf GOPR${b}-$a$c
        file rename $f $newf
    } elseif {[regexp {^GOPR([0-9][0-9][0-9][0-9])([.]...)$} $f dummy a b]} {
        set newf GOPR${a}-00$b
        file rename $f $newf
    }
}
