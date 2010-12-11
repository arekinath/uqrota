require 'rubygems'
require 'config'
require 'rota/model'
require 'utils/ical'
require 'utils/xml'
require 'sinatra/base'

class DataService < Sinatra::Base
  mime_type :xml, 'text/xml'
  mime_type :json, 'text/javascript'
  mime_type :ics, 'text/calendar'
  
  get '/course/:code.xml' do |code|
    Utils.xml(Rota::Course.get(code.upcase))
  end
  
  get '/course/:code.ics' do |code|
    Utils.ical(Rota::Course.get(code.upcase))
  end
  
  get '/offering/:id.xml' do |id|
    Utils.xml(Rota::Offering.get(id.to_i))
  end
  
  get '/offering/:id.ics' do |id|
    Utils.ical(Rota::Offering.get(id.to_i))
  end
  
  get '/offering/:id/assessment.ics' do |id|
    Utils.ical do |i|
      Rota::Offering.get(id.to_i).to_ical(i, :assessment)
    end
  end
  
  get '/offering/:id/timetable.ics' do |id|
    Utils.ical do |i|
      Rota::Offering.get(id.to_i).to_ical(i, :timetable)
    end
  end
  
  get '/group/:id.xml' do |id|
    Utils.xml(Rota::TimetableGroup.get(id.to_i))
  end
  
  get '/group/:id.ics' do |id|
    Utils.ical(Rota::TimetableGroup.get(id.to_i))
  end
  
  get '/session/:id.xml' do |id|
    Utils.xml(Rota::TimetableSession.get(id.to_i))
  end
  
  get '/session/:id.ics' do |id|
    Utils.ical(Rota::TimetableSession.get(id.to_i))
  end
end
