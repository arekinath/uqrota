require 'rubygems'
require 'config'
require 'rota/model'
require 'rota/temporal'
require 'webapi/common'
require 'sinatra/base'
require 'sinatra/namespace'

class << Sinatra::Base
  def http_options path,opts={}, &blk
    route 'OPTIONS', path, opts, &blk
  end
end
Sinatra::Delegator.delegate :http_options 

class LoginService < Sinatra::Base
  register Sinatra::Namespace
  enable :sessions
  
  namespace '/user' do
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
      user = Rota::User.first(:email => params[:email])
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
    
    put '/me.json' do
      content_type :json
      begin
        user = Rota::User.create(params[:user])
        user.save
        @s.user = user
        return { :success => true, :user => user, :secret => @s.secret }.to_json
      rescue DataMapper::SaveFailureError => boom
        return { :success => false }
      end
    end
    
    get '/count.json' do
      content_type :json
      fc = FindConditions.new(Rota::User, params[:with])
      { :count => fc.results.size }.to_json
    end
    
    get '/me.json' do
      content_type :json
      if @s.logged_in
        @s.user.to_json
      else
        404
      end
    end
  
    post '/me.json' do
      content_type :json
      if @s.logged_in
        @s.user.update(params[:user])
        @s.user.to_json
      else
        404
      end
    end
    
    post '/logout.json' do
      content_type :json
      @s.logged_in = false
      @s.user = nil
      { :success => true }.to_json
    end
    
    get '/:id.json' do |id|
      content_type :json
      if @s.logged_in and @s.user.id == id.to_i
        @s.user.to_json
      else
        404
      end
    end
    
    post '/:id.json' do |id|
      content_type :json
      if @s.logged_in and @s.user.id == id.to_i
        @s.user.update(params[:user])
        @s.user.to_json
      else
        404
      end
    end
  end
end

class UserService < Sinatra::Base
  register Sinatra::Namespace
  enable :sessions
  
  namespace '/my' do
    before do
      if request.env['ORIGIN'] =~ /^https:\/\/uqrota\.net\/(.+)$/
        response.headers['Access-Control-Allow-Origin'] = request.env['ORIGIN']
      elsif request.env['HTTP_ORIGIN'] =~ /^https:\/\/www\.uqrota\.net\/(.+)$/
        response.headers['Access-Control-Allow-Origin'] = request.env['HTTP_ORIGIN']
      else
        response.headers['Access-Control-Allow-Origin'] = "https://www.uqrota.net"
      end
    end
    
    before do
      @s = Rota::APISession.from_session(session)
      unless @s.logged_in and request.env['HTTP_X_API_SECRET'] == @s.secret
        halt(403)
      end
    end
    
    after do
      @s.save
    end
    
    rmap = {
            'planbox' => Rota::PlanBox,
            'timetable' => Rota::Timetable,
            'usersemester' => Rota::UserSemester,
            'courseselection' => Rota::CourseSelection,
            'seriesselection' => Rota::SeriesSelection,
            'groupselection' => Rota::GroupSelection
            }
    
    get '/:resource/:id.json' do |resource, id|
      content_type :json
      res = rmap[resource].get(id)
      if res.nil?
        404
      elsif not res.owned_by?(@s.user)
        403
      else
        res.to_json
      end
    end
    
    delete '/:resource/:id.json' do |resource, id|
      content_type :json
      res = rmap[resource].get(id)
      if res.nil?
        404
      elsif not res.owned_by?(@s.user)
        403
      else
        res.destroy!
        { :success => true }.to_json
      end
    end
    
    post '/:resource/:id.json' do |resource, id|
      content_type :json
      rcl = rmap[resource]
      res = rcl.get(id)
      if res.nil?
        404
      elsif not res.owned_by?(@s.user)
        403
      else
        hash = params[resource]
        rcl.relationships.each do |r|
          if r.min > 0
            keys = r.parent_model.collect { |k| k.name }
            keyvals = {}
            keys.each { |k| keyvals[k] = hash[r.name][k] }
            
            obj = r.parent_model.first(keyvals)
            if obj.nil? or (obj.responds_to?(:owned_by?) and not obj.owned_by?(@s.user))
              return 403
            end
            
            hash[r.name.to_s] = obj
          end
        end
        res.update(hash)
        res.to_json
      end
    end
    
    put '/:resource/new.json' do |resource|
      content_type :json
      rcl = rmap[resource]
      hash = params[resource]
      rcl.relationships.each do |r|
        if r.min > 0
          keys = r.parent_model.key.collect { |k| k.name }
          keyvals = {}
          keys.each { |k| keyvals[k] = hash[r.name][k] }
          
          obj = r.parent_model.first(keyvals)
          if obj.nil? or (obj.respond_to?(:owned_by?) and not obj.owned_by?(@s.user))
            return 403
          end
          
          hash[r.name.to_s] = obj
        end
      end
      res = rcl.create(hash)
      res.to_json
    end
    
    get '/share/:hashcode.json' do
      content_type :json
      sh = Rota::SharingLink.get(params[:hashcode])
      sh.to_json
    end
  end
end