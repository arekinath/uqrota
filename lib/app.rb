require 'config'
require 'webapi/data'
require 'webapi/user'
require 'sinatra/base'

class RotaApp < Sinatra::Base
  set :views, Rota::ViewsDir
  set :public, Rota::PublicDir
  set :root, Rota::RootDir
  
  set :sessions, true
  
  mime_type :xml, 'text/xml'
  mime_type :json, 'application/json'
  mime_type :ical, 'text/calendar'
  mime_type :plain, 'text/plain'
  
  use DataService
  use LoginService
  use UserService
end
