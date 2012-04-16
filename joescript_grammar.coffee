{Grammar} = require './joeson'
{red, blue, cyan, magenta, green, normal, black, white, yellow} = require './colors'
{clazz} = require 'cardamom'
assert = require 'assert'

Node = clazz 'Node'
Word = clazz 'Word', Node, ->
  init: (@word) ->
  toString: -> @word
Block = clazz 'Block', Node, ->
  init: (lines) ->
    @lines = if lines instanceof Array then lines else [lines]
  toString: ->
    (''+line for line in @lines).join '\n'
  toStringWithIndent: ->
    '\n  '+((''+line).replace(/\n/g, '\n  ') for line in @lines).join('\n  ')+'\n'
If = clazz 'If', Node, ->
  init: ({@cond, @block, @else}) ->
    @block = Block @block if @block not instanceof Block
  toString: ->
    if @else?
      "if(#{@cond}){#{@block}}else{#{@else}}"
    else
      "if(#{@cond}){#{@block}}"
For = clazz 'For', Node, ->
  init: ({@block, @own, @keys, @type, @obj, @cond}) ->
  toString: -> "for #{@own? and 'own ' or ''}#{@keys.join ','} #{@type} #{@obj} #{@cond? and "when #{@cond} " or ''}{#{@block}}"
While = clazz 'While', Node, ->
  init: ({@cond, @block}) -> @cond ?= true
  toString: -> "while(#{@cond}){#{@block}}"
Switch = clazz 'Switch', Node, ->
  init: ({@obj, @cases, @default}) ->
  toString: -> "switch(#{@obj}){#{@cases.join('//')}//else{#{@default}}}"
Try = clazz 'Try', Node, ->
  init: ({@block, @doCatch, @catchVar, @catchBlock, @finally}) ->
  toString: -> "try{#{@block}}#{
                @doCatch and "catch(#{@catchVar or ''}){#{@catchBlock}}" or ''}#{
                @finally and "finally{#{@finally}}" or ''}"
Case = clazz 'Case', Node, ->
  init: ({@matches, @block}) ->
  toString: -> "when #{@matches.join ','}{#{@block}}"
Operation = clazz 'Operation', Node, ->
  init: ({@left, @not, @op, @right}) ->
  toString: -> "(#{@left or ''} #{@not and 'not ' or ''}#{@op} #{@right or ''})"
Statement = clazz 'Statement', Node, ->
  init: ({@type, @expr}) ->
  toString: -> "#{@type}(#{@expr ? ''});"
Invocation = clazz 'Invocation', Node, ->
  init: ({@func, @params}) ->
  toString: -> "#{@func}(#{@params.map((p)->"#{p}#{p.splat and '...' or ''}")})"
Assign = clazz 'Assign', Node, ->
  init: ({@target, @type, @value}) ->
  toString: -> "#{@target}#{@type}(#{@value})"
Slice = clazz 'Slice', Node, ->
  init: ({@obj, @range}) ->
  toString: -> "#{@obj}[#{@range}]"
Index = clazz 'Index', Node, ->
  init: ({obj, attr, type}) ->
    type ?= '.'
    if type is '::'
      if attr?
        obj = Index obj:obj, attr:'prototype', type:'.'
      else
        attr = 'prototype'
      type = '.'
    @obj = obj
    @attr = attr
    @type = type
  toString: ->
    close = if @type is '[' then ']' else ''
    "(#{@obj})#{@type}#{@attr}#{close}"
Soak = clazz 'Soak', Node, ->
  init: (@obj) ->
  toString: -> "(#{@obj})?"
Obj = clazz 'Obj', Node, ->
  init: (@items) ->
  toString: -> "{#{@items.join ','}}"
This = clazz 'This', Node, ->
  init: ->
  toString: -> "@"
Arr = clazz 'Arr', Obj, ->
  toString: -> "[#{@items.join ','}]"
Item = clazz 'Item', Node, ->
  init: ({@key, @value}) ->
  toString: -> @key+(if @value?   then ":(#{@value})"   else '')
Str = clazz 'Str', Node, ->
  init: (@parts) ->
  toString: ->
    parts = @parts.map (x) ->
      if x instanceof Node
        '#{'+x+'}'
      else
        x.replace /"/g, "\\\""
    '"' + parts.join('') + '"'
Func = clazz 'Func', Node, ->
  init: ({@params, @type, @block}) ->
  toString: -> "(#{if @params then @params.map(
      (p)->"#{p}#{p.splat and '...' or ''}#{p.default and '='+p.default or ''}"
    ).join ',' else ''})#{@type}{#{@block}}"
Range = clazz 'Range', Node, ->
  init: ({@start, @type, @end, @by}) ->
    @by ?= 1
  toString: -> "Range(#{@start? and "start:#{@start}," or ''}"+
                     "#{@end?   and "end:#{@end},"     or ''}"+
                     "type:'#{@type}', by:#{@by})"
Heredoc = clazz 'Heredoc', Node, ->
  init: (@text) ->
  toString: -> "####{@text}###"
Dummy = clazz 'Dummy', Node, ->
  init: (@args) ->
  toString: -> "{#{@args}}"

@NODES = {
  Node, Word, Block, If, For, While, Switch, Try, Case, Operation,
  Statement, Invocation, Assign, Slice, Index, Soak, Obj, This,
  Arr, Item, Str, Func, Range, Heredoc, Dummy
}

debugIndent = yes

checkIndent = (ws) ->
  @storeCache = no
  @stack[0].indent ?= '' # set default lazily

  container = @stack[@stack.length-2]
  @log "[In] container (@#{@stack.length-2}:#{container.name}) indent:'#{container.indent}', softline:'#{container.softline}'" if debugIndent
  # get the parent container's indent string
  for i in [@stack.length-3..0] by -1
    if @stack[i].softline? or @stack[i].indent?
      pContainer = @stack[i]
      pIndent = pContainer.softline ? pContainer.indent
      @log "[In] parent pContainer (@#{i}:#{pContainer.name}) indent:'#{pContainer.indent}', softline:'#{pContainer.softline}'" if debugIndent
      break
  # if ws starts with pIndent... valid
  if ws.length > pIndent.length and ws.indexOf(pIndent) is 0
    @log "Setting container.indent to '#{ws}'"
    container.indent = ws
    return container.indent
  null

checkNewline = (ws) ->
  @storeCache = no
  @stack[0].indent ?= '' # set default lazily

  # find the container INDENT on the stack
  for i in [@stack.length-2..0] by -1
    if @stack[i].softline? or @stack[i].indent?
      container = @stack[i]
      break

  containerIndent = container.softline ? container.indent
  isNewline = ws is containerIndent
  @log "[NL] container (@#{i}:#{container.name}) indent:'#{container.indent}', softline:'#{container.softline}', isNewline:'#{isNewline}'" if debugIndent
  return ws if isNewline
  null

# like a newline, but allows additional padding
checkSoftline = (ws) ->
  @storeCache = no
  @stack[0].indent ?= '' # set default lazily

  # find the applicable indent
  container = null
  for i in [@stack.length-2..0] by -1
    if i < @stack.length-2 and @stack[i].softline?
      # a strict ancestor's container's softline acts like an indent.
      # this allows softlines to be shortened only within the same direct container.
      container = @stack[i]
      @log "[SL] (@#{i}:#{container.name}) indent(ignored):'#{container.indent}', **softline**:'#{container.softline}'" if debugIndent
      break
    else if @stack[i].indent?
      container = @stack[i]
      @log "[SL] (@#{i}:#{container.name}) **indent**:'#{container.indent}', softline(ignored):'#{container.softline}'" if debugIndent
      break
  if container is null
    throw new Error "QWE"
  # commit softline ws to container
  if ws.indexOf(container.softline ? container.indent) is 0
    topContainer = @stack[@stack.length-2]
    @log "[SL] Setting topmost container (@#{@stack.length-2}:#{topContainer.name})'s softline to '#{ws}'"
    topContainer.softline = ws
    return ws
  null

checkComma = ({beforeBlanks, beforeWS, afterBlanks, afterWS}) ->
  @storeCache = no
  if afterBlanks.length > 0
    return null if checkSoftline.call(this, afterWS) is null
  else if beforeBlanks.length > 0
    return null if checkSoftline.call(this, beforeWS) is null
  ','

resetIndent = (ws) ->
  @storeCache = no
  @stack[0].indent ?= '' # set default lazily
  # find any container
  container = @stack[@stack.length-2]
  assert.ok container?
  @log "setting container(=#{container.name}).indent to '#{ws}'"
  container.indent = ws
  return container.indent

@GRAMMAR = Grammar ({o, i, tokens}) -> [
  o "__INIT__ LINES __EXIT__ _"
  i __INIT__:                     "_BLANKLINE*", -> # init code
  i __EXIT__:                     "_BLANKLINE*", -> # exit code
  i LINES:                        "LINE*_NEWLINE", Block
  i LINE: [
    o HEREDOC:                    "_ '###' !'#' (!'###' .)* '###'", (it) -> Heredoc it.join ''
    o POSTIF:                     "block:(POSTIF|POSTFOR) &:(POSTIF_IF|POSTIF_UNLESS)"
    i POSTIF_IF:                  "_IF cond:EXPR", If
    i POSTIF_UNLESS:              "_UNLESS cond:EXPR", ({cond}) -> If cond:Operation(op:'not', right:cond)
    o POSTFOR: [
      o                           "block:STMT _FOR own:_OWN? keys:SYMBOL*_COMMA{1,2} type:(_IN|_OF) obj:EXPR (_WHEN cond:EXPR)?", For
      o STMT: [
        o                         "type:(_RETURN|_THROW) expr:EXPR? | type:_BREAK", Statement
        o EXPR: [
          o FUNC:                 "params:PARAMS? _ type:('->'|'=>') block:BLOCK?", Func
          i PARAMS:               "_ '(' (&:PARAM default:(_ '=' EXPR)?)*_COMMA _ ')'"
          i PARAM:                "&:SYMBOL splat:'...'?
                                  |&:PROPERTY splat:'...'?
                                  |OBJ_EXPL
                                  |ARR_EXPL"
          o RIGHT_RECURSIVE: [
            o INVOC_IMPL:         "func:(ASSIGNABLE|_TYPEOF) params:(&:EXPR splat:'...'?)+_COMMA", Invocation
            o OBJ_IMPL:           "_INDENT? OBJ_IMPL_ITEM+(_COMMA|_NEWLINE)
                                   | OBJ_IMPL_ITEM+_COMMA", Obj
            i OBJ_IMPL_ITEM:      "key:(WORD|STRING) _ ':' value:EXPR", Item
            o ASSIGN:             "target:ASSIGNABLE _ type:('='|'+='|'-='|'*='|'/='|'?='|'||=') value:BLOCKEXPR", Assign
          ]
          o COMPLEX: [
            o IF:                 "_IF cond:EXPR block:BLOCK ((_NEWLINE | _INDENT)? _ELSE else:BLOCK)?", If
            o FOR:                "_FOR own:_OWN? keys:SYMBOL*_COMMA{1,2} type:(_IN|_OF) obj:EXPR (_WHEN cond:EXPR)? block:BLOCK", For
            o LOOP:               "_LOOP block:BLOCK", While
            o WHILE:              "_WHILE cond:EXPR block:BLOCK", While
            o SWITCH:             "_SWITCH obj:EXPR _INDENT cases:CASE*_NEWLINE default:DEFAULT?", Switch
            i CASE:               "_WHEN matches:EXPR+_COMMA block:BLOCK", Case
            i DEFAULT:            "_NEWLINE _ELSE BLOCK"
            o TRY:                "_TRY block:BLOCK
                                   (_NEWLINE? doCatch:_CATCH catchVar:EXPR? catchBlock:BLOCK?)?
                                   (_NEWLINE? _FINALLY finally:BLOCK)?", Try
          ]
          o OP_OPTIMIZATION:      "OP40 _ !(OP00_OP|OP10_OP|OP20_OP|OP30_OP)"
          o OP00: [
            i OP00_OP:            " '==' | '!=' | '<=' | '<' | '>=' | '>' | _IS | _ISNT "
            o                     "left:(OP00|OP10) _ op:OP00_OP _SOFTLINE? right:OP10", Operation
            o OP10: [
              i OP10_OP:          "not:_NOT? op:(_IN|_INSTANCEOF)"
              o                   "left:(OP10|OP20) _ @:OP10_OP  _SOFTLINE? right:OP20", Operation
              o OP20: [
                i OP20_OP:        " '+' | '-' | _OR | '?' "
                o                 "left:(OP20|OP30) _ op:OP20_OP _SOFTLINE? right:OP30", Operation
                o OP30: [
                  i OP30_OP:      " '*' | '/' | '%' | '&' | '&&' | _AND "
                  o               "left:(OP30|OP40) _ op:OP30_OP _SOFTLINE? right:OP40", Operation
                  o OP40: [
                    i OP40_OP:    " _NOT | '!' | '~' "
                    o             "_ op:OP40_OP right:OP50", Operation
                    o OP50: [
                      i OP50_OP:  " '--' | '++' "
                      o           "left:OPATOM op:OP50_OP", Operation
                      o           "_ op:OP50_OP right:OPATOM", Operation
                      o OPATOM:   "FUNC | RIGHT_RECURSIVE | COMPLEX | ASSIGNABLE"
                    ] # end OP50
                  ] # end OP40
                ] # end OP30
              ] # end OP20
            ] # end OP10
          ] # end OP00
        ] # end EXPR
      ] # end STMT
    ] # end POSTFOR
  ] # end LINE

  o ASSIGNABLE: [
    # left recursive
    o SLICE:        "obj:ASSIGNABLE !__ range:RANGE", Slice
    o INDEX0:       "obj:ASSIGNABLE type:'['  attr:EXPR _ ']'", Index
    o INDEX1:       "obj:ASSIGNABLE type:'.'  attr:WORD", Index
    o PROTO:        "obj:ASSIGNABLE type:'::' attr:WORD?", Index
    o INVOC_EXPL:   "func:(ASSIGNABLE|_TYPEOF) '(' ___ params:(&:EXPR splat:'...'?)*_COMMA ___ ')'", Invocation
    o SOAK:         "ASSIGNABLE '?'", Soak
    # rest
    o RANGE:        "_ '[' start:EXPR? _ type:('...'|'..') end:EXPR? _ ']' by:(_BY EXPR)?", Range
    o ARR_EXPL:     "_ '[' ___ (&:EXPR splat:'...'?)*(_COMMA|_SOFTLINE) ___ ']'", Arr
    o OBJ_EXPL: [
      o             "_ '{' ___ OBJ_EXPL_ITEM*_COMMA ___ '}'", Obj
      i OBJ_EXPL_ITEM: "key:(PROPERTY|WORD|STRING) value:(_ ':' EXPR)?", Item
    ]
    o PARENT:       "_ '(' POSTFOR _ ')'"
    o PROPERTY:     "_ '@' (WORD|STRING)", (attr) -> Index obj:This(), attr:attr
    o THIS:         "_ '@'", This
    o REGEX:        "_ _FSLASH &:(!_FSLASH (ESC2 | .))* _FSLASH <words:1> flags:/[a-zA-Z]*/", Str
    o STRING: [
      o             "_ _QUOTE  (!_QUOTE  (ESCSTR | .))* _QUOTE",  Str
      o             "_ _TQUOTE (!_TQUOTE (ESCSTR | INTERP | .))* _TQUOTE", Str
      o             "_ _DQUOTE (!_DQUOTE (ESCSTR | INTERP | .))* _DQUOTE", Str
      i ESCSTR:     "_SLASH .", (it) -> {n:'\n', t:'\t', r:'\r'}[it] or it
      i INTERP:     "'\#{' _BLANKLINE* _RESETINDENT EXPR ___ '}'"
    ]
    o BOOLEAN:      "_TRUE | _FALSE", (it) -> it is 'true'
    o NUMBER:       "_ <words:1> /-?[0-9]+(\\.[0-9]+)?/", Number
    o SYMBOL:       "_ !_KEYWORD WORD"
  ]

  # BLOCKS:
  i BLOCK: [
    o               "_INDENT LINE*_NEWLINE", Block
    o               "_THEN?  LINE+(_ ';')", Block
  ]
  i BLOCKEXPR:      "_INDENT? EXPR"
  i _INDENT:        "_BLANKLINE+ &:_", checkIndent, skipCache:yes
  i _RESETINDENT:   "_BLANKLINE* &:_", resetIndent, skipCache:yes
  i _NEWLINE: [
    o               "_BLANKLINE+ &:_", checkNewline, skipCache:yes
    o               "_ ';'"
  ], skipCache:yes
  i _SOFTLINE:      "_BLANKLINE+ &:_", checkSoftline, skipCache:yes
  i _COMMA:         "beforeBlanks:_BLANKLINE* beforeWS:_ ','
                      afterBlanks:_BLANKLINE*  afterWS:_", checkComma, skipCache:yes

  # TOKENS:
  i WORD:           "_ <words:1> /[a-zA-Z\\$_][a-zA-Z\\$_0-9]*/", Word
  i _KEYWORD:       tokens('if', 'unless', 'else', 'for', 'own', 'in', 'of', 'loop', 'while', 'break', 'switch',
                      'when', 'return', 'throw', 'then', 'is', 'isnt', 'true', 'false', 'by',
                      'not', 'and', 'or', 'instanceof', 'typeof', 'try', 'catch', 'finally')
  i _QUOTE:         "'\\''"
  i _DQUOTE:        "'\"'"
  i _TQUOTE:        "'\"\"\"'"
  i _FSLASH:        "'/'"
  i _SLASH:         "'\\\\'"
  i '.':            "<chars:1> /[\\s\\S]/",            skipLog:yes
  i ESC1:           "_SLASH .",                        skipLog:yes
  i ESC2:           "_SLASH .", ((chr) -> '\\'+chr),   skipLog:yes

  # WHITESPACES:
  i _:              "<words:1> /[ ]*/",                skipLog:yes
  i __:             "<words:1> /[ ]+/",                skipLog:yes
  i _TERM:          "_ ('\r\n'|'\n')",                 skipLog:yes
  i _COMMENT:       "_ !HEREDOC '#' (!_TERM .)*",      skipLog:yes
  i _BLANKLINE:     "_ _COMMENT? _TERM",               skipLog:yes
  i ___:            "_BLANKLINE* _",                   skipLog:yes

]
# ENDGRAMMAR
