USING: help.markup help.syntax strings ;
IN: ip-parser

HELP: parse-ipv4
{ $values { "str" string } { "ip" string } }
{ $description "Parses an IP string that may not have all four address components specified, following these rules:" $nl
    { $table
        { { $snippet "A" } { $snippet "0.0.0.A" } }
        { { $snippet "A.D" } { $snippet "A.0.0.D" } }
        { { $snippet "A.B.D" } { $snippet "A.B.0.D" } }
        { { $snippet "A.B.C.D" } { $snippet "A.B.C.D" } }
    }
    $nl
    "In addition, this supports components specified as decimal, octal, hexadecimal, and mixed representations, as well as components specified larger than 255 by carry propagation."
} ;
