proc get_pr_info {url} {
    set data [exec wget -q -O - $url]

    set root $url
    regsub {/pull/[0-9]*/files} $root "" root

    regsub {.*data-range-url="[^>]*/[$]range"} $data "" data
    regsub {.*data-range-url="[^>]*/[$]range"} $data "" data
    regsub {</details-menu>.*} $data "" data

    set commits {}

    set pat {href=\"([^\"]+)\"}
    while {[regexp $pat $data dummy commit]} {
        regsub .*/ $commit "" commit
        #puts $root/commit/$commit.diff
        if {![info exists firstrev]} {
            set firstrev $commit
        }
        set lastrev $commit
        regsub $pat $data xxx data
    }

    if {![info exists firstrev]} {
        return
    }

    # Find the parent of the first rev
    set firsturl $root/commit/$firstrev
    set data [exec wget -q -O - $firsturl]
    if {![regsub {.*[^0-9]1 parent} $data "" data]} {
        puts "Cannot handle multiple parent: $firsturl"
        exit 1
    }
    set data [string trim $data]
    if {![regexp {^<[^>]*href=\"[^>]*/([^/"]+)[^/]+\">} $data dummy parent]} {
        puts "Cannot find the parent of: $firsturl"
        exit 1
    }

    set diffurl $root/compare/${parent}..${lastrev}.diff

    puts $diffurl
}

set url [lindex $argv 0]
if {$url == ""} {
    set url https://github.com/openjdk/lilliput/pull/13/files
    puts "Using this for testing ... $url"
}

regsub {(pull/[0-9]*).*} $url \\1 url
append url /files

get_pr_info $url

# https://github.com/openjdk/lilliput/commit/0cafeb29c35b267b1b35e542e9834d32cc523ea8.diff
# https://github.com/openjdk/lilliput/compare/4390f5f0af1958d449cab79891bbaa9a4e0b71f1..0cafeb29c35b267b1b35e542e9834d32cc523ea8.diff
# https://github.com/openjdk/lilliput/compare/4390f5f0af1958d449cab79891bbaa9a4e0b71f1..da6c2272837d06d822db204173081ad600dd17c9.diff
