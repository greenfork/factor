! Copyright (C) 2007 Chris Double.
! See http://factorcode.org/license.txt for BSD license.
USING: kernel sequences strings namespaces math assocs shuffle 
       vectors arrays combinators.lib math.parser match
       unicode.categories sequences.lib compiler.units parser
       words ;
IN: peg

TUPLE: parse-result remaining ast ;

SYMBOL: ignore 

: <parse-result> ( remaining ast -- parse-result )
  parse-result construct-boa ;

TUPLE: parser ;
C: <parser> parser
M: parser equal? eq? ;

: init-parser ( parser -- parser )
  #! Set the delegate for the parser
  <parser> over set-delegate ;

SYMBOL: compiled-parsers

GENERIC: (compile) ( parser -- quot )

: compiled-parser ( parser -- word )
  #! Look to see if the given parser has been compied.
  #! If not, compile it to a temporary word, cache it,
  #! and return it. Otherwise return the existing one.
  dup compiled-parsers get at [
    nip
  ] [
    dup (compile) define-temp 
    [ swap compiled-parsers get set-at ] keep
  ] if* ;

: compile ( parser -- word )
  H{ } clone compiled-parsers [ 
    [ compiled-parser ] with-compilation-unit 
  ] with-variable ;

: parse ( state parser -- result )
  compile call ;

<PRIVATE

TUPLE: token-parser symbol ;

MATCH-VARS: ?token ;

: token-pattern ( -- quot )
  [
    ?token 2dup head? [
      dup >r length tail-slice r> <parse-result>
    ] [
      2drop f
    ] if 
  ] ;
  
M: token-parser (compile) ( parser -- quot )
  token-parser-symbol \ ?token token-pattern match-replace ;
      
TUPLE: satisfy-parser quot ;

MATCH-VARS: ?quot ;

: satisfy-pattern ( -- quot )
  [
    dup empty? [
      drop f 
    ] [
      unclip-slice dup ?quot call [  
        <parse-result>
      ] [
        2drop f
      ] if
    ] if 
  ] ;

M: satisfy-parser (compile) ( parser -- quot )
  satisfy-parser-quot \ ?quot satisfy-pattern match-replace ;

TUPLE: range-parser min max ;

MATCH-VARS: ?min ?max ;

: range-pattern ( -- quot )
  [
    dup empty? [
      drop f
    ] [
      0 over nth dup 
      ?min ?max between? [
         [ 1 tail-slice ] dip <parse-result>
      ] [
        2drop f
      ] if
    ] if 
  ] ;

M: range-parser (compile) ( parser -- quot )
  T{ range-parser _ ?min ?max } range-pattern match-replace ;

TUPLE: seq-parser parsers ;

: seq-pattern ( -- quot )
  [
    dup [
      dup parse-result-remaining ?quot [
        [ parse-result-remaining swap set-parse-result-remaining ] 2keep
        parse-result-ast dup ignore = [ 
          drop  
        ] [ 
          swap [ parse-result-ast push ] keep 
        ] if
      ] [
        drop f 
      ] if*
    ] [
      drop f
    ] if  
  ] ;

M: seq-parser (compile) ( parser -- quot )
  [
    [ V{ } clone <parse-result> ] %
    seq-parser-parsers [ compiled-parser \ ?quot seq-pattern match-replace % ] each 
  ] [ ] make ;

TUPLE: choice-parser parsers ;

: choice-pattern ( -- quot )
  [
    dup [
          
    ] [
      drop dup ?quot 
    ] if
  ] ;

M: choice-parser (compile) ( parser -- quot )
  [
    f ,
    choice-parser-parsers [ compiled-parser \ ?quot choice-pattern match-replace % ] each
    \ nip ,
  ] [ ] make ;

TUPLE: repeat0-parser p1 ;

: (repeat0) ( quot result -- result )
  2dup parse-result-remaining swap call [
    [ parse-result-remaining swap set-parse-result-remaining ] 2keep 
    parse-result-ast swap [ parse-result-ast push ] keep
    (repeat0) 
 ] [
    nip
  ] if* ; inline

: repeat0-pattern ( -- quot )
  [
    [ ?quot ] swap (repeat0) 
  ] ;

M: repeat0-parser (compile) ( parser -- quot )
  [
    [ V{ } clone <parse-result> ] %
    repeat0-parser-p1 compiled-parser \ ?quot repeat0-pattern match-replace %        
  ] [ ] make ;

TUPLE: repeat1-parser p1 ;

: repeat1-pattern ( -- quot )
  [
    [ ?quot ] swap (repeat0) [
      dup parse-result-ast empty? [
        drop f
      ] when  
    ] [
      f 
    ] if*
  ] ;

M: repeat1-parser (compile) ( parser -- quot )
  [
    [ V{ } clone <parse-result> ] %
    repeat1-parser-p1 compiled-parser \ ?quot repeat1-pattern match-replace % 
  ] [ ] make ;

TUPLE: optional-parser p1 ;

: optional-pattern ( -- quot )
  [
    dup ?quot swap f <parse-result> or 
  ] ;

M: optional-parser (compile) ( parser -- quot )
  optional-parser-p1 compiled-parser \ ?quot optional-pattern match-replace ;

TUPLE: ensure-parser p1 ;

: ensure-pattern ( -- quot )
  [
    dup ?quot [
      ignore <parse-result>
    ] [
      drop f
    ] if
  ] ;

M: ensure-parser (compile) ( parser -- quot )
  ensure-parser-p1 compiled-parser \ ?quot ensure-pattern match-replace ;

TUPLE: ensure-not-parser p1 ;

: ensure-not-pattern ( -- quot )
  [
    dup ?quot [
      drop f
    ] [
      ignore <parse-result>
    ] if
  ] ;

M: ensure-not-parser (compile) ( parser -- quot )
  ensure-not-parser-p1 compiled-parser \ ?quot ensure-not-pattern match-replace ;

TUPLE: action-parser p1 quot ;

MATCH-VARS: ?action ;

: action-pattern ( -- quot )
  [
    ?quot dup [ 
      dup parse-result-ast ?action call
      swap [ set-parse-result-ast ] keep
    ] when 
  ] ;

M: action-parser (compile) ( parser -- quot )
  { action-parser-p1 action-parser-quot } get-slots [ compiled-parser ] dip 
  2array { ?quot ?action } action-pattern match-replace ;

: left-trim-slice ( string -- string )
  #! Return a new string without any leading whitespace
  #! from the original string.
  dup empty? [
    dup first blank? [ 1 tail-slice left-trim-slice ] when
  ] unless ;

TUPLE: sp-parser p1 ;

M: sp-parser (compile) ( parser -- quot )
  [
    \ left-trim-slice , sp-parser-p1 compiled-parser , 
  ] [ ] make ;

TUPLE: delay-parser quot ;

M: delay-parser (compile) ( parser -- quot )
  [
    delay-parser-quot % \ (compile) , \ call ,
  ] [ ] make ;

PRIVATE>

: token ( string -- parser )
  token-parser construct-boa init-parser ;      

: satisfy ( quot -- parser )
  satisfy-parser construct-boa init-parser ;

: range ( min max -- parser )
  range-parser construct-boa init-parser ;

: seq ( seq -- parser )
  seq-parser construct-boa init-parser ;

: 2seq ( parser1 parser2 -- parser )
  2array seq ;

: 3seq ( parser1 parser2 parser3 -- parser )
  3array seq ;

: 4seq ( parser1 parser2 parser3 parser4 -- parser )
  4array seq ;

: seq* ( quot -- paser )
  { } make seq ; inline 

: choice ( seq -- parser )
  choice-parser construct-boa init-parser ;

: 2choice ( parser1 parser2 -- parser )
  2array choice ;

: 3choice ( parser1 parser2 parser3 -- parser )
  3array choice ;

: 4choice ( parser1 parser2 parser3 parser4 -- parser )
  4array choice ;

: choice* ( quot -- paser )
  { } make choice ; inline 

: repeat0 ( parser -- parser )
  repeat0-parser construct-boa init-parser ;

: repeat1 ( parser -- parser )
  repeat1-parser construct-boa init-parser ;

: optional ( parser -- parser )
  optional-parser construct-boa init-parser ;

: ensure ( parser -- parser )
  ensure-parser construct-boa init-parser ;

: ensure-not ( parser -- parser )
  ensure-not-parser construct-boa init-parser ;

: action ( parser quot -- parser )
  action-parser construct-boa init-parser ;

: sp ( parser -- parser )
  sp-parser construct-boa init-parser ;

: hide ( parser -- parser )
  [ drop ignore ] action ;

: delay ( quot -- parser )
  delay-parser construct-boa init-parser ;

: PEG:
  (:) [
    [
        call compile
        [ dup [ parse-result-ast ] [ "Parse failed" throw ] if ]
        append define
    ] with-compilation-unit
  ] 2curry over push-all ; parsing
