express   = require 'express'
fs        = require 'fs'
events    = require 'events'
_         = require 'underscore'
async     = require 'async'
constants = require './env/constants'

app = module.exports = express.createServer()


##################################
## Express configuration
app.configure ->
  app.set 'views', __dirname + '/views'
  app.set 'view engine', 'jade'
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use app.router
  app.use express.static __dirname + '/public'
##################################


##################################
## Environment configuration
env = require './env/env'

app.configure 'development', ->
  app.use express.errorHandler
    dumpExceptions: true
    showStack: true

app.configure 'production', ->
  app.use express.errorHandler()

db   = env.getDbConn()
port = env.getListenPort()
###################################


###################################
## Serving pages
getViewData = (promise) ->

  db.get 'master', (err,result) ->
    promise.emit 'viewData', result

renderView = (view,res) ->

  promise = new (events.EventEmitter)
  promise.on 'start', ->
    getViewData promise

  promise.on 'viewData', (viewData) ->

    # set up rendering options
    viewData.edit = true # TODO dynamically assign this based on session
    renderOptions =
      maple: viewData

    # actually render view
    res.render 'index', renderOptions

  promise.emit 'start'

# Routes

app.get '/', (req,res) ->
  renderView 'index', res
app.get '/:id', (req,res) ->
  renderView req.params.id, res
####################################


####################################
## Handling Data modification
app.post '/save', (req,res) ->

  key   = req.body.id
  value = req.body.value

  handleSave = (err) ->
    if err
      res.end err.toString()
    else
      res.end value

  db.get 'master', (err,doc) ->

    set_nested = (key,new_value,ob) ->
      # base case
      if key.length == 1
        ob[key] = new_value
        return
      # otherwise recurse
      first = key.shift()
      set_nested key,new_value,ob[first]

    ## modify document
    key = key.split('.')
    set_nested key,value,doc

    ## resave document
    db.insert doc, handleSave
###################################


app.listen port

console.log "Maple server listening on port %d in %s mode", app.address().port, app.settings.env