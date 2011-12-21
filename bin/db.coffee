fs     = require 'fs'
events = require 'events'
_      = require 'underscore'
async  = require 'async'
env    = require '../env/env'
auth   = require '../auth'

db       = env.getDbConn()
dbMaster = env.getDb()

taskPromise = new (events.EventEmitter)

module.exports =
  seed: ->
    dbMaster.db.create env.getDbName(), (err,suc) ->
      if err?
        if err.message != 'The database could not be created, the file already exists.' || err.error != 'file_exists'
          console.error 'db:seed ERROR ***'
          return

      db.get 'master', (err,doc) ->

        # create a document for seed.json
        seed = fs.readFileSync './db/seed.json'
        seed = JSON.parse seed

        ## give seed old revision so we can overwrite it
        seed._rev = doc._rev if doc._rev?

        db.insert seed, 'master', (err) ->
          if err
            console.error 'db:seed ERROR ***', err
          else
            console.error 'db:seeded'

  save: ->
    db.get 'master', (err,result) ->
      fs.writeFileSync './db/save.json', JSON.stringify result, undefined, '\s'
      console.error 'db:saved'