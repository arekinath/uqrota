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
    @s = Rota::APISession.from_session(session)
    if request.env['ORIGIN'] =~ /^https:\/\/uqrota\.net\/(.+)$/
      response.headers['Access-Control-Allow-Origin'] = request.env['ORIGIN']
    elsif request.env['HTTP_ORIGIN'] =~ /^https:\/\/www\.uqrota\.net\/(.+)$/
      response.headers['Access-Control-Allow-Origin'] = request.env['HTTP_ORIGIN']
    end
  end
  
  after do
    @s.save
  end
  
  post '/login.json' do
    content_type :json
    user = Rota::User.get(params[:email])
    if not user.nil? and user.is_password?(params[:password])
      @s.logged_in = true
      @s.user = user
      Utils.json { |j| j.success true; j.secret @s.secret }
    else
      @s.logged_in = false
      Utils.json { |j| j.success false }
    end
  end
  
  get '/login.json' do
    content_type :json
    if @s.logged_in
      Utils.json do |j|
        j.logged_in true
        j.email @s.user.email
        j.secret @s.secret
      end
    else
      Utils.json { |j| j.logged_in false }
    end
  end
  
  post '/logout.json' do
    content_type :json
    @s.logged_in = false
    @s.user = nil
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
    @s = Rota::APISession.from_session(session)
  end
  
  after do
    @s.save
  end
  
  get '/me/semester_plans.json' do
    content_type :json
    Utils.json do |j|
      j.plans(:array) do |ar|
        session[:user].semester_plans.each do |sp|
          ar.object do |obj|
            sp.to_json(obj, :no_children)
          end
        end        
      end
    end
  end
end