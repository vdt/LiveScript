var ditto, last, o, bnf, operators, name, alts, alt, token, tokens;
ditto = {};
last = '';
o = function(patterns, action, options){
  patterns = patterns.trim().split(/\s+/);
  action && (action = action === ditto
    ? last
    : (action + "").replace(/^function\s*\(\)\s*\{\s*return\s*([\s\S]*);\s*\}/, '$$$$ = $1;').replace(/\b(?!Er)[A-Z][\w.]*/g, 'yy.$&').replace(/\.L\(/g, '$&yylineno, '));
  return [patterns, last = action || '', options];
};
bnf = {
  Chain: [
    o('ID', function(){
      return Chain(L(Var($1)));
    }), o('Parenthetical', function(){
      return Chain($1);
    }), o('List', ditto), o('STRNUM', function(){
      return Chain(L(Literal($1)));
    }), o('LITERAL', ditto), o('Chain DOT Key', function(){
      return $1.add(Index($3, $2, true));
    }), o('Chain DOT List', ditto), o('Chain CALL( ArgList OptComma )CALL', function(){
      return $1.add(Call($3));
    }), o('Chain ?', function(){
      return Chain(Existence($1.unwrap()));
    }), o('LET CALL( ArgList OptComma )CALL Block', function(){
      return Chain(Call['let']($3, $6));
    }), o('WITH Expression Block', function(){
      return Chain(Call.block(Fun([], $3), [$2], '.call'));
    }), o('[ Expression LoopHeads ]', function(){
      return Chain(new Parens($3[0].makeComprehension($2, $3.slice(1))));
    }), o('{ [ ArgList OptComma ] LoopHeads }', function(){
      return Chain(new Parens($6[0].addObjComp().makeComprehension(L(Arr($3)), $6.slice(1))));
    }), o('( BIOP )', function(){
      return Chain(Binary($2));
    }), o('( BIOP Expression )', function(){
      return Chain(Binary($2, void 8, $3));
    }), o('( Expression BIOP )', function(){
      return Chain(Binary($3, $2));
    }), o('( BIOPR )', function(){
      return Chain('!' === $2.charAt(0)
        ? Binary($2.slice(1)).invertIt()
        : Binary($2));
    }), o('( BIOPR Expression )', function(){
      return Chain('!' === $2.charAt(0)
        ? Binary($2.slice(1), void 8, $3).invertIt()
        : Binary($2, void 8, $3));
    }), o('( Expression BIOPR )', function(){
      return Chain('!' === $3.charAt(0)
        ? Binary($3.slice(1), $2).invertIt()
        : Binary($3, $2));
    }), o('( UNARY )', function(){
      return Chain(Unary($2));
    }), o('( CREMENT )', function(){
      return Chain(Unary($2));
    }), o('( BACKTICK Chain BACKTICK )', function(){
      return Chain($3);
    }), o('( Expression BACKTICK Chain BACKTICK )', function(){
      return Chain($4.add(Call([$2])));
    }), o('( BACKTICK Chain BACKTICK Expression )', function(){
      return Chain(Chain(Var('__flip')).add(Call([$3]))).flipIt().add(Call([$5]));
    })
  ],
  List: [
    o('[ ArgList    OptComma ]', function(){
      return L(Arr($2));
    }), o('{ Properties OptComma }', function(){
      return L(Obj($2));
    }), o('[ ArgList    OptComma ] LABEL', function(){
      return L(Arr($2)).named($5);
    }), o('{ Properties OptComma } LABEL', function(){
      return L(Obj($2)).named($5);
    })
  ],
  Key: [o('KeyBase'), o('Parenthetical')],
  KeyBase: [
    o('ID', function(){
      return L(Key($1));
    }), o('STRNUM', function(){
      return L(Literal($1));
    })
  ],
  ArgList: [
    o('', function(){
      return [];
    }), o('Arg', function(){
      return [$1];
    }), o('ArgList , Arg', function(){
      return ($1).concat($3);
    }), o('ArgList OptComma NEWLINE Arg', function(){
      return ($1).concat($4);
    }), o('ArgList OptComma INDENT ArgList OptComma DEDENT', ditto)
  ],
  Arg: [
    o('Expression'), o('... Expression', function(){
      return Splat($2);
    }), o('...', function(){
      return Splat(L(Arr()), true);
    })
  ],
  OptComma: [o(''), o(',')],
  Lines: [
    o('', function(){
      return Block();
    }), o('Line', function(){
      return Block($1);
    }), o('Lines NEWLINE Line', function(){
      return $1.add($3);
    }), o('Lines NEWLINE')
  ],
  Line: [
    o('Expression'), o('PARAM( ArgList OptComma )PARAM <- Expression', function(){
      return Call.back($2, $6, $5 === '<~');
    }), o('EXPORT Exprs', function(){
      return Export($2);
    }), o('EXPORT INDENT ArgList OptComma DEDENT', function(){
      return Export($3);
    }), o('COMMENT', function(){
      return L(JS($1, true, true));
    }), o('...', function(){
      return L(Throw(JS("Error('unimplemented')")));
    })
  ],
  Block: [o('INDENT Lines DEDENT', function(){
    return $2.chomp();
  })],
  Expression: [
    o('Expression BACKTICK Chain BACKTICK Expression', function(){
      return $3.add(Call([$1, $5]));
    }), o('Chain', function(){
      return $1.unwrap();
    }), o('Chain ASSIGN Expression', function(){
      return Assign($1.unwrap(), $3, $2);
    }), o('Chain ASSIGN INDENT ArgList OptComma DEDENT', function(){
      return Assign($1.unwrap(), Arr.maybe($4), $2);
    }), o('Expression IMPORT Expression', function(){
      return Import($1, $3, $2 === '<<<<');
    }), o('Expression IMPORT INDENT ArgList OptComma DEDENT', function(){
      return Import($1, Arr.maybe($4), $2 === '<<<<');
    }), o('CREMENT Chain', function(){
      return Unary($1, $2.unwrap());
    }), o('Chain CREMENT', function(){
      return Unary($2, $1.unwrap(), true);
    }), o('UNARY ASSIGN Chain', function(){
      return Assign($3.unwrap(), [$1], $2);
    }), o('+-    ASSIGN Chain', ditto), o('CLONE ASSIGN Chain', ditto), o('UNARY Expression', function(){
      return Unary($1, $2);
    }), o('+-    Expression', ditto, {
      prec: 'UNARY'
    }), o('CLONE Expression', ditto, {
      prec: 'UNARY'
    }), o('UNARY INDENT ArgList OptComma DEDENT', function(){
      return Unary($1, Arr.maybe($3));
    }), o('Expression +-      Expression', function(){
      return Binary($2, $1, $3);
    }), o('Expression COMPARE Expression', ditto), o('Expression LOGIC   Expression', ditto), o('Expression MATH    Expression', ditto), o('Expression POWER   Expression', ditto), o('Expression SHIFT   Expression', ditto), o('Expression BITWISE Expression', ditto), o('Expression CONCAT  Expression', ditto), o('Expression COMPOSE Expression', ditto), o('Expression RELATION Expression', function(){
      return '!' === $2.charAt(0)
        ? Binary($2.slice(1), $1, $3).invert()
        : Binary($2, $1, $3);
    }), o('Expression PIPE     Expression', function(){
      return Block($1).pipe($3, $2);
    }), o('Expression BACKPIPE Expression', ditto), o('Chain !?', function(){
      return Existence($1.unwrap(), true);
    }), o('PARAM( ArgList OptComma )PARAM -> Block', function(){
      return L(Fun($2, $6, $5.charAt(0) === '~', $5 == '-->' || $5 == '~~>'));
    }), o('FUNCTION CALL( ArgList OptComma )CALL Block', function(){
      return L(Fun($3, $6).named($1));
    }), o('IfBlock'), o('IfBlock ELSE Block', function(){
      return $1.addElse($3);
    }), o('Expression POST_IF Expression', function(){
      return If($3, $1, $2 === 'unless');
    }), o('LoopHead Block', function(){
      return $1.addBody($2);
    }), o('LoopHead Block ELSE Block', function(){
      return $1.addBody($2).addElse($4);
    }), o('DO Block WHILE Expression', function(){
      return new While($4, $3 === 'until', true).addBody($2);
    }), o('HURL Expression', function(){
      return Jump[$1]($2);
    }), o('HURL INDENT ArgList OptComma DEDENT', function(){
      return Jump[$1](Arr.maybe($3));
    }), o('HURL', function(){
      return L(Jump[$1]());
    }), o('JUMP', function(){
      return L(new Jump($1));
    }), o('JUMP ID', function(){
      return L(new Jump($1, $2));
    }), o('SWITCH Expression Cases', function(){
      return new Switch($2, $3);
    }), o('SWITCH Expression Cases DEFAULT Block', function(){
      return new Switch($2, $3, $5);
    }), o('SWITCH Expression Cases ELSE    Block', function(){
      return new Switch($2, $3, $5);
    }), o('SWITCH            Cases', function(){
      return new Switch(null, $2);
    }), o('SWITCH            Cases DEFAULT Block', function(){
      return new Switch(null, $2, $4);
    }), o('SWITCH            Cases ELSE    Block', function(){
      return new Switch(null, $2, $4);
    }), o('SWITCH                          Block', function(){
      return new Switch(null, [], $2);
    }), o('TRY Block', function(){
      return new Try($2);
    }), o('TRY Block CATCH Block', function(){
      return new Try($2, $3, $4);
    }), o('TRY Block CATCH Block FINALLY Block', function(){
      return new Try($2, $3, $4, $6);
    }), o('TRY Block             FINALLY Block', function(){
      return new Try($2, null, null, $4);
    }), o('CLASS                          Block', function(){
      return new Class(null, null, $2);
    }), o('CLASS       EXTENDS Expression Block', function(){
      return new Class(null, $3, $4);
    }), o('CLASS Chain                    Block', function(){
      return new Class($2.unwrap(), null, $3);
    }), o('CLASS Chain EXTENDS Expression Block', function(){
      return new Class($2.unwrap(), $4, $5);
    }), o('Chain EXTENDS Expression', function(){
      return Util.Extends($1.unwrap(), $3);
    }), o('LABEL Expression', function(){
      return new Label($1, $2);
    }), o('LABEL Block', ditto), o('[ Expression TO Expression ]', function(){
      return new Parens(new For({
        from: $2,
        op: $3,
        to: $4
      }));
    }), o('[ Expression TO Expression BY Expression ]', function(){
      return new Parens(new For({
        from: $2,
        op: $3,
        to: $4,
        step: $6
      }));
    })
  ],
  KeyValue: [
    o('Key'), o('LITERAL', function(){
      return Prop(L(Key($1, $1 != 'arguments' && $1 != 'eval')), L(Literal($1)));
    }), o('Key     DOT KeyBase', function(){
      return Prop($3, Chain($1, [Index($3, $2)]));
    }), o('LITERAL DOT KeyBase', function(){
      return Prop($3, Chain(L(Literal($1)), [Index($3, $2)]));
    }), o('{ Properties OptComma } LABEL', function(){
      return Prop(L(Key($5)), L(Obj($2).named($5)));
    }), o('[ ArgList    OptComma ] LABEL', function(){
      return Prop(L(Key($5)), L(Arr($2).named($5)));
    })
  ],
  Property: [
    o('Key : Expression', function(){
      return Prop($1, $3);
    }), o('Key : INDENT ArgList OptComma DEDENT', function(){
      return Prop($1, Arr.maybe($4));
    }), o('KeyValue'), o('KeyValue LOGIC Expression', function(){
      return Binary($2, $1, $3);
    }), o('+- Key', function(){
      return Prop($2.maybeKey(), L(Literal($1 === '+')));
    }), o('+- LITERAL', function(){
      return Prop(L(Key($2, true)), L(Literal($1 === '+')));
    }), o('... Expression', function(){
      return Splat($2);
    }), o('COMMENT', function(){
      return L(JS($1, true, true));
    })
  ],
  Properties: [
    o('', function(){
      return [];
    }), o('Property', function(){
      return [$1];
    }), o('Properties , Property', function(){
      return ($1).concat($3);
    }), o('Properties OptComma NEWLINE Property', function(){
      return ($1).concat($4);
    }), o('INDENT Properties OptComma DEDENT', function(){
      return $2;
    })
  ],
  Parenthetical: [o('( Body )', function(){
    return Parens($2.chomp().unwrap(), false, $1 === '"');
  })],
  Body: [
    o('Lines'), o('Block'), o('Block NEWLINE Lines', function(){
      return $1.add($3);
    })
  ],
  IfBlock: [
    o('IF Expression Block', function(){
      return If($2, $3, $1 === 'unless');
    }), o('IfBlock ELSE IF Expression Block', function(){
      return $1.addElse(If($4, $5, $3 === 'unless'));
    })
  ],
  LoopHead: [
    o('FOR Chain IN Expression', function(){
      return new For({
        item: $2.unwrap(),
        index: $3,
        source: $4
      });
    }), o('FOR Chain IN Expression CASE Expression', function(){
      return new For({
        item: $2.unwrap(),
        index: $3,
        source: $4,
        guard: $6
      });
    }), o('FOR Chain IN Expression BY Expression', function(){
      return new For({
        item: $2.unwrap(),
        index: $3,
        source: $4,
        step: $6
      });
    }), o('FOR Chain IN Expression BY Expression CASE Expression', function(){
      return new For({
        item: $2.unwrap(),
        index: $3,
        source: $4,
        step: $6,
        guard: $8
      });
    }), o('FOR     ID         OF Expression', function(){
      return new For({
        object: true,
        index: $2,
        source: $4
      });
    }), o('FOR     ID         OF Expression CASE Expression', function(){
      return new For({
        object: true,
        index: $2,
        source: $4,
        guard: $6
      });
    }), o('FOR     ID , Chain OF Expression', function(){
      return new For({
        object: true,
        index: $2,
        item: $4.unwrap(),
        source: $6
      });
    }), o('FOR     ID , Chain OF Expression CASE Expression', function(){
      return new For({
        object: true,
        index: $2,
        item: $4.unwrap(),
        source: $6,
        guard: $8
      });
    }), o('FOR OWN ID         OF Expression', function(){
      return new For({
        object: true,
        own: true,
        index: $3,
        source: $5
      });
    }), o('FOR OWN ID         OF Expression CASE Expression', function(){
      return new For({
        object: true,
        own: true,
        index: $3,
        source: $5,
        guard: $8
      });
    }), o('FOR OWN ID , Chain OF Expression', function(){
      return new For({
        object: true,
        own: true,
        index: $3,
        item: $5.unwrap(),
        source: $7
      });
    }), o('FOR OWN ID , Chain OF Expression CASE Expression', function(){
      return new For({
        object: true,
        own: true,
        index: $3,
        item: $5.unwrap(),
        source: $7,
        guard: $8
      });
    }), o('FOR ID FROM Expression TO Expression', function(){
      return new For({
        index: $2,
        from: $4,
        op: $5,
        to: $6
      });
    }), o('FOR ID FROM Expression TO Expression CASE Expression', function(){
      return new For({
        index: $2,
        from: $4,
        op: $5,
        to: $6,
        guard: $8
      });
    }), o('FOR ID FROM Expression TO Expression BY Expression', function(){
      return new For({
        index: $2,
        from: $4,
        op: $5,
        to: $6,
        step: $8
      });
    }), o('FOR ID FROM Expression TO Expression BY Expression CASE Expression', function(){
      return new For({
        index: $2,
        from: $4,
        op: $5,
        to: $6,
        step: $8,
        guard: $10
      });
    }), o('FOR ID FROM Expression TO Expression CASE Expression BY Expression', function(){
      return new For({
        index: $2,
        from: $4,
        op: $5,
        to: $6,
        guard: $8,
        step: $10
      });
    }), o('WHILE Expression', function(){
      return new While($2, $1 === 'until');
    }), o('WHILE Expression CASE Expression', function(){
      return new While($2, $1 === 'until').addGuard($4);
    }), o('WHILE Expression , Expression', function(){
      return new While($2, $1 === 'until', $4);
    }), o('WHILE Expression , Expression CASE Expression', function(){
      return new While($2, $1 === 'until', $4).addGuard($6);
    })
  ],
  LoopHeads: [
    o('LoopHead', function(){
      return [$1];
    }), o('LoopHeads LoopHead', function(){
      return ($1).concat($2);
    })
  ],
  Cases: [
    o('CASE Exprs Block', function(){
      return [new Case($2, $3)];
    }), o('Cases CASE Exprs Block', function(){
      return ($1).concat(new Case($3, $4));
    })
  ],
  Exprs: [
    o('Expression', function(){
      return [$1];
    }), o('Exprs , Expression', function(){
      return ($1).concat($3);
    })
  ]
};
operators = [['left', 'PIPE', 'POST_IF', 'FOR', 'WHILE'], ['right', 'BACKPIPE'], ['right', ',', 'ASSIGN', 'HURL', 'EXTENDS', 'INDENT', 'SWITCH', 'CASE', 'TO', 'BY', 'LABEL'], ['right', 'LOGIC'], ['left', 'BITWISE'], ['right', 'COMPARE'], ['left', 'RELATION'], ['right', 'CONCAT'], ['left', 'SHIFT', 'IMPORT'], ['left', '+-'], ['left', 'MATH'], ['right', 'UNARY'], ['right', 'POWER'], ['right', 'COMPOSE'], ['nonassoc', 'CREMENT'], ['left', 'BACKTICK']];
tokens = (function(){
  var __ref, __i, __ref1, __len, __j, __ref2, __len1, __results = [];
  for (name in __ref = bnf) {
    alts = __ref[name];
    for (__i = 0, __len = (__ref1 = alts).length; __i < __len; ++__i) {
      alt = __ref1[__i];
      for (__j = 0, __len1 = (__ref2 = alt[0]).length; __j < __len1; ++__j) {
        token = __ref2[__j];
        if (!(token in bnf)) {
          __results.push(token);
        }
      }
    }
  }
  return __results;
}()).join(' ');
bnf.Root = [[['Body'], 'return $$']];
module.exports = new (require('jison')).Parser({
  bnf: bnf,
  operators: operators,
  tokens: tokens,
  startSymbol: 'Root'
});