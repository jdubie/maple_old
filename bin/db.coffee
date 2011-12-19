fs     = require 'fs'
events = require 'events'
_      = require 'underscore'
async  = require 'async'
env    = require '../env/env'

db       = env.getDbConn()
dbMaster = env.getDb()

taskPromise = new (events.EventEmitter)

module.exports =
  seed: ->
    dbMaster.db.destroy env.getDbName(), ->
      dbMaster.db.create env.getDbName(), ->

        # create a document for seed.json
        seed = fs.readFileSync './db/seed.json'
        seed = JSON.parse seed
        db.insert seed, 'master', (err) ->
          if err
            console.error 'db:seed ERROR ***', err
          else
            console.error 'db:seeded'

  save: ->
    db.get 'master', (err,result) ->
      fs.writeFileSync './db/save.json', JSON.stringify result, undefined, '\s'
      console.error 'db:saved'