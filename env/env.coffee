fs = require 'fs'

pwd = fs.readFileSync "#{process.env.PWD}/pwd.json"
pwd = JSON.parse pwd

env = 'development'
env = 'production' if process.env.NODE_ENV == 'production'

pwd = pwd[env];

## setup db
nano = require('nano')("http://#{pwd.db_uname}:#{pwd.db_pwd}@#{pwd.db_host}:#{pwd.db_port}")


module.exports =

  getDb: -> nano
  getDbConn: -> nano.use pwd.db_name
  getDbName: -> pwd.db_name

  getListenPort: -> pwd.listen_port