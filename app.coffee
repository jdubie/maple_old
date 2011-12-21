events      = require 'events'
fs          = require 'fs'
crypto      = require 'crypto'
express     = require 'express'
_           = require 'underscore'
async       = require 'async'
auth        = require './auth'

app = module.exports = express.createServer()

##################################
## Environment configuration
env = require './env/env'

db     = env.getDbConn()
port   = env.getListenPort()
secret = env.getSessionSecret()
###################################

##################################
## Express configuration
app.configure ->
  app.set 'views', __dirname + '/views'
  app.set 'view engine', 'jade'
  app.use express.static __dirname + '/public'
  ################################
  ## Session support
  MemStore = require('connect').session.MemoryStore
  app.use express.cookieParser()
  app.use(express.session({secret: secret, store: MemStore({reapInterval: 60000*10})}))
  ################################
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use app.router

app.configure 'development', ->
  app.use express.errorHandler
    dumpExceptions: true
    showStack: true

app.configure 'production', ->
  app.use express.errorHandler()
##################################


###################################
## Handle authentication
# TODO make sure authenticated
# sessions are all over TLS

## login ##
app.get '/_login', (req,res) ->
  if req.session.user
    res.redirect '/', res
  else
    res.render '_login'
      layout: false

app.post '/_login', (req,res) ->

  login = req.body.login
  pwd   = req.body.password

  promise = auth.authenticate_user login, pwd, db
  promise
    .on 'failure', (msg) ->
      req.flash msg
      res.redirect '/_login'
    .on 'success', ->
      # successfully authenticated
      req.session.user = req.body.login
      res.redirect '/'

## sign up ##
app.get  '/_signup', (req,res) ->
  res.render '_signup'

app.post '/_signup', (req,res) ->
  admin_pwd = req.body.admin_pwd
  login     = req.body.login
  pwd       = req.body.password
  confirm   = req.body.confirm

  validate_promise = auth.validate_signup admin_pwd,login,pwd,confirm,db
  validate_promise
    .on 'failure', (msg) ->
      req.flash msg
      res.redirect '/_signup'
    .on 'success', ->
      create_promise = auth.create_user admin_pwd,login,pwd,confirm,db
      create_promise
        .on 'success', ->
          res.redirect '/_login'

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
app.post '/save', auth.requiresAuth, (req,res) ->

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