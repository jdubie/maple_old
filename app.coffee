express   = require 'express'
fs        = require 'fs'
constants = require './env/constants'
_         = require 'underscore'
async     = require 'async'

nano = require('nano')('http://admin:admin@localhost:5984')
db   = nano.use 'somacentral'

app = module.exports = express.createServer()


# Configuration

app.configure ->
  app.set 'views', __dirname + '/views'
  app.set 'view engine', 'jade'
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use app.router
  app.use express.static __dirname + '/public'

app.configure 'development', ->
  app.use express.errorHandler
    dumpExceptions: true
    showStack: true

app.configure 'production', ->
  app.use express.errorHandler()

renderView = (view,res) ->

  ## read jade file to determine dependencies
  view = fs.readFileSync './views/' + view + '.jade'
  view = view.toString()

  #### TODO: Make this parsing correct (CFG??)
  deps = view.split constants.DYN_VAR
  deps.shift() # remove leading jade

  ## remove leading period
  deps = _.map deps, (dep) -> dep.split('.')[1]

  ## remove trailing text
  deps = _.map deps, (dep) -> dep.split('}')[0]
  deps = _.map deps, (dep) -> dep.split('\n')[0]
  deps = _.map deps, (dep) -> dep.split(' ')[0]

  ## remove duplicate dependencies
  deps = _.uniq deps

  async.map deps, db.get, (err,r) ->

    # build up result
    result = {}
    for i in [0...deps.length]
      result[deps[i]] = r[i].value

    res.render 'index'
      layout : false
      '_BOOM': result

# Routes

app.get '/', (req,res) ->
  renderView 'index', res
app.get '/:id', (req,res) ->
  renderView req.params.id, res




app.listen 3000

console.log "Express server listening on port %d in %s mode", app.address().port, app.settings.env