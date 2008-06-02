! Copyright (C) 2006 Daniel Ehrenberg, Walton Chan
! See http://factorcode.org/license.txt for BSD license.
USING: http.client xml xml.utilities kernel sequences
namespaces http math.parser help math.order locals
urls accessors ;
IN: yahoo

TUPLE: result title url summary ;

C: <result> result
    
TUPLE: search query results adult-ok start appid region type
format similar-ok language country site subscription license ;

: parse-yahoo ( xml -- seq )
    "Result" deep-tags-named [
        { "Title" "Url" "Summary" }
        [ tag-named children>string ] with map
        first3 <result>
    ] map ;

: yahoo-url ( -- str )
    "http://search.yahooapis.com/WebSearchService/V1/webSearch" ;

: param ( search str quot -- search )
    >r over r> call [ url-encode [ % ] bi@ ] [ drop ] if* ;
    inline

: num-param ( search str quot -- search )
    [ dup [ number>string ] when ] compose param ; inline

: bool-param ( search str quot -- search )
    [ "1" and ] compose param ; inline

: query ( search -- url )
    [
        yahoo-url %     
        "?appid=" [ appid>> ] param
        "&query=" [ query>> ] param
        "&region=" [ region>> ] param
        "&type=" [ type>> ] param
        "&format=" [ format>> ] param
        "&language=" [ language>> ] param
        "&country=" [ country>> ] param
        "&site=" [ site>> ] param
        "&subscription=" [ subscription>> ] param
        "&license=" [ license>> ] param
        "&results=" [ results>> ] num-param
        "&start=" [ start>> ] num-param
        "&adult_ok=" [ adult-ok>> ] bool-param
        "&similar_ok=" [ similar-ok>> ] bool-param
        drop
    ] "" make ;

: factor-id
    "fRrVAKzV34GDyeRw6bUHDhEWHRedwfOC7e61wwXZLgGF80E67spxdQXuugBe2pgIevMmKwA-" ;

: <search> ( query -- search )
    search new
        factor-id >>appid
        10 >>results
        swap >>query ;

: search-yahoo ( search -- seq )
    query http-get string>xml parse-yahoo ;
