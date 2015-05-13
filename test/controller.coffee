# Copyright 2015 Surul Software Labs GmbH
# This file is licensed under the MIT License

readline = require("readline")
events = require("events")
proc = require("process")
path = require("path")


readResponses = {}
notifications = {}

objId = 0

send = (obj, cb) ->
  obj["id"] = objId++
  process.stdout.write(JSON.stringify(obj) + "\n")
  readResponses[obj["id"]] = (event) => cb?(event)

errorsExists = false

fail = (args...) ->
  console.error(args...)
  errorsExists = true

finish = () ->
  if not errorsExists
    send({"name": "test-done", "type": "emit"})
  else
    send({"name": "test-failed", "type": "emit"})



read = (cmd) ->
  try
    event = JSON.parse(cmd)
  catch e
    return fail("Error parsing command ", cmd, ":", e)

  if event["type"]? and event["type"] == "notify"
    channel = notifications[event["name"]]
    if not channel?
      return fail("unexpected notification ", cmd)
    channel(event)
    return

  id = event["id"]
  if not id?
    return fail("No event id present for command", cmd)

  response = readResponses[id]
  if not response?
    return fail("unexpected event ", cmd)

  response(event)

check = (e, expected) ->
  failed = true
  if e["type"] == "ok"
    if not expected? or expected == e["msg"]
      failed = false

  if not failed
    return {send: send, finish: finish}
  else
    fail(e["msg"])
    return {send: (args...) -> finish()
            finish: finish}

# All tests
testArgUpdate = () ->
  send({"name": "test", "type": "add", "script": "function(g, ctx, arg) {ctx.testVar = arg;}"},
    (event) ->
      check(event).send({"name": "test", "arg": 5, "type": "call"},
      (event) -> check(event).finish()))

testModuleAccess = () ->
  script = "
    function(g, ctx, arg) {
      assert = require('assert');
      assert.ok(true);
      ctx.testVar = arg;
    }
  "
  send({"name": "test", "type": "add", "script": script},
    (event) -> check(event).send({"name": "test", "arg": 6, "type": "call"}, (e) -> check(e).finish()))

testReturnArguments = () ->
  send({"name": "test", "type": "add", "script": "function (g, ctx, arg) { return arg; }"},
    (e) -> check(e).send({"name": "test", "arg": 7, "type": "call"},
      (event) ->
        check(event)
        if event.msg != 7
          fail("received incorrect response ", event)
        finish()
    ))

testNotify = () ->
  notifications['test-notification'] = (event) ->
    if event["arg"][0] != 20
      fail("incorrect notification received", event)
    finish()

  send({"name": "test", "type": "add", "script": "
    function (notify, ctx, arg) {
      notify('test-notification', arg);
    }
  "},
    (e) -> check(e).send({"name": "test", "arg": 20, "type": "call"},
      (event) -> check(event)))

testCallError = () ->
  send({"name": "test", "type": "add", "script": "function(g, ctx, arg) {throw new Error('This is an error');}"},
    (event) ->
      check(event).send({"name": "test", "arg": 5, "type": "call"},
        (event) ->
          if event["type"] != "error"
            fail("Expected error but received", event)
          splits = event["msg"].split("\n")
          if splits[0] != 'Error: This is an error' or splits[1] != '  at eval (<anonymous>:1:31)'
            fail("Expected error but received", event)
          finish()))

testSaveAttrs = () ->
  send({"type": "attr", "obj": "process", "name": "versions", "save": "process/versions"},
    (event) ->
      check(event).send({"type": "attr", "obj": "process/versions", "name": "node"},
        (event) ->
          check(event)
          if event.msg != process.versions.node
            fail("did not read saved attribute")
          finish()))

testGetAttrs = () ->
  send({"type": "attr", "obj": "process", "name": "arch"},
    (event) ->
      check(event, process.arch)
      testSaveAttrs())

testAttrs = () -> testGetAttrs()


fn = (obj, name, args, save) -> {"type": "fn", "obj": obj, "name": name, "save": save, "arg": args}
ctor = (obj, name, args, save) -> {"type": "fn", "obj": obj, "name": name, "save": save, "arg": args, "new": true}

testCallbacks = () ->
  notifications["test-callback"] = (event) ->
    arg = event["arg"]
    if arg.length != 2
      throw new Error("unexpected callback ", event)

    if arg[0] != 5
      throw new Error("expected 5 got ", arg[0])

    send({"type": "attr", "obj": arg[1], "name": "arch"},
      (event) ->
        check(event, process.arch)
        finish())

  send(fn("module", "require", [["events"]], "events"),
    (event) -> check(event).send(ctor("events", "EventEmitter", [], "emitter"),
      (event) -> check(event).send(fn("emitter", "on", [["test-callback"], [null, null, ["test-callback", "", "procObj"]]], "void"),
        (event) -> check(event).send(fn("emitter", "emit", [["test-callback"], [5], [null, "process"]], "void"),
          (event) -> check(event)))))

testRequireWithSave = () ->
  send(fn("module", "require", [["path"]], "path"),
    (event) ->
      check(event).send(fn("process", "cwd", null, "currentWD"),
        (event) ->
          check(event).send(fn("path", "basename", [[null, "currentWD"]], null),
            (event) ->
              check(event, path.basename(process.cwd()))
              testCallbacks())))

testRequire = () ->
  send(fn("module", "require", [["path"]], "path"),
    (event) ->
      check(event).send(fn("path", "basename", [[__filename]], null),
        (event) ->
          check(event, path.basename(__filename))
          testRequireWithSave()))

testArgLessFn = () ->
  send({"type": "fn", "obj": "process", "name": "cwd"},
    (event) ->
      check(event, process.cwd())
      testRequire())

testFunctionCalls = () -> testArgLessFn()

testDirectCall = () ->
  send(fn("module", "require", [["buffer"]], "buffer"),
    (event) -> check(event).send({"type": "attr", "obj": "buffer", "name": "Buffer", "save": "Buffer"},
      (event) -> check(event).send(ctor("Buffer", "", [["contents"]], "buf1"),
        (event) -> check(event).send(fn("buf1", "toString", [], null),
          (event) ->
            check(event)
            finish()))))

tests = {
  "Test Argument Update": (a...) -> testArgUpdate(a...),
  "Test Module Access": (a...) -> testModuleAccess(a...),
  "Test Return Arguments": (a...) -> testReturnArguments(a...)
  "Test Notify": (a...) -> testNotify(a...)
  "Test Call Error": (a...) -> testCallError(a...)
  "Test Attrs": (a...) -> testAttrs(a...)
  "Test Function Calls": (a...) -> testFunctionCalls(a...)
  "Test Direct Call": (a...) -> testDirectCall(a...)
}

main = (testName) ->
# Start reading input
  rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
    terminal: false
  })

  # Set up callbacks for handling commands from parent
  rl.on('line', (cmd) => read(cmd))

  # Choose test to run
  test = tests[testName?.trim()]
  if not test?
    return fail("no such test ", testName)

  test()

# Run all tests
main(process.env["GLUONJS_TEST"])


