require 'rubygems'
require 'config'
require 'rota/model'
require 'rota/temporal'
require 'sinatra/base'

class UserService < Sinatra::Base
  enable :sessions
  
  mime_type :xml, 'text/xml'
  mime_type :json, 'text/javascript'
  mime_type :ical, 'text/calendar'
  mime_type :plain, 'text/plain'
  
  post '/login.json' do
    user = User.get(params[:email])
    if not user.nil? and user.is_password?(params[:password])
      session[:user] = user
    end
  end
  
  get '/login.json' do
    if session[:user]
      Utils.json do |j|
        j.logged_in true
        j.email session[:user].email
      end
    else
      Utils.json do |j|
        j.logged_in false
      end
    end
  end
  
  post '/logout.json' do
    
  end
end