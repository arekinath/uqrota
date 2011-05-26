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
    
    get '/planbox/:id.json' do
      content_type :json
      planbox = Rota::PlanBox.get(params[:id])
      if planbox.nil?
        404
      elsif @s.user != planbox.user
        403
      else
        planbox.to_json
      end
    end
    
    post '/planbox/:id.json' do |id|
      content_type :json
      planbox = Rota::PlanBox.get(id)
      if planbox.nil?
        404
      elsif @s.user != planbox.user
        403
      else
        planbox.update(params[:planbox])
        planbox.to_json
      end
    end
    
    delete '/planbox/:id.json' do |id|
      content_type :json
      planbox = Rota::PlanBox.get(id)
      if planbox.nil?
        404
      elsif @s.user != planbox.user
        403
      else
        planbox.destroy!
        { :success => true }.to_json
      end
    end
    
    put '/planboxes/new.json' do
      content_type :json
      
      hash = params[:planbox]
      hash['semester'] = Rota::Semester.get(hash[:semester][:id])
      hash['user'] = @s.user
      
      planbox = Rota::PlanBox.create(hash)
      planbox.to_json
    end
    
    get '/timetable/:id.json' do
      content_type :json
      tt = Rota::Timetable.get(params[:id])
      if tt.nil?
        404
      elsif tt.plan_box.user != @s.user
        403
      else
        tt.to_json
      end
    end
    
    post '/timetable/:id.json' do
      content_type :json
      tt = Rota::Timetable.get(params[:id])
      if tt.nil?
        404
      elsif tt.plan_box.user != @s.user
        403
      else
        tt.update(params[:timetable])
        tt.to_json
      end
    end
    
    delete '/timetable/:id.json' do |id|
      content_type :json
      tt = Rota::Timetable.get(id)
      if tt.nil?
        404
      elsif @s.user != tt.plan_box.user
        403
      else
        tt.destroy!
        { :success => true }.to_json
      end
    end
    
    put '/planbox/:pbid/timetables/new.json' do
      content_type :json
      pb = Rota::PlanBox.get(params[:pbid])
      if pb.nil?
        404
      elsif pb.user != @s.user
        403
      else
        tt = Rota::Timetable.create(params[:timetable])
        tt.plan_box = pb
        tt.save
        tt.to_json
      end
    end
    
    get '/course_selection/:id.json' do
      content_type :json
      cs = Rota::CourseSelection.get(params[:id])
      if cs.nil?
        404
      elsif cs.timetable.plan_box.user != @s.user
        403
      else
        cs.to_json
      end
    end
    
    post '/course_selection/:id.json' do
      content_type :json
      x = Rota::CourseSelection.get(params[:id])
      if x.nil?
        404
      elsif x.timetable.plan_box.user != @s.user
        403
      else
        x.update(params[:course_selection])
        x.to_json
      end
    end
    
    put '/timetable/:ttid/course_selections/new.json' do
      content_type :json
      tt = Rota::Timetable.get(params[:ttid])
      if tt.nil?
        404
      elsif tt.plan_box.user != @s.user
        403
      else
        x = Rota::CourseSelection.create(params[:course_selection])
        x.timetable = tt
        x.save
        x.to_json
      end
    end
    
    get '/series_selection/:id.json' do
      content_type :json
      ss = Rota::SeriesSelection.get(params[:id])
      if ss.nil?
        404
      elsif ss.course_selection.timetable.plan_box.user != @s.user
        403
      else
        ss.to_json
      end
    end
    
    post '/series_selection/:id.json' do
      content_type :json
      x = Rota::SeriesSelection.get(params[:id])
      if x.nil?
        404
      elsif x.timetable.plan_box.user != @s.user
        403
      else
        x.update(params[:course_selection])
        x.to_json
      end
    end
    
    put '/course_selection/:csid/series_selections/new.json' do
      content_type :json
    end
    
    get '/group_selection/:id.json' do
      content_type :json
      gs = Rota::GroupSelection.get(params[:id])
      if gs.nil?
        404
      elsif gs.course_selection.timetable.plan_box.user != @s.user
        403
      else
        gs.to_json
      end
    end
    
    post '/group_selection/:id.json' do
      content_type :json
    end
    
    put '/course_selection/:csid/group_selections/new.json' do
      content_type :json
      
    end
    
    get '/share/:hashcode.json' do
      content_type :json
      sh = Rota::SharingLink.get(params[:hashcode])
      sh.to_json
    end
  end
end