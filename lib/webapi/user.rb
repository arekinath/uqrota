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
    else
      response.headers['Access-Control-Allow-Origin'] = "https://www.uqrota.net"
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
      { :success => true, :secret => @s.secret }.to_json
    else
      @s.logged_in = false
      { :success => false }.to_json
    end
  end
  
  get '/login.json' do
    content_type :json
    if @s.logged_in
      { :logged_in => true, :email => @s.user.email, :secret => @s.secret }.to_json
    else
      { :logged_in => false }.to_json
    end
  end
  
  post '/logout.json' do
    content_type :json
    @s.logged_in = false
    @s.user = nil
    { :success => true }.to_json
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
    unless @s.logged_in and request.env['HTTP_X_API_SECRET'] == @s.secret
      halt(403)
    end
  end
  
  after do
    @s.save
  end
  
  get '/planbox/mine.json' do
    content_type :json
    Utils.json do |j|
      j.planboxes(:array) do |a|
        @s.user.plan_boxes.each do |pb|
          a.object do |obj|
            pb.to_json(obj)
          end
        end
      end
    end
  end
end