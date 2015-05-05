# Copyright 2015 Surul Software Labs GmbH
# This file is licensed under the MIT License

# The test is broken into two files. Each test case is run in a separate
# instance of the child process. A specific test name is passed to the
# child process which runs the appropriate test code, communicating with
# the parent process (the test runner). The file controller.coffee contains
# all of these tests.

chai = require "chai"
chai.should()

{Gluon} = require "../src/index"

describe 'Gluon', ->
  gluon1 = null

  ctx = {}
  @timeout(1000)

  beforeEach ->
    ctx.testVar = 10
    env = {"GLUONJS_TEST": @currentTest.title}
    gluon1 = new Gluon ctx, env, 'node_modules/.bin/coffee', 'test/controller.coffee'
    gluon1.debugEnabled = false
    gluon1.start()
    gluon1.on("test-failed", => throw new Error("test failed"))

  afterEach ->
    gluon1?.stop()

  it 'Test Argument Update', (done) ->
    gluon1.on("check-test-var", => ctx.testVar.should.equal 5)
    gluon1.on("test-done", => done())

  it 'Test Module Access', (done) ->
    gluon1.on("check-test-var", => ctx.testVar.should.equal 6)
    gluon1.on("test-done", => done())

  it 'Test Return Arguments', (done) ->
    gluon1.on("test-done", => done())
