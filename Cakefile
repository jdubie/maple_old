fs     = require 'fs'
events = require 'events'
_      = require 'underscore'
async  = require 'async'
env    = require './env/env'

db       = env.getDbConn()
dbMaster = env.getDb()

taskPromise = new (events.EventEmitter)

task 'db:seed', (options) ->

  dbMaster.db.destroy env.getDbName(), ->
    dbMaster.db.create env.getDbName(), ->

      # create a document for every key
      # in seed.json
      seed = fs.readFileSync './db/seed.json'
      seed = JSON.parse seed
      keys = _.keys seed
      insertDocs = _.map keys, (key) ->
        (cb) -> db.insert value: seed[key], key, cb

      async.parallel insertDocs, (err,results) ->
        if err
          console.error 'db:seed ERROR ***', err
        else
          console.error 'db:seeded'

task 'db:save', (options) ->
  db.list (err,body) ->
    ids = _.map body.rows, (row) -> row.id

    async.map ids, db.get, (err,responses) ->
      res = _.map responses, (res) -> res.value

      result = {}
      for i in [0...ids.length]
        result[ids[i]] = res[i]
      fs.writeFileSync './db/save.json', JSON.stringify result, undefined, '\s'

      console.error 'db:saved'
