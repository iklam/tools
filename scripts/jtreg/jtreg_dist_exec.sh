(
    #set -x
    # FIXME - use a local JDK ?
    export JAVA_HOME=$1
    shift

    # The source directory: run the test case in this dir 
    cd $1
    shift

    # The temporary test work dir when running jtreg on this machine
    workdir=$1
    shift
    mkdir -p $workdir

    # The directory on my main workstation to collect the execution results
    storedir=$1
    shift

    echo start $@
    time eval "$@" || failed=1
    if test "$failed" = "1"; then
        echo TEST_FAILED
    fi
    
    for i in "$@"; do
        testfile=$i
    done
    echo end
  time (
    datadir=$(echo $testfile | sed -e 's/[.]java#/_/' -e 's/[.]java$//')
    if test -f $workdir/$datadir.jtr; then
        mkdir -p $storedir/$datadir
        # Don't remove any files, in case rm -rf removes stuff from /!
        cp $workdir/$datadir.jtr $storedir/$datadir.jtr
        if test -d $workdir/$datadir; then
            (cd $workdir/$datadir/; tar cf - \
                                        --exclude='core.[0-9]*' \
                                        --exclude='*.cds' \
                                        --exclude='*.jsa' *) | \
                (cd $storedir/$datadir/; tar xf -)
            echo DATA_COPY_SUCCEED $storedir/$datadir 
            exit
        else 
            echo DATA_COPY_SUCCEEDED $workdir/$datadir.jtr only
            exit
        fi
    else
        echo DATA_COPY_FAILED $workdir/$datadir.jtr not found
    fi
    echo DATA_COPY_FAILED
  )
) 2>&1

exit
