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
env = fs.readFileSync './env/env.json'
env = JSON.parse env

app.configure 'development', ->
  app.use express.errorHandler
    dumpExceptions: true
    showStack: true
  env = env.development

app.configure 'production', ->
  app.use express.errorHandler()
  env = env.production

nano = require('nano')('http://admin:admin@localhost:5984')
db   = nano.use "#{env.db_name}"
# db = nano.use 'somacentral'
###################################


getDepencies = (view,promise) ->

  # ## read jade file to determine dependencies
  # view = fs.readFileSync './views/' + view + '.jade'
  # view = view.toString()

  # #### TODO: Make this parsing correct (CFG??)
  # deps = view.split constants.DYN_VAR
  # deps.shift() # remove leading jade

  # ## remove leading period
  # deps = _.map deps, (dep) -> dep.split('.')[1]

  # ## remove trailing text
  # deps = _.map deps, (dep) -> dep.split('}')[0]
  # deps = _.map deps, (dep) -> dep.split('\n')[0]
  # deps = _.map deps, (dep) -> dep.split(' ')[0]

  # ## remove duplicate dependencies
  # deps = _.uniq deps

  # just grab everything
  db.list (err,body) ->
    deps = _.map body.rows, (row) -> row.id
    promise.emit 'deps', deps

getViewData = (deps,promise) ->

  async.map deps, db.get, (err,r) ->

    # build up result
    result = {}
    for i in [0...deps.length]
      result[deps[i]] = r[i].value

    promise.emit 'viewData', result

renderView = (view,res) ->

  promise = new (events.EventEmitter)
  promise.on 'start', ->
    getDepencies view, promise

  promise.on 'deps', (deps) ->
    getViewData deps, promise

  promise.on 'viewData', (viewData) ->

    # set up rendering options
    viewData.edit = true
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
  console.error req
  renderView req.params.id, res

# handle saving
app.post '/save/:id', (req,res) ->
  id = req.body.id
  value = req.body.value

  handleSave = (err) ->
    if err
      res.end err.toString()
    else
      res.end value

  # save new one
  db.get id, (err,doc) ->
    if err? and err.error == 'not_found' and err.message == 'missing'
      ## create document
      console.error 'create new document'
      db.insert {value}, id, handleSave
    else
      ## modify document
      doc.value = value
      db.insert doc, handleSave

app.listen 3000

console.log "Express server listening on port %d in %s mode", app.address().port, app.settings.env