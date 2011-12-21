events = require 'events'
assert = require 'assert'
vows   = require 'vows'
fs     = require 'fs'
_      = require 'underscore'
async  = require 'async'

auth   = require '../auth'
env    = require '../env/env'
db_bin = require '../bin/db'

db     = env.getDbConn()


counter = 0
unique_id = -> "user#{counter++}"
admin_pwd = 'password'

vows
  .describe('Authentication')
  .addBatch

    'set admin pwd':
      topic: ->
        promise = new (events.EventEmitter)
        db_bin.seed
        db_bin.pwd admin_pwd, ->
          promise.emit 'success'
        return promise
      'no errors': (err,suc) ->
        assert.equal err,null

      'try authenticating admin':
        topic: ->
          auth.authenticate_user 'admin',admin_pwd,db
        'we are successful': (err,suc) ->
          assert.equal err, null
          assert.equal suc, 'admin'

      'try authenticating admin with bad password':
        topic: ->
          auth.authenticate_user 'admin','bad password',db
        'we fail': (err,suc) ->
          assert.equal err, 'invalid password username combo'
          assert.equal suc, null

      'make valid user creation request':
        topic: ->
          auth.valid_request admin_pwd,'_unique_user','pwd12','pwd12',db
        'successful': (suc) ->
          assert.equal suc,'_unique_user'

      'short password':
        topic: ->
          auth.valid_request admin_pwd,'_unique_user','pwd','pwd',db
        'not successful': (err,suc) ->
          assert.equal err, 'password is too short'
          assert.equal suc, null

      'non-matching passwords':
        topic: ->
          auth.valid_request admin_pwd,'_unique_user','pwd111','pwd222',db
        'not successful': (err,suc) ->
          assert.equal err, 'passwords don\'t match'
          assert.equal suc, null

      'bad admin password':
        topic: ->
          auth.valid_request 'bad_pwd','_unique_user','pwd123','pwd123',db
        'not successful': (err,suc) ->
          assert.equal err, 'admin password invalid'
          assert.equal suc, null

      'already existing username':
        topic: ->
          auth.valid_request admin_pwd,'admin','pwd123','pwd123',db
        'not successful': (err,suc) ->
          assert.equal err, 'login name already exists'
          assert.equal suc, null

      'sign up valid user':
        topic: ->
          auth.signup_user admin_pwd,'newbee','pwd123','pwd123',db
        'not successful': (err,suc) ->
          assert.equal err, null
          assert.equal suc, 'newbee'

  .export module