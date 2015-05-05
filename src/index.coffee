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

class Gluon extends events.EventEmitter
  constructor: (@ctx, @env, @binary, @args...) ->
    @scripts = {}
    @debugEnabled = false

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
    try
      event = JSON.parse(token)
    catch e
      @debug("Invalid JSON:", token)
      @sendError(null, "invalid json: #{e}")
      return

    type = event["type"]
    switch type
      when "add"
        err = @add(event["name"], event["script"])
      when "call"
        [out, err]= @call(event["name"], event["arg"])
      when "emit"
        err = @emitEvent(event["name"])
      else
        err = "message type unknown: #{type}"

    if err?
      @sendError(event["id"], err)
    else
      @send({"id": event["id"], "type": "ok", "msg": out})

  call: (name, arg) ->
    fn = @scripts[name]
    if not fn?
      return [null, "no such function #{name}"]

    try
      result = fn(arg)
      return [result, null]
    catch e
      return [null, e]


  emitEvent: (name) ->
    if not name?
      return "no event provided to emit"
    @emit(name)
    return null

  add: (name, script) ->
    if not name?
      return "script name absent"
    else if name of @scripts
      return "script #{name} exists"

    try
      @ctx[name] = null
      fn = eval("(" + script + ")")
      notify = (name, arg) => @notify(name, arg)
      @scripts[name] = (args...) => fn(notify, @ctx, args...)
    catch e
      return "invalid script: #{e}"

    @debug("Added script: #{name}")

  sendError: (id, obj) ->
    @send({"type": "error", "id": id, "msg": obj})

  notify: (name, arg) ->
    @send({"type": "notify", "name": name, "arg": arg})

  send: (obj) ->
    @proc.stdin.write(JSON.stringify(obj) + "\n")

  debug: (objs...) ->
    if @debugEnabled
      console.log(objs...)

root = exports ? window
root.Gluon = Gluon
