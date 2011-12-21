module.exports =

  create_user: (admin_pwd,login,pwd,confirm,db) ->
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

  signup_user: (admin_pwd,login,pwd,confirm,db) ->

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

        create_user

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


  requiresAuth: (req,res,next) ->
    if req.session.user
      next()
    else
      res.end '*** login first at /_login'
