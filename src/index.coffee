# Copyright 2015 Surul Software Labs GmbH
# This file is licensed under the MIT License
#
# A process is started using the spawn() method in the child_process
# module. stdin and stdout are used to perform bi-directional data
# exchange. stderr is used for logging. All data from stderr is reprinted
# on the stderr in nodejs.

child_process = require "child_process"
StreamSplitter = require "stream-splitter"
events = require "events"

getProp = (source, objName) ->
  obj = source[objName]
  if not obj?
    throw new Error("#{objName} not found")
  return obj

class Gluon extends events.EventEmitter
  constructor: (@ctx, @env, @binary, @args...) ->
    @scripts = {}
    @debugEnabled = false
    @callbackCtr = 0
    gl = {
      'module': module, 'process': process, 'global': global, 'console': console,
      '__dirname': __dirname, '__filename': __filename
    }
    for key, val of gl
      if key not in @ctx
        @ctx[key] = val

  start: ->
    @debug("Starting gluon #{@binary} #{@args}")
    try
      localEnv = {}
      for k, v of process.env
        localEnv[k] = v
      for k, v of @env
        localEnv[k] = v

      @proc = child_process.spawn(@binary, @args, {env: localEnv, stdio: ["pipe", "pipe", process.stderr]})
      @stdoutLines = @proc.stdout.pipe(StreamSplitter("\n"))
      @stdoutLines.encoding = "utf8"
      @stdoutLines.on("token", (t) => @read t)
      @stdoutLines.on("done", =>
        console.log("Gluon terminated")
        @emit("done")
      )
      @stdoutLines.on("error", (err) -> console.error("Error in gluon!", err))
    catch e
      throw "Failed to start gluon process: #{e}"

  stop: ->
    @proc.kill()

  read: (token) ->
    if token.charAt(0) != '{'
      process.stdout.write(token)
      process.stdout.write('\n')
      return

    id = null
    try
      event = JSON.parse(token)
      type = event["type"]
      id = event["id"]
      switch type
        when "add"
          @add(event["name"], event["script"])
        when "attr"
          out = @attr(event["obj"], event["name"], event["save"])
        when "fn"
          out = @fn(event["obj"], event["name"], event["save"], event["arg"], event["new"])
        when "free"
          @free(event["obj"])
        when "call"
          out = @call(event["name"], event["arg"])
        when "emit"
          @emitEvent(event["name"])
        else
          throw new Error("message type unknown: #{type}")

      @send({"id": id, "type": "ok", "msg": out})
    catch e
      @sendError(id, e)

  free: (objRef) ->
    delete @ctx[objRef]

  saveOrReturn: (save, result) ->
    if save? == "void"
      return null
    else if save?
      @ctx[save] = result
      return null
    return result

  makeArg: (value, objectRef, callbackRef) ->
    if callbackRef? and callbackRef.length > 0
      return (args...) =>
        notifyArgs = [callbackRef[0]]
        rest = callbackRef.slice(1)

        if args.length != rest.length
          @sendError(null, "expected " + rest.length + " args but received " + args.length + " for " + callbackRef[0])
          return

        for arg, i in rest
          if not arg? or arg == ""
            notifyArgs.push(args[i])
          else
            # store the object
            @callbackCtr++
            storedId = arg + "/" + @callbackCtr
            @ctx[storedId] = args[i]
            notifyArgs.push(storedId)

        @notify(notifyArgs...)
    else if objectRef?
      return getProp(@ctx, objectRef)
    else
      return value

  # objName: The name of the stored object to call the function on
  # name: The name of the function
  # save: The name to store the result under. If absent it is returned.
  # args: An array of arrays. Each element of the top level array represents an argument
  #       The second level arrays are structured as follows
  #         [value, objectRef, callbackRef]
  #       A callback is called by sending a notification to the child that a callback is
  #       being invoked.
  #
  # - Callback reference
  #   - All function arguments will be passed
  #   - array of strings - each corresponds to a function argument of the callback.
  #   - If the string is empty the value will be passed.
  #   - If the string is non-empty the value will be saved and the reference passed.
  fn: (objName, name, save, args, isConstructor) ->
    obj = getProp(@ctx, objName)
    f = getProp(obj, name)
    filtered = []
    if args?
      for arg in args
        filtered.push(@makeArg(arg...))
    if isConstructor? and isConstructor
      result = new (Function.prototype.bind.apply(f, filtered))
    else
      result = f.apply(obj, filtered)
    return @saveOrReturn(save, result)

  attr: (objName, name, save) ->
    @saveOrReturn(save, getProp(getProp(@ctx, objName), name))

  call: (name, arg) ->
    fn = @scripts[name]
    if not fn?
      throw new Error("no such function #{name}")
    result = fn(arg)

  emitEvent: (name) ->
    if not name?
      throw new Error("no event provided to emit")
    @emit(name)
    return null

  add: (name, script) ->
    if not name?
      throw new Error("script name absent")
    else if name of @scripts
      throw new Error("script #{name} exists")

    try
      @ctx[name] = null
      fn = eval("(" + script + ")")
      notify = (name, arg) => @notify(name, arg)
      @scripts[name] = (args...) => fn(notify, @ctx, args...)
    catch e
      throw new Error("invalid script: #{e}")

    @debug("Added script: #{name}")

  sendError: (id, obj) ->
    if obj instanceof Error
      msg = obj.stack
    else
      msg = obj
    @send({"type": "error", "id": id, "msg": msg})

  notify: (name, arg...) ->
    @send({"type": "notify", "name": name, "arg": arg})

  send: (obj) ->
    try
      str = JSON.stringify(obj)
      @proc.stdin.write(str + "\n")
    catch e
      console.error "error sending", obj, e.stack
      throw e

  debug: (objs...) ->
    if @debugEnabled
      console.log(objs...)

root = exports ? window
root.Gluon = Gluon
