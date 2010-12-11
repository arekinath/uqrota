require 'rubygems'
require 'config'
require 'rota/model'
require 'utils/ical'
require 'utils/xml'
require 'sinatra/base'

class DataService < Sinatra::Base
  mime_type :xml, 'text/xml'
  mime_type :ical, 'text/calendar'
  
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
  
  get '/program/:id.xml' do |id|
    content_type :xml
    prog = Rota::Program.get(id.to_i)
    return 404 if prog.nil?
    Utils.xml(prog)
  end
  
  get '/plan/:id.xml' do |id|
    content_type :xml
    plan = Rota::Plan.get(id.to_i)
    return 404 if plan.nil?
    Utils.xml(plan)
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
  
  get '/course/:code.xml' do |code|
    content_type :xml
    course = Rota::Course.get(code.upcase)
    return 404 if course.nil?
    Utils.xml(course)
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
  
  get '/course/:code.ics' do |code|
    content_type :ical
    course = Rota::Course.get(code.upcase)
    return 404 if course.nil?
    Utils.ical(course)
  end
  
  get '/offering/:id.xml' do |id|
    content_type :xml
    offering = Rota::Offering.get(id.to_i)
    return 404 if offering.nil?
    Utils.xml(offering)
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
