# The LiveScript parser is generated by [Jison](http://github.com/zaach/jison)
# from this grammar file. Jison is a bottom-up parser generator, similar in
# style to [Bison](http://www.gnu.org/software/bison), implemented in JavaScript.
# It can recognize [LALR(1), LR(0), SLR(1), and LR(1)](http://en.wikipedia.org/wiki/LR_grammar)
# type grammars. To create the Jison parser, we list the pattern to match
# on the left-hand side, and the action to take (usually the creation of syntax
# tree nodes) on the right. As the parser runs, it
# shifts tokens from our token stream, from left to right, and
# [attempts to match](http://en.wikipedia.org/wiki/Bottom-up_parsing)
# the token sequence against the rules below. When a match can be made, it
# reduces into the [nonterminal](http://en.wikipedia.org/wiki/Terminal_and_nonterminal_symbols)
# (the enclosing name at the top), and we proceed from there.
#
# If you run the `slake build:parser` command, Jison constructs a parse table
# from our rules and saves it into [lib/parser.js](../lib/parser.js).

# Jison DSL
# ---------

# Our handy DSL for Jison grammar generation, thanks to
# [Tim Caswell](http://github.com/creationix). For every rule in the grammar,
# we pass the pattern-defining string, the action to run, and extra options,
# optionally. If no action is specified, we simply pass the value of the
# previous nonterminal.
ditto = {}
last  = ''

o = (patterns, action, options) ->
  patterns.=trim()split /\s+/
  action &&= if action is ditto then last else
    "#action"
    .replace /^function\s*\(\)\s*\{\s*return\s*([\s\S]*);\s*\}/ '$$$$ = $1;'
    .replace /\b(?!Er)[A-Z][\w.]*/g \yy.$&
    .replace /\.L\(/g '$&yylineno, '
  [patterns, last := action or '', options]

# Grammatical Rules
# -----------------

# In all of the rules that follow, you'll see the name of the nonterminal as
# the key to a list of alternative matches. With each match's action, the
# dollar-sign variables are provided by Jison as references to the value of
# their numeric position, so in this rule:
#
#     "Expression MATH Expression"
#
# `$1` would be the value of the first _Expression_, `$2` would be the token
# value for the _MATH_ terminal, and `$3` would be the value of the second
# _Expression_.
bnf =
  # The types of things that can be accessed or called into.
  Chain:
    o \ID            -> Chain L Var $1
    o \Parenthetical -> Chain $1
    o \List          ditto
    o \STRNUM        -> Chain L Literal $1
    o \LITERAL       ditto

    o 'Chain DOT Key'  -> $1.add Index $3, $2, true
    o 'Chain DOT List' ditto

    o 'Chain CALL( ArgList OptComma )CALL' -> $1.add Call $3

    o 'Chain ?' -> Chain Existence $1.unwrap!

    o 'LET CALL( ArgList OptComma )CALL Block' -> Chain Call.let $3, $6

    o 'WITH Expression Block' -> Chain Call.block Fun([] $3), [$2] \.call

    o '[ Expression LoopHeads ]'  -> Chain new Parens $3.0.makeComprehension $2, $3.slice 1 
    o '{ [ ArgList OptComma ] LoopHeads }'
    , -> Chain new Parens $6.0.addObjComp!makeComprehension (L Arr $3), $6.slice 1

    o '( BIOP )'            -> Chain Binary $2
    o '( BIOP Expression )' -> Chain Binary $2, , $3
    o '( Expression BIOP )' -> Chain Binary $3,   $2

    o '( BIOPR )'
    , -> Chain if   \! is $2.charAt 0
               then Binary $2.slice(1) .invertIt!
               else Binary $2
    o '( BIOPR Expression )'
    , -> Chain if   \! is $2.charAt 0
               then Binary $2.slice(1), , $3 .invertIt!
               else Binary $2, , $3
    o '( Expression BIOPR )'
    , -> Chain if   \! is $3.charAt 0
               then Binary $3.slice(1), $2 .invertIt!   
               else Binary $3, $2

    o '( UNARY )'           -> Chain Unary $2
    o '( CREMENT )'         -> Chain Unary $2

    o '( BACKTICK Chain BACKTICK )'            -> Chain $3
    o '( Expression BACKTICK Chain BACKTICK )' -> Chain $4.add Call [$2]
    o '( BACKTICK Chain BACKTICK Expression )' 
    , -> Chain(Chain Var \__flip .add Call [$3]).flipIt!add Call [$5]

  # Array/Object
  List:
    o '[ ArgList    OptComma ]' -> L Arr $2
    o '{ Properties OptComma }' -> L Obj $2
    # Can be labeled to perform named destructuring.
    o '[ ArgList    OptComma ] LABEL' -> L Arr $2 .named $5
    o '{ Properties OptComma } LABEL' -> L Obj $2 .named $5

  # **Key** represents a property name, before `:` or after `.`.
  Key:
    o \KeyBase
    o \Parenthetical
  KeyBase:
    o \ID     -> L Key     $1
    o \STRNUM -> L Literal $1

  # **ArgList** is either the list of objects passed into a function call,
  # the parameter list of a function, or the contents of an array literal
  # (i.e. comma-separated expressions). Newlines work as well.
  ArgList:
    o ''                                                -> []
    o \Arg                                              -> [$1]
    o 'ArgList , Arg'                                   -> $1 +++ $3
    o 'ArgList OptComma NEWLINE Arg'                    -> $1 +++ $4
    o 'ArgList OptComma INDENT ArgList OptComma DEDENT' ditto
  Arg:
    o     \Expression
    o '... Expression' -> Splat $2
    o \...             -> Splat L(Arr!), true

  # An optional, trailing comma.
  OptComma:
    o ''
    o \,

  # A list of lines, separated by newlines or semicolons.
  Lines:
    o ''                   -> Block!
    o \Line                -> Block $1
    o 'Lines NEWLINE Line' -> $1.add $3
    o 'Lines NEWLINE'
  # A line of LiveScript can be either an expression, backcall, comment or
  # [yadayadayada](http://search.cpan.org/~tmtm/Yada-Yada-Yada-1.00/Yada.pm).
  Line:
    o \Expression

    o 'PARAM( ArgList OptComma )PARAM <- Expression'
    , -> Call.back $2, $6, $5 is \<~

    o 'EXPORT Exprs'                          -> Export $2
    o 'EXPORT INDENT ArgList OptComma DEDENT' -> Export $3

    o \COMMENT -> L JS $1, true true
    o \...     -> L Throw JS "Error('unimplemented')"

  # An indented block of expressions.
  # Note that [Lexer](#lexer) rewrites some single-line forms into blocks.
  Block:
    o 'INDENT Lines DEDENT' -> $2.chomp!
    ...

  # All the different types of expressions in our language.
  Expression:
    o 'Expression BACKTICK Chain BACKTICK Expression' -> $3.add Call [$1, $5]

    o \Chain -> $1.unwrap!

    o 'Chain ASSIGN Expression'
    , -> Assign $1.unwrap!, $3           , $2
    o 'Chain ASSIGN INDENT ArgList OptComma DEDENT'
    , -> Assign $1.unwrap!, Arr.maybe($4), $2

    o 'Expression IMPORT Expression'
    , -> Import $1, $3           , $2 is \<<<<
    o 'Expression IMPORT INDENT ArgList OptComma DEDENT'
    , -> Import $1, Arr.maybe($4), $2 is \<<<<

    o 'CREMENT Chain' -> Unary $1, $2.unwrap!
    o 'Chain CREMENT' -> Unary $2, $1.unwrap!, true

    o 'UNARY ASSIGN Chain' -> Assign $3.unwrap!, [$1] $2
    o '+-    ASSIGN Chain' ditto
    o 'CLONE ASSIGN Chain' ditto

    o 'UNARY Expression' -> Unary $1, $2
    o '+-    Expression' ditto, prec: \UNARY
    o 'CLONE Expression' ditto, prec: \UNARY
    o 'UNARY INDENT ArgList OptComma DEDENT' -> Unary $1, Arr.maybe $3

    o 'Expression +-      Expression' -> Binary $2, $1, $3
    o 'Expression COMPARE Expression' ditto
    o 'Expression LOGIC   Expression' ditto
    o 'Expression MATH    Expression' ditto
    o 'Expression POWER   Expression' ditto
    o 'Expression SHIFT   Expression' ditto
    o 'Expression BITWISE Expression' ditto
    o 'Expression CONCAT  Expression' ditto
    o 'Expression COMPOSE Expression' ditto

    o 'Expression RELATION Expression' ->
      *if \! is $2.charAt 0 then Binary $2.slice(1), $1, $3 .invert!
                            else Binary $2         , $1, $3

    o 'Expression PIPE     Expression' -> Block $1 .pipe $3, $2
    o 'Expression BACKPIPE Expression' ditto 

    o 'Chain !?' -> Existence $1.unwrap!, true

    # The function literal can be either anonymous with `->`,
    o 'PARAM( ArgList OptComma )PARAM -> Block' 
    , -> L Fun $2, $6, $5.charAt(0) is \~, $5 in <[ --> ~~> ]>
    # or named with `function`.
    o 'FUNCTION CALL( ArgList OptComma )CALL Block' -> L Fun($3, $6)named $1

    # The full complement of `if` and `unless` expressions,
    # including postfix one-liners.
    o \IfBlock
    o 'IfBlock ELSE Block'            -> $1.addElse $3
    o 'Expression POST_IF Expression' -> If $3, $1, $2 is \unless

    # Loops can either be normal with a block of expressions
    # to execute, postfix with a single expression, or postconditional.
    o 'LoopHead Block'            -> $1.addBody $2
    o 'LoopHead Block ELSE Block' -> $1.addBody $2 .addElse $4
    o 'DO Block WHILE Expression'
    , -> new While($4, $3 is \until, true)addBody $2

    # `return` or `throw`
    o 'HURL Expression'                     -> Jump[$1] $2
    o 'HURL INDENT ArgList OptComma DEDENT' -> Jump[$1] Arr.maybe $3
    o \HURL                                 -> L Jump[$1]!

    # `break` or `continue`
    o \JUMP     -> L new Jump $1
    o 'JUMP ID' -> L new Jump $1, $2

    o 'SWITCH Expression Cases'               -> new Switch $2, $3
    o 'SWITCH Expression Cases DEFAULT Block' -> new Switch $2, $3, $5
    o 'SWITCH Expression Cases ELSE    Block' -> new Switch $2, $3, $5
    o 'SWITCH            Cases'               -> new Switch null $2
    o 'SWITCH            Cases DEFAULT Block' -> new Switch null $2, $4
    o 'SWITCH            Cases ELSE    Block' -> new Switch null $2, $4
    o 'SWITCH                          Block' -> new Switch null [], $2

    o 'TRY Block'                           -> new Try $2
    o 'TRY Block CATCH Block'               -> new Try $2, $3, $4
    o 'TRY Block CATCH Block FINALLY Block' -> new Try $2, $3, $4, $6
    o 'TRY Block             FINALLY Block' -> new Try $2, null null $4

    o 'CLASS                          Block' -> new Class null        null $2
    o 'CLASS       EXTENDS Expression Block' -> new Class null        $3,  $4
    o 'CLASS Chain                    Block' -> new Class $2.unwrap!, null $3
    o 'CLASS Chain EXTENDS Expression Block' -> new Class $2.unwrap!, $4,  $5

    o 'Chain EXTENDS Expression' -> Util.Extends $1.unwrap!, $3

    o 'LABEL Expression' -> new Label $1, $2
    o 'LABEL Block'      ditto

    o '[ Expression TO Expression ]'
    , -> new Parens new For from: $2, op: $3, to: $4
    o '[ Expression TO Expression BY Expression ]'
    , -> new Parens new For from: $2, op: $3, to: $4, step: $6 

  # Keys and values.
  KeyValue:
    o \Key
    o \LITERAL -> Prop L(Key $1, $1 not in <[ arguments eval ]>), L Literal $1
    o 'Key     DOT KeyBase' -> Prop $3, Chain(          $1; [Index $3, $2])
    o 'LITERAL DOT KeyBase' -> Prop $3, Chain(L Literal $1; [Index $3, $2])
    o '{ Properties OptComma } LABEL' -> Prop L(Key $5), L(Obj $2 .named $5)
    o '[ ArgList    OptComma ] LABEL' -> Prop L(Key $5), L(Arr $2 .named $5)
  Property:
    o 'Key : Expression'                     -> Prop $1, $3
    o 'Key : INDENT ArgList OptComma DEDENT' -> Prop $1, Arr.maybe($4)

    o \KeyValue
    o 'KeyValue LOGIC Expression' -> Binary $2, $1, $3

    o '+- Key'     -> Prop $2.maybeKey!   , L Literal $1 is \+
    o '+- LITERAL' -> Prop L(Key $2, true), L Literal $1 is \+

    o '... Expression' -> Splat $2

    o \COMMENT -> L JS $1, true true
  # Properties within an object literal can be separated by
  # commas, as in JavaScript, or simply by newlines.
  Properties:
    o ''                                                      -> []
    o \Property                                               -> [$1]
    o 'Properties , Property'                                 -> $1 +++ $3
    o 'Properties OptComma NEWLINE Property'                  -> $1 +++ $4
    o 'INDENT Properties OptComma DEDENT'                     -> $2

  Parenthetical:
    o '( Body )' -> Parens $2.chomp!unwrap!, false, $1 is \"
    ...

  Body:
    o \Lines
    o \Block
    o 'Block NEWLINE Lines' -> $1.add $3

  # The most basic form of `if` is a condition and an action. The following
  # `if`-related rules are broken up along these lines to avoid ambiguity.
  IfBlock:
    o              'IF Expression Block' ->            If $2, $3, $1 is \unless
    o 'IfBlock ELSE IF Expression Block' -> $1.addElse If $4, $5, $3 is \unless

  LoopHead:
    # The source of a `for`-loop is an array, object, or range.
    # Unless it's iterating over an object, you can choose to step through
    # in fixed-size increments.
    o 'FOR Chain IN Expression'
    , -> new For item: $2.unwrap!, index: $3, source: $4
    o 'FOR Chain IN Expression CASE Expression'
    , -> new For item: $2.unwrap!, index: $3, source: $4, guard: $6
    o 'FOR Chain IN Expression BY Expression'
    , -> new For item: $2.unwrap!, index: $3, source: $4, step: $6
    o 'FOR Chain IN Expression BY Expression CASE Expression'
    , -> new For item: $2.unwrap!, index: $3, source: $4, step: $6, guard: $8

    o 'FOR     ID         OF Expression'
    , -> new For {+object,       index: $2,                   source: $4}
    o 'FOR     ID         OF Expression CASE Expression'
    , -> new For {+object,       index: $2,                   source: $4, guard: $6}
    o 'FOR     ID , Chain OF Expression'
    , -> new For {+object,       index: $2, item: $4.unwrap!, source: $6}
    o 'FOR     ID , Chain OF Expression CASE Expression'
    , -> new For {+object,       index: $2, item: $4.unwrap!, source: $6, guard: $8}
    o 'FOR OWN ID         OF Expression'
    , -> new For {+object, +own, index: $3,                   source: $5}
    o 'FOR OWN ID         OF Expression CASE Expression'
    , -> new For {+object, +own, index: $3,                   source: $5, guard: $8}
    o 'FOR OWN ID , Chain OF Expression'
    , -> new For {+object, +own, index: $3, item: $5.unwrap!, source: $7}
    o 'FOR OWN ID , Chain OF Expression CASE Expression'
    , -> new For {+object, +own, index: $3, item: $5.unwrap!, source: $7, guard: $8}

    o 'FOR ID FROM Expression TO Expression'
    , -> new For index: $2, from: $4, op: $5, to: $6
    o 'FOR ID FROM Expression TO Expression CASE Expression'
    , -> new For index: $2, from: $4, op: $5, to: $6, guard: $8
    o 'FOR ID FROM Expression TO Expression BY Expression'
    , -> new For index: $2, from: $4, op: $5, to: $6, step: $8
    o 'FOR ID FROM Expression TO Expression BY Expression CASE Expression'
    , -> new For index: $2, from: $4, op: $5, to: $6, step: $8, guard: $10
    o 'FOR ID FROM Expression TO Expression CASE Expression BY Expression'
    , -> new For index: $2, from: $4, op: $5, to: $6, guard: $8, step: $10

    o 'WHILE Expression'                 -> new While $2, $1 is \until
    o 'WHILE Expression CASE Expression' -> new While $2, $1 is \until .addGuard $4
    o 'WHILE Expression , Expression'    -> new While $2, $1 is \until, $4
    o 'WHILE Expression , Expression CASE Expression'
    , -> new While $2, $1 is \until, $4 .addGuard $6

  LoopHeads:
    o 'LoopHead'           -> [$1]
    o 'LoopHeads LoopHead' -> $1 +++ $2

  Cases:
    o       'CASE Exprs Block' -> [new Case $2, $3]
    o 'Cases CASE Exprs Block' -> $1 +++ new Case $3, $4

  Exprs:
    o         \Expression  -> [$1]
    o 'Exprs , Expression' -> $1 +++ $3

# Precedence and Associativity
# ----------------------------
# Following these rules is what makes
# `a + b * c` parse as `a + (b * c)` (rather than `(a + b) * c`),
# and `x = y = z` `x = (y = z)` (not `(x = y) = z`).
operators =
  # Listed from lower precedence.
  <[ left     PIPE POST_IF FOR WHILE ]>
  <[ right    BACKPIPE     ]>
  <[ right    , ASSIGN HURL EXTENDS INDENT SWITCH CASE TO BY LABEL ]>
  <[ right    LOGIC        ]>
  <[ left     BITWISE      ]>
  <[ right    COMPARE      ]>
  <[ left     RELATION     ]>
  <[ right    CONCAT       ]>
  <[ left     SHIFT IMPORT ]>
  <[ left     +-           ]>
  <[ left     MATH         ]>
  <[ right    UNARY        ]>
  <[ right    POWER        ]>
  <[ right    COMPOSE      ]>
  <[ nonassoc CREMENT      ]>
  <[ left     BACKTICK     ]>

# Wrapping Up
# -----------

# Process all of our rules and prepend resolutions, while recording all
# terminals (every symbol which does not appear as the name of a rule above)
# as `tokens`.
tokens = do
  for name, alts of bnf
    for alt in alts
      [token for token in alt.0 when token not of bnf]
.join ' '

bnf.Root = [[[\Body] 'return $$']]

# Finally, initialize the parser with the name of the root.
module.exports =
  new (require \jison)Parser {bnf, operators, tokens, startSymbol: \Root}
