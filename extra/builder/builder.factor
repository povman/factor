
USING: kernel parser io io.files io.launcher io.sockets hashtables math threads
       arrays system continuations namespaces sequences splitting math.parser
       prettyprint tools.time calendar bake vars http.client
       combinators bootstrap.image bootstrap.image.download
       combinators.cleave benchmark
       classes strings quotations words parser-combinators new-slots accessors
       assocs.lib smtp builder.util ;

IN: builder

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: git-clone ( -- desc ) { "git" "clone" "../factor" } ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

VAR: stamp

: enter-build-dir ( -- )
  datestamp >stamp
  "/builds" cd
  stamp> make-directory
  stamp> cd ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: git-id ( -- id )
  { "git" "show" } <process-stream> [ readln ] with-stream " " split second ;

: record-git-id ( -- ) git-id "../git-id" [ . ] with-file-out ;

: make-clean ( -- desc ) { "make" "clean" } ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: target ( -- target ) { os [ cpu "." split ] } to-strings "-" join ;

: make-vm ( -- desc )
  <process*>
    { "make" target } to-strings >>arguments
    "../compile-log"             >>stdout
    +stdout+                     >>stderr
  >desc ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: factor-binary ( -- name )
  os
  { { "macosx" [ "./Factor.app/Contents/MacOS/factor" ] }
    { "winnt"  [ "./factor-nt.exe" ] }
    [ drop       "./factor" ] }
  case ;

: bootstrap-cmd ( -- cmd )
  { factor-binary [ "-i=" my-boot-image-name append ] "-no-user-init" }
  to-strings ;

: bootstrap ( -- desc )
  <process*>
    bootstrap-cmd >>arguments
    "../boot-log" >>stdout
    +stdout+      >>stderr
    20 minutes>ms >>timeout
  >desc ;

: builder-test ( -- desc ) { factor-binary "-run=builder.test" } to-strings ;
  
! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: (build) ( -- )

  enter-build-dir

  "report" [

    "Build machine:   " write host-name print
    "Build directory: " write cwd       print

    git-clone [ "git clone failed" print ] run-or-bail

    "factor" cd

    record-git-id

    make-clean run-process drop

    make-vm [ "vm compile error" print "../compile-log" cat ] run-or-bail

    [ my-arch download-image ] [ "Image download error" print throw ] recover

    ! bootstrap [ "Bootstrap error" print "../boot-log" cat ] run-or-bail

!     bootstrap
!       <process-stream> dup dispose process-stream-process wait-for-process
!     zero? not
!       [ "Bootstrap error" print "../boot-log" cat "bootstrap error" throw ]
!     when

    [
      bootstrap
        <process-stream> dup dispose process-stream-process wait-for-process
      zero? not
        [ "bootstrap non-zero" throw ]
      when
    ]
    [ "Bootstrap error" print "../boot-log" cat "bootstrap" throw ]
    recover
        
    [ builder-test try-process ]
    [ "Builder test error" print throw ]
    recover

    "Boot time: " write "../boot-time" eval-file milli-seconds>time print
    "Load time: " write "../load-time" eval-file milli-seconds>time print
    "Test time: " write "../test-time" eval-file milli-seconds>time print

    "Did not pass load-everything: " print "../load-everything-vocabs" cat
    "Did not pass test-all: "        print "../test-all-vocabs"        cat

    "Benchmarks: " print
    "../benchmarks" [ stdio get contents eval ] with-file-in benchmarks.

  ] with-file-out ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

SYMBOL: builder-recipients

: tag-subject ( str -- str ) { "builder@" host-name* ": " , } bake to-string ;

: build ( -- )
  [ (build) ] [ drop ] recover
  <email>
    "ed@factorcode.org"     >>from
    builder-recipients get  >>to
    "report" tag-subject    >>subject
    "../report" file>string >>body
  send ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: git-pull ( -- desc )
  {
    "git"
    "pull"
    "--no-summary"
    "git://factorcode.org/git/factor.git"
    "master"
  } ;

: updates-available? ( -- ? )
  git-id
  git-pull run-process drop
  git-id
  = not ;

: build-loop ( -- )
  [
    "/builds/factor" cd
    updates-available?
      [ build ]
    when
  ]
  [ drop ]
  recover
  5 minutes>ms sleep
  build-loop ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

MAIN: build-loop