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
    content_type :json
    user = Rota::User.get(params[:email])
    if not user.nil? and user.is_password?(params[:password])
      session[:user] = user
      Utils.json { |j| j.success true }
    else
      Utils.json { |j| j.success false }
    end
  end
  
  get '/login.json' do
    content_type :json
    if session[:user]
      Utils.json do |j|
        j.logged_in true
        j.email session[:user].email
      end
    else
      Utils.json { |j| j.logged_in false }
    end
  end
  
  post '/logout.json' do
    content_type :json
    session[:user] = nil
    Utils.json { |j| j.success true }
  end
end