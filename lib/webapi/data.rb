require 'rubygems'
require 'config'
require 'rota/model'
require 'utils/ical'
require 'utils/json'
require 'utils/xml'
require 'rota/temporal'
require 'sinatra/base'

class << Sinatra::Base
  def http_options path,opts={}, &blk
    route 'OPTIONS', path, opts, &blk
  end
end
Sinatra::Delegator.delegate :http_options 

class DataService < Sinatra::Base
  mime_type :xml, 'text/xml'
  mime_type :json, 'text/javascript'
  mime_type :ical, 'text/calendar'
  
  http_options /.+/ do
    content_type = 'text/plain'
    response.headers['Access-Control-Allow-Origin'] = request.env['Origin']
    response.headers['Access-Control-Allow-Methods'] = 'HEAD, POST, GET, PUT, DELETE, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = request.env['Access-Control-Request-Headers']
    response.headers['Access-Control-Max-Age'] = '1200'
    ''
  end
  
  get '/programs/undergrad.xml' do
    content_type :xml
    Utils.xml do |x|
      x.programs do |b|
        Rota::Program.all.each do |prog|
          prog.to_xml(b, :no_children)
        end
      end
    end
  end
  
  get '/programs/undergrad.json' do
    content_type :json
    Utils.json do |x|
      x.programs(:array) do |a|
        Rota::Program.all.each do |prog|
          a.object do |o|
            prog.to_json(o, :no_children)
          end
        end
      end
    end
  end
  
  get '/program/:id.xml' do |id|
    content_type :xml
    prog = Rota::Program.get(id.to_i)
    return 404 if prog.nil?
    Utils.xml(prog)
  end
  
  get '/program/:id.json' do |id|
    content_type :json
    prog = Rota::Program.get(id.to_i)
    return 404 if prog.nil?
    Utils.json(prog)
  end
  
  get '/plan/:id.xml' do |id|
    content_type :xml
    plan = Rota::Plan.get(id.to_i)
    return 404 if plan.nil?
    Utils.xml(plan)
  end
  
  get '/plan/:id.json' do |id|
    content_type :json
    plan = Rota::Plan.get(id.to_i)
    return 404 if plan.nil?
    Utils.json(plan)
  end
  
  get '/semesters.xml' do
    content_type :xml
    Utils.xml do |x|
      x.semesters do |b|
        Rota::Semester.all.each do |sem|
          hash = {}
          hash[:current] = 'true' if sem == Rota::Semester.current
          b.semester(sem['id'], hash)
        end
      end
    end
  end
  
  get '/semesters.json' do
    content_type :json
    Utils.json do |x|
      x.semesters(:array) do |b|
        Rota::Semester.all.each do |sem|
          b.object do |o|
            o.id(sem['id'])
            o.current('true') if sem == Rota::Semester.current
          end
        end
      end
    end
  end
  
  get '/semester/:id.xml' do |id|
    content_type :xml
    sem = Rota::Semester.get(id.to_i)
    if sem.nil?
      if id == 'current'
        sem = Rota::Semester.current
      else
        return 404
      end
    end
    Utils.xml(sem)
  end
  
  get '/semester/:id.json' do |id|
    content_type :json
    sem = Rota::Semester.get(id.to_i)
    if sem.nil?
      if id == 'current'
        sem = Rota::Semester.current
      else
        return 404
      end
    end
    Utils.json(sem)
  end
  
  get '/semester/:id.ics' do |id|
    content_type :ical
    sem = Rota::Semester.get(id.to_i)
    return 404 if sem.nil?
    Utils.ical(sem)
  end
  
  get '/semester/:id/courses.xml' do |id|
    content_type :xml
    sem = Rota::Semester.get(id.to_i)
    return 404 if sem.nil?
    Utils.xml do |b|
      b.semester do |s|
        s.id(sem['id'])
        s.courses do |cs|
          sem.offerings.each do |o|
            cs.course(o.course.code)            
          end
        end
      end
    end
  end
  
  get '/semester/:id/courses.json' do |id|
    content_type :json
    sem = Rota::Semester.get(id.to_i)
    return 404 if sem.nil?
    Utils.json do |x|
      x.courses(:array) do |a|
        sem.offerings.each do |off|
          a << off.course.code
        end
      end
    end
  end
  
  get '/course/:code.xml' do |code|
    content_type :xml
    course = Rota::Course.get(code.upcase)
    return 404 if course.nil?
    Utils.xml(course)
  end
  
  get '/course/:code.json' do |code|
    content_type :json
    course = Rota::Course.get(code.upcase)
    return 404 if course.nil?
    Utils.json(course)
  end
  
  get '/course/:code/plans.xml' do |code|
    content_type :xml
    course = Rota::Course.get(code.upcase)
    return 404 if course.nil?
    Utils.xml do |x|
      x.plans do |b|
        course.course_groups.plans.uniq.each do |pl|
          b.plan do |p|
            p.id(pl['id'])
            b.name(pl.name)
            b.program do |pg|
              pg.id(pl.program['id'])
              pg.name(pl.program.name)
            end
          end
        end
      end
    end
  end
  
  get '/course/:code/plans.json' do |code|
    content_type :json
    course = Rota::Course.get(code.upcase)
    return 404 if course.nil?
    Utils.json do |j|
      j.plans(:array) do |a|
        course.course_groups.plans.uniq.each do |pl|
          a.object do |obj|
            obj.id(pl['id'])
            obj.name(pl.name)
            obj.program do |pg|
              pg.id(pl.program['id'])
              pg.name(pl.program.name)
            end
          end
        end
      end
    end
  end
  
  get '/course/:code.ics' do |code|
    content_type :ical
    course = Rota::Course.get(code.upcase)
    return 404 if course.nil?
    Utils.ical(course)
  end
  
  get '/clashes/:id1/:id2.xml' do |id1, id2|
    content_type :xml
    o1 = Rota::Offering.get(id1.to_i)
    o2 = Rota::Offering.get(id2.to_i)
    return 404 if o1.nil? or o2.nil?
    cs = Rota::ClashSummary.new(o1, o2)
    Utils.xml(cs)
  end
  
  get '/offering/:id.xml' do |id|
    content_type :xml
    offering = Rota::Offering.get(id.to_i)
    return 404 if offering.nil?
    Utils.xml(offering)
  end
  
  get '/offering/:id.json' do |id|
    content_type :json
    offering = Rota::Offering.get(id.to_i)
    return 404 if offering.nil?
    Utils.json(offering)
  end
  
  get '/offering/:id.ics' do |id|
    content_type :ical
    offering = Rota::Offering.get(id.to_i)
    return 404 if offering.nil?
    Utils.ical do |i|
      offering.to_ical(i, :all)
    end
  end
  
  get '/offering/:id/assessment.ics' do |id|
    content_type :ical
    offering = Rota::Offering.get(id.to_i)
    return 404 if offering.nil?
    Utils.ical do |i|
      offering.to_ical(i, :assessment)
    end
  end
  
  get '/offering/:id/timetable.ics' do |id|
    content_type :ical
    offering = Rota::Offering.get(id.to_i)
    return 404 if offering.nil?
    Utils.ical do |i|
      offering.to_ical(i, :timetable)
    end
  end
  
  get '/group/:id.xml' do |id|
    content_type :xml
    group = Rota::TimetableGroup.get(id.to_i)
    return 404 if group.nil?
    Utils.xml(group)
  end
  
  get '/group/:id.ics' do |id|
    content_type :ical
    group = Rota::TimetableGroup.get(id.to_i)
    return 404 if group.nil?
    Utils.ical(group)
  end
  
  get '/session/:id.xml' do |id|
    content_type :xml
    session = Rota::TimetableSession.get(id.to_i)
    return 404 if session.nil?
    Utils.xml(session)
  end
  
  get '/session/:id.ics' do |id|
    content_type :ical
    session = Rota::TimetableSession.get(id.to_i)
    return 404 if session.nil?
    Utils.ical(session)
  end
end
