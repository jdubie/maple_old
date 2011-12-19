fs = require 'fs'
_  = require 'underscore'

module.exports = (root_dir) ->

  ############################################
  ## Build out directory tree
  #   /maple
  #     /public
  #       /images
  #       /javascripts
  #       /styles
  #     /views
  #     /db
  #
  root_dir  = 'maple' unless root_dir?
  root_dirs = ['views','db','public']
  fs.mkdirSync root_dir, 0755
  _.each root_dirs, (dir) -> fs.mkdirSync "#{root_dir}/#{dir}", 0755

  public_dirs = ['images','javascripts','styles']
  _.each public_dirs, (dir) -> fs.mkdirSync "#{root_dir}/public/#{dir}", 0755
  ############################################


  ############################################
  ## Add initial files
  maple_dir = "#{process.env._}/../.."
  cur_dir   = process.env.PWD

  ## pwd.json
  init_pwd = fs.readFileSync "#{maple_dir}/pwd.json"
  fs.writeFileSync "#{root_dir}/pwd.json", init_pwd

  ## javascript files
  jquery = fs.readFileSync "#{maple_dir}/public/javascripts/jquery.min.js"
  jeditable = fs.readFileSync "#{maple_dir}/public/javascripts/jeditable.mini.js"
  fs.writeFileSync "#{root_dir}/public/javascripts/jquery.min.js", jquery
  fs.writeFileSync "#{root_dir}/public/javascripts/jeditable.min.js", jeditable

  ## seed file
  seed = fs.readFileSync "#{maple_dir}/db/seed.json"
  fs.writeFileSync "#{root_dir}/db/seed.json", seed
  #############################################
