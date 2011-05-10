require 'rubygems'
require 'config'
require 'rota/model'
require 'rota/temporal'
require 'sinatra/base'

class << Sinatra::Base
  def http_options path,opts={}, &blk
    route 'OPTIONS', path, opts, &blk
  end
end
Sinatra::Delegator.delegate :http_options 

class LoginService < Sinatra::Base
  enable :sessions
  
  mime_type :xml, 'text/xml'
  mime_type :json, 'text/javascript'
  mime_type :ical, 'text/calendar'
  mime_type :plain, 'text/plain'
  
  before do
    if request.env['ORIGIN'] =~ /^https:\/\/uqrota\.net\/(.+)$/
      response.headers['Access-Control-Allow-Origin'] = request.env['ORIGIN']
    elsif request.env['HTTP_ORIGIN'] =~ /^https:\/\/www\.uqrota\.net\/(.+)$/
      response.headers['Access-Control-Allow-Origin'] = request.env['HTTP_ORIGIN']
    end
  end
  
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

class UserService < Sinatra::Base
  enable :sessions
  
  before do
    if request.env['ORIGIN'] =~ /^https:\/\/uqrota\.net\/(.+)$/
      response.headers['Access-Control-Allow-Origin'] = request.env['ORIGIN']
    elsif request.env['HTTP_ORIGIN'] =~ /^https:\/\/www\.uqrota\.net\/(.+)$/
      response.headers['Access-Control-Allow-Origin'] = request.env['HTTP_ORIGIN']
    end
  end
  
  mime_type :xml, 'text/xml'
  mime_type :json, 'text/javascript'
  mime_type :ical, 'text/calendar'
  mime_type :plain, 'text/plain'
  
  before do
    unless session[:user]
      halt(403)
    end
  end
  
  get '/timetables.json' do
    content_type :json
    Utils.json { |j| j.test true }
  end
end