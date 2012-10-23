fs = require 'fs'
{spawn, exec} = require 'child_process'
log = console.log
sugar = require 'sugar'

task 'build', ->
  run 'coffee -c src/*.coffee'
  run 'coffee -c src/**/*.coffee'
  run 'coffee -c lib/*.coffee'
  #run 'coffee -c lib/**/*.coffee'

task 'install', 'install JoeScript into /usr/local (or --prefix)', (options) ->
  base = options.prefix or '/usr/local'
  lib  = "#{base}/lib/joescript"
  bin  = "#{base}/bin"
  node = "~/.node_libraries/joescript"
  console.log   "Installing JoeScript to #{lib}"
  console.log   "Linking to #{node}"
  console.log   "Linking 'joe' to #{bin}/joe"
  exec([
    "mkdir -p #{lib} #{bin}"
    "cp -rf bin lib LICENSE README.md package.json src #{lib}"
    "ln -sfn #{lib}/bin/joe #{bin}/joe"
    #"ln -sfn #{lib}/bin/cake #{bin}/cake"
    #"mkdir -p ~/.node_libraries"
    #"ln -sfn #{lib}/lib/joescript #{node}"
  ].join(' && '), (err, stdout, stderr) ->
    if err then console.log stderr.trim() else log 'done', green
  )

task 'test', ->
  run 'cake build', ->
    run 'coffee tests/codestream_test.coffee', ->
      run 'coffee tests/joeson_test.coffee', ->
        run 'coffee tests/joescript_test.coffee', ->
          run 'coffee tests/translator_test.coffee', ->
            run 'coffee tests/jscompile_test.coffee', ->
              console.log "All tests OK"

task 'browser', 'Package compiled files for inclusion in the browser', ->
  run 'cake build', ->
    code = """
      nonce = {nonce:'nonce'};
    """
    code = require('joescript/lib/demodule')([
      {name:'joescript/src',      path:'src/**.js'}
      {name:'joescript/lib',      path:'lib/**.js'}
      {name:'_process',        path:'node_modules/browserify/builtins/__browserify_process.js'}
      {name:'assert',          path:'node_modules/browserify/builtins/assert.js'}
      {name:'util',            path:'node_modules/browserify/builtins/util.js'}
      {name:'events',          path:'node_modules/browserify/builtins/events.js'}
      {name:'buffer',          path:'node_modules/browserify/builtins/buffer.js'}
      {name:'buffer_ieee754',  path:'node_modules/browserify/builtins/buffer_ieee754.js'}
      #{name:'path',            path:'node_modules/browserify/builtins/path'}
      {name:'fs',              path:'node_modules/browserify/builtins/fs.js'}
      {name:'cardamom',        path:'node_modules/cardamom/lib/cardamom.js'}
      {name:'cardamom/src',    path:'node_modules/cardamom/lib/**.js'}
      {name:'sugar',           path:'node_modules/sugar/release/1.2.5/development/sugar-1.2.5-core.development.js'}
      {name:'async',           path:'node_modules/async/lib/async.js'}
      {name:'nogg',            path:'node_modules/nogg/lib/nogg.js'}
      {name:'uglify-js',       path:'node_modules/uglify-js/uglify-js.js'}
      {name:'uglify-js/lib',   path:'node_modules/uglify-js/lib/**.js'}
    ], {
      main:           {name:'Sembly', module:'joescript/src'}
      beforeModule:   'var process = require("_process");'
      afterPackage:   """
        if (typeof define === 'function' && define.amd) {
          define(function() { return Main; });
        } else { 
          root.Sembly = Sembly;
        }
      """
    })
    fs.writeFileSync 'static/joescript.js', code, 'utf8'
    {parser, uglify} = require 'uglify-js'
    minCode = uglify.gen_code (uglify.ast_squeeze uglify.ast_mangle parser.parse code), ascii_only:yes # issue on chrome on ubuntu
    fs.writeFileSync 'static/joescript.min.js', minCode, 'utf8'

run = (args...) ->
  for a in args
    switch typeof a
      when 'string' then command = a
      when 'object'
        if a instanceof Array then params = a
        else options = a
      when 'function' then callback = a
  
  command += ' ' + params.join ' ' if params?
  cmd = spawn '/bin/sh', ['-c', command], options
  cmd.stdout.on 'data', (data) -> process.stdout.write data
  cmd.stderr.on 'data', (data) -> process.stderr.write data
  process.on 'SIGHUP', -> cmd.kill()
  cmd.on 'exit', (code) -> callback() if callback? and code is 0
