require 'sugar'

{clazz, colors:{red, blue, cyan, magenta, green, normal, black, white, yellow}} = require('cardamom')
{inspect} = require 'util'
assert = require 'assert'
async = require 'async'
{pad, escape, starts, ends} = require 'sembly/lib/helpers'
{debug, info, warn, fatal} = require('nogg').logger __filename.split('/').last()

{JObject, JArray, JUndefined, JNull, JNaN, JStub, JBoundFunc} = require 'sembly/src/interpreter/object'

fnNamed = (name, fn) -> fn.id = name; fn

# Caches.
CACHE = @CACHE = {}

if window?
  PERSISTENCE = undefined
else
  {JPersistence} = p = require 'sembly/src/interpreter/persistence'
  PERSISTENCE = new JPersistence()

GOD     = @GOD   = CACHE['god']   = new JObject id:'god',   creator:null, data:name:'God'
ANON    = @ANON  = CACHE['anon']  = new JObject id:'anon',  creator:GOD, data:name:'Anonymous'
if require.main is module
  USERS = @USERS = CACHE['users'] = new JObject id:'users', creator:GOD, data:
    god:    GOD
    anon:   ANON
else
  USERS = @USERS                  = new JStub   id:'users', persistence:PERSISTENCE
WORLD   = @WORLD = CACHE['world'] = new JObject id:'world', creator:GOD, data: {
  world:  new JStub(id:'world', persistence:PERSISTENCE)
  this:   USERS
  users:  USERS
  login:  CACHE['login'] = fnNamed('login', ($) ->
    return "TODO: This should be a form object with a callback."
  )
  eval:   CACHE['eval'] = fnNamed('eval', ($, this_, codeStr) ->
    # Parse the codeStr and associate functions with the output Item
    try
      #info "evaluating code:\n#{codeStr}"
      node = require('sembly/src/joescript').parse codeStr
      #info "unparsed node:\n" + node.serialize()
      node = node.toJSNode(toValue:yes).installScope().determine()
      #info "parsed node:\n" + node.serialize()
    catch err
      return $.throw 'EvalError', "Error in eval(): #{err}"
    # Run node by pushing node into the stack.
    # NOTE: node should be a block, and it has its own scope,
    # so it's different from javascript's eval in this way.
    $.i9ns.push this:node, func:node.interpret
  )
}
WORLD.hack_persistence = PERSISTENCE # FIX

{JKernel} = require 'sembly/src/interpreter/kernel'
KERNEL = @KERNEL = new JKernel cache:CACHE
KERNEL.emitter.on 'shutdown', -> PERSISTENCE?.client.quit()

# Not all world items are initialized manually.
# Some (like command) live in the database, so
# if you need them, you want to call this method first.
# TODO refactor, make reload available to all objects.
WORLD.reload = (cb) ->
  delete CACHE['world']
  PERSISTENCE.loadJObject 'world', CACHE, (err, world) ->
    WORLD.data = world.data if world?
    cb(err, world)

# run this file to set up redis
if require.main is module
  PERSISTENCE?.attachTo WORLD
  KERNEL.run({user:GOD, scope:WORLD, code: """
      world.command = {
        type: 'editor'
        mode: 'coffeescript'
        onSubmit: ({modules, data:codeStr}) ->
          modules.push module={code:codeStr, status:'running'}
          print = (data) ->
            if not module.output?
              output = module.output = []
              output.__class__ = 'hideKeys'
            output.push data
          #try XXX implement try/catch blocks.
          module.result = eval(codeStr)
          #catch error
          #  module.error = error
          module!status
      } 
    """, callback: (err) ->
      return console.log "FAIL!\n#{err.stack ? err}" if err?
      WORLD.emit thread:@, type:'new'
      @enqueue callback: (err) ->
        return console.log "FAIL!\n#{err.stack ? err}" if err?
        PERSISTENCE.client.quit() # TODO
        console.log "done!"
  })
