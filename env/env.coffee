fs = require 'fs'

pwd = fs.readFileSync './env/pwd.json'
pwd = JSON.parse pwd

env = 'development'
env = 'production' if process.env.NODE_ENV == 'production'

pwd = pwd[env];

module.exports =

  getDbConn: ->
    nano = require('nano')("http://#{pwd.db_uname}:#{pwd.db_pwd}@#{pwd.db_host}:#{pwd.db_port}")
    db   = nano.use pwd.db_name
