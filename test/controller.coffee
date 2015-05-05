# Copyright 2015 Surul Software Labs GmbH
# This file is licensed under the MIT License

readline = require("readline")

send =  (obj) -> process.stdout.write(JSON.stringify(obj) + "\n")

errorsExists = false

fail = (args...) ->
  console.error(args...)
  errorsExists = true

deferredFinish = false

finish = () ->
  if not errorsExists
    send({"id": 10000, "name": "test-done", "type": "emit"})
  else
    send({"id": 10001, "name": "test-failed", "type": "emit"})

readResponses = {}

read = (cmd) ->
  try
    event = JSON.parse(cmd)
  catch e
    return fail("Error parsing command ", cmd, ":", e)

  id = event["id"]
  if not id?
    return fail("No event id present for command", cmd)

  response = readResponses[id]
  if not response?
    return fail("unexpected event ", cmd)

  response(event)

# All tests
testArgUpdate = () ->
  send({"id": 1, "name": "test", "type": "add", "script": "function(ctx, arg) {ctx.testVar = arg;}"})
  send({"id": 2, "name": "test", "arg": 5, "type": "call"})
  send({"id": 3, "name": "check-test-var", "type": "emit"})

testModuleAccess = () ->
  script = "
    function(ctx, arg) {
      assert = require('assert');
      assert.ok(true);
      ctx.testVar = arg;
    }
  "
  send({"id": 1, "name": "test", "type": "add", "script": script})
  send({"id": 2, "name": "test", "arg": 6, "type": "call"})
  send({"id": 3, "name": "check-test-var", "type": "emit"})

testReturnArguments = () ->
  # The test will finish once we receive a response from the parent and so the final signal
  # must be sent asynchronously
  deferredFinish = true
  send({"id": 1, "name": "test", "type": "add", "script": "function (ctx, arg) { return arg; }"})

  # Set up a callback to handle the function response. This finishes the test as well.
  readResponses[2] = (event) ->
    if event.msg != 7
      fail("received incorrect response ", event)
    finish()

  send({"id": 2, "name": "test", "arg": 7, "type": "call"})


tests = {
  "Test Argument Update": (a...) -> testArgUpdate(a...),
  "Test Module Access": (a...) -> testModuleAccess(a...),
  "Test Return Arguments": (a...) -> testReturnArguments(a...)
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

  # Finish the test
  if not deferredFinish
    finish()

# Run all tests
main(process.env["GLUONJS_TEST"])


