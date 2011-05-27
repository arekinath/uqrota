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
        hash = params[:planbox]
        hash['user'] = @s.user
        planbox.update(hash)
        planbox.to_json
      end
    end
    
    post '/planbox/:id/courses.json' do |id|
      content_type :json
      planbox = Rota::PlanBox.get(id)
      if planbox.nil?
        404
      elsif @s.user != planbox.user
        403
      else
        csl = params[:courses] || []
        courses = []
        csl.each do |k,v|
          courses << Rota::Course.get(v['code'])
        end
        planbox.courses = courses
        planbox.save
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
        planbox.courses = []
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
      
      hash = params[:timetable]
      hash['plan_box'] = Rota::PlanBox.get(hash[:plan_box][:id])
      
      if tt.nil?
        404
      elsif tt.plan_box.user != @s.user or hash['plan_box'].nil? or hash['plan_box'].user != @s.user
        403
      else
        tt.update(hash)
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
    
    put '/timetables/new.json' do
      content_type :json
      
      hash = params[:timetable]
      hash['plan_box'] = Rota::PlanBox.get(hash[:plan_box][:id])
      
      if hash['plan_box'].nil?
        404
      elsif hash['plan_box'].user != @s.user
        403
      else
        timetable = Rota::Timetable.create(hash)
        timetable.to_json
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
      cs = Rota::CourseSelection.get(params[:id])
      
      hash = params[:courseselection]
      hash['timetable'] = Rota::Timetable.get(hash[:timetable][:id])
      
      if cs.nil?
        404
      elsif cs.timetable.plan_box.user != @s.user
        403
      elsif hash['timetable'].nil? or hash['timetable'].plan_box.user != @s.user
        403
      else
        cs.update(hash)
        cs.to_json
      end
    end
    
    delete '/course_selection/:id.json' do |id|
      content_type :json
      cs = Rota::CourseSelection.get(id)
      if cs.nil?
        404
      elsif @s.user != cs.timetable.plan_box.user
        403
      else
        cs.destroy!
        { :success => true }.to_json
      end
    end
    
    put '/course_selections/new.json' do
      content_type :json
      
      hash = params[:courseselection]
      hash['timetable'] = Rota::Timetable.get(hash[:timetable][:id])
      
      if hash['timetable'].nil?
        404
      elsif hash['timetable'].plan_box.user != @s.user
        403
      else
        cs = Rota::CourseSelection.create(hash)
        cs.to_json
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
      ss = Rota::SeriesSelection.get(params[:id])
      
      hash = params[:seriesselection]
      hash['course_selection'] = Rota::CourseSelection.get(hash[:course_selection][:id])
      
      if ss.nil?
        404
      elsif ss.course_selection.timetable.plan_box.user != @s.user
        403
      elsif hash['course_selection'].nil? or hash['course_selection'].timetable.plan_box.user != @s.user
        403
      else
        ss.update(hash)
        ss.to_json
      end
    end
    
    delete '/series_selection/:id.json' do |id|
      content_type :json
      ss = Rota::SeriesSelection.get(id)
      if ss.nil?
        404
      elsif @s.user != ss.course_selection.timetable.plan_box.user
        403
      else
        ss.destroy!
        { :success => true }.to_json
      end
    end
    
    put '/series_selections/new.json' do
      content_type :json
      
      hash = params[:seriesselection]
      hash['course_selection'] = Rota::CourseSelection.get(hash[:course_selection][:id])
      
      if hash['course_selection'].nil?
        404
      elsif hash['course_selection'].timetable.plan_box.user != @s.user
        403
      else
        o = Rota::SeriesSelection.create(hash)
        o.to_json
      end
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
      gs = Rota::GroupSelection.get(params[:id])
      
      hash = params[:groupselection]
      hash['course_selection'] = Rota::CourseSelection.get(hash[:course_selection][:id])
      
      if gs.nil?
        404
      elsif gs.course_selection.timetable.plan_box.user != @s.user
        403
      elsif hash['course_selection'].nil? or hash['course_selection'].timetable.plan_box.user != @s.user
        403
      else
        gs.update(hash)
        gs.to_json
      end
    end
    
    delete '/group_selection/:id.json' do |id|
      content_type :json
      gs = Rota::GroupSelection.get(id)
      if gs.nil?
        404
      elsif @s.user != gs.course_selection.timetable.plan_box.user
        403
      else
        gs.destroy!
        { :success => true }.to_json
      end
    end
    
    put '/group_selections/new.json' do
      content_type :json
      
      hash = params[:groupselection]
      hash['course_selection'] = Rota::CourseSelection.get(hash[:course_selection][:id])
      
      if hash['course_selection'].nil?
        404
      elsif hash['course_selection'].timetable.plan_box.user != @s.user
        403
      else
        o = Rota::GroupSelection.create(hash)
        o.to_json
      end
    end
    
    get '/share/:hashcode.json' do
      content_type :json
      sh = Rota::SharingLink.get(params[:hashcode])
      sh.to_json
    end
  end
end