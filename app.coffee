express     = require 'express'
fs          = require 'fs'
events      = require 'events'
_           = require 'underscore'
async       = require 'async'
constants   = require './env/constants'
crypto      = require 'crypto'

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

app.post '/_login', (req,res) ->

  login = req.body.login
  pwd   = req.body.password

  promise = authenticate_user login, pwd
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

  # make sure username doesn't already exist
  unique = (cb) ->
    db.get login, (err,body) ->
      if err.error == 'not_found' and err.reason == 'missing'
        cb 'unique'
      else cb null

  # make sure passwords match
  match = (cb) ->
    if pwd != confirm
      cb null
    else cb 'match'

  # authenticate admin's password
  authed = (cb) ->
    promise = authenticate_user 'admin', admin_pwd
    promise.on 'success', -> cb 'authed'
    promise.on 'failure', -> cb null

  async.parallel [
   unique
   match
   authed
  ], (err,res) ->
    if res[0]? and res[1]? and res[2]?
      ## create user
      # hash their password
      pwd_sum = crypto.createHash 'sha256'
      pwd_sum.update pwd
      hashed_pwd_buf = new Buffer(pwd_sum.digest('base64'),'base64')

      # pick random salt same length as password
      salt = Math.random().toString() # pseudo random seed to hash function
      salt_sum = crypto.createHash 'sha256'
      salt_sum.update salt
      salt = salt_sum.digest 'base64'

      # store salt + password
      salted_pwd_buf = new Buffer(salt.length)
      salt_buf = new Buffer(salt,'base64')
      for i in [0...salt_buf.length]
        salted_pwd_buf = salt_buf[i] ^ hashed_pwd_buf[i]
      salted_pwd = salted_pwd_buf.toString('base64')

      db.insert {salted_pwd,salt}, login, (err,res) ->
        res.redirect '/_login'

## Authentication Middleware ##
authenticate_user = (login,password) ->
  promise = new (events.EventEmitter)

  # hash supplied password
  shasum = crypto.createHash('sha256')
  shasum.update password
  hash_pwd = new Buffer(shasum.digest('base64'),'base64')

  # look up user's hashed password
  # plus random salt entry
  # TODO CouchDB escape supplied username
  db.get login, (err,doc) ->
    if err
      promise.emit 'failure', 'login name does not exist'
      return
    else
      hash_plus_salt = new Buffer(doc.salted_pwd,'base64')
      salt = new Buffer(doc.salt,'base64')

      # compare hash of supplied password XOR salt
      # to the db entry of password XOR salt
      for i in [0...salt.length]
        if (salt[i] ^ hash_pwd[i]) != hash_plus_salt[i]
          promise.emit 'failure', 'invalid password username combo'
          return # so don't emit success

      promise.emit 'success'

  return promise


requiresAuth = (req,res,next) ->
  if req.session.user
    next()
  else
    res.end '*** login first at /_login'
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
app.post '/save', requiresAuth, (req,res) ->

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