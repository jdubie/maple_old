events = require 'events'
crypto = require 'crypto'
async  = require 'async'
_      = require 'underscore'

MIN_LENGTH = 5

module.exports =

  signup_user: (admin_pwd,login,pwd,confirm,db) ->
    promise = new (events.EventEmitter)

    valid_promise = @valid_request admin_pwd,login,pwd,confirm,db, (res) ->
    valid_promise
      .on 'success', =>
        create_promise = @create_user login,pwd,db
        create_promise
          .on 'success', ->
            promise.emit 'success', login
          .on 'error', (msg) ->
            promise.emit msg
      .on 'error', (msg) ->
        promise.emit 'error', msg

    return promise


  create_user: (login,pwd,db,rev) ->
    promise = new (events.EventEmitter)

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
      salted_pwd_buf[i] = salt_buf[i] ^ hashed_pwd_buf[i]
    salted_pwd = salted_pwd_buf.toString('base64')
    # salted_pwd = 'pwd, im salty'
    # console.error salted_pwd_buf

    doc = {salted_pwd,salt}
    doc._rev = rev if rev?

    db.insert doc, login, (err,res) ->
      if err
        promise.emit 'error', err
      else
        promise.emit 'success'

    return promise


  valid_request: (admin_pwd,login,pwd,confirm,db) ->

    promise = new (events.EventEmitter)

    # make sure password is long enough
    if pwd.length < MIN_LENGTH
      process.nextTick ->
        promise.emit 'error', 'password is too short'
      return promise

    # make sure passwords match
    if pwd != confirm
      process.nextTick ->
        promise.emit 'error', 'passwords don\'t match'
      return promise

    # make sure username doesn't already exist
    db.get login, (err,body) =>
      if err? and err.error == 'not_found'
        # make sure admin password is correct
        auth_promise = @authenticate_user 'admin',admin_pwd,db
        auth_promise.on 'success', ->
          promise.emit 'success', login
        auth_promise.on 'error', ->
          promise.emit 'error', 'admin password invalid'
      else
        promise.emit 'error', 'login name already exists'

    return promise

  authenticate_user: (login,password,db) ->
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
        promise.emit 'error', 'login name does not exist'
        return
      else
        hash_plus_salt = new Buffer(doc.salted_pwd,'base64')
        salt = new Buffer(doc.salt,'base64')

        # compare hash of supplied password XOR salt
        # to the db entry of password XOR salt
        for i in [0...salt.length]
          if (salt[i] ^ hash_pwd[i]) != hash_plus_salt[i]
            promise.emit 'error', 'invalid password username combo'
            return # so don't emit success

        promise.emit 'success', login

    return promise

  ################################
  ## Authentication middleware
  requiresAuth: (req,res,next) ->
    if req.session.user
      next()
    else
      res.end '*** login first at /_login'
  ##################################