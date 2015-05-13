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
    gluon1.on("test-done", =>
      ctx.testVar.should.equal 5
      done())

  it 'Test Module Access', (done) ->
    gluon1.on("test-done", =>
      ctx.testVar.should.equal 6
      done())

  it 'Test Return Arguments', (done) ->
    gluon1.on("test-done", => done())

  it 'Test Notify', (done) ->
    gluon1.on("test-done", => done())

  it 'Test Call Error', (done) ->
    gluon1.on("test-done", => done())

  it 'Test Globals', () ->
    ctx.process.should.exist
    ctx.global.should.exist
    ctx.console.should.exist
    ctx.module.should.exist
    ctx.__dirname.should.exist
    ctx.__filename.should.exist

  it 'Test Attrs', (done) ->
    gluon1.on("test-done", => done())

  it 'Test Function Calls', (done) ->
    gluon1.on("test-done", => done())

  it 'Test Direct Call', (done) ->
    gluon1.on("test-done", => done())
