# Copyright 2015 Surul Software Labs GmbH
# This file is licensed under the MIT License

readline = require("readline")
events = require("events")

readResponses = {}

objId = 0

send = (obj, cb) ->
  obj["id"] = objId++
  process.stdout.write(JSON.stringify(obj) + "\n")
  readResponses[obj["id"]] = (event) => cb?(event)

errorsExists = false

fail = (args...) ->
  console.error(args...)
  errorsExists = true

deferredFinish = false

finish = () ->
  if not errorsExists
    send({"name": "test-done", "type": "emit"})
  else
    send({"name": "test-failed", "type": "emit"})


notifications = []

read = (cmd) ->
  try
    event = JSON.parse(cmd)
  catch e
    return fail("Error parsing command ", cmd, ":", e)

  if event["type"]? and event["type"] == "notify"
    notifications.push(event)
    return

  id = event["id"]
  if not id?
    return fail("No event id present for command", cmd)

  response = readResponses[id]
  if not response?
    return fail("unexpected event ", cmd)

  response(event)

check = (e) ->
  if e["type"] == "ok"
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
  send({"name": "test", "type": "add", "script": "
    function (notify, ctx, arg) {
      notify('test-notification', arg);
    }
  "},
    (e) -> check(e).send({"name": "test", "arg": 20, "type": "call"},
      (event) ->
        check(event)
        if notifications.length == 1
          n = notifications[0]

        if not n?
          fail("no notification received")
        else if n.arg != 20 or n.name != "test-notification"
          fail("incorrect notification received", n)

        finish()))

tests = {
  "Test Argument Update": (a...) -> testArgUpdate(a...),
  "Test Module Access": (a...) -> testModuleAccess(a...),
  "Test Return Arguments": (a...) -> testReturnArguments(a...)
  "Test Notify": (a...) -> testNotify(a...)
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


