express   = require 'express'
fs        = require 'fs'
events    = require 'events'
_         = require 'underscore'
async     = require 'async'
constants = require './env/constants'

app = module.exports = express.createServer()


# Configuration

app.configure ->
  app.set 'views', __dirname + '/views'
  app.set 'view engine', 'jade'
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use app.router
  app.use express.static __dirname + '/public'

##################################
## env configuration
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

getViewData = (promise) ->

  db.get 'master', (err,result) ->
    promise.emit 'viewData', result

renderView = (view,res) ->

  promise = new (events.EventEmitter)
  promise.on 'start', ->
    getViewData promise

  promise.on 'viewData', (viewData) ->

    # set up rendering options
    viewData.edit = true # TODO dynamically assign this
    renderOptions = {}
    renderOptions[constants.DYN_VAR] = viewData
    renderOptions['_DYN']            = viewData

    # actually render view
    res.render 'index', renderOptions

  promise.emit 'start'

# Routes

app.get '/', (req,res) ->
  renderView 'index', res
app.get '/:id', (req,res) ->
  renderView req.params.id, res

# handle saving
app.post '/save', (req,res) ->
  id    = req.body.id
  value = req.body.value

  handleSave = (err) ->
    if err
      res.end err.toString()
    else
      res.end value

  db.get 'master', (err,doc) ->
    ## modify document
    doc[id] = value
    ## resave document
    db.insert doc, handleSave

app.listen port

console.log "Maple server listening on port %d in %s mode", app.address().port, app.settings.env