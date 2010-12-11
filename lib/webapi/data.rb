require 'rubygems'
require 'config'
require 'rota/model'
require 'utils/ical'
require 'utils/xml'
require 'sinatra/base'

class DataService < Sinatra::Base
  mime_type :xml, 'text/xml'
  mime_type :ical, 'text/calendar'
  
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
  
  get '/course/:code.xml' do |code|
    content_type :xml
    course = Rota::Course.get(code.upcase)
    return 404 if course.nil?
    Utils.xml(course)
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
