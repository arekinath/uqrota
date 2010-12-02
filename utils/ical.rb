require 'rubygems'
require 'ri_cal'
require 'date'
require 'time'

module Utils
  
  class TimetableToIcalConverter
    def initialize(timetable)
      @timetable = timetable
    end
    
    def to_ical
      cal = RiCal.Calendar do |cal|
	@timetable.groups.each do |g|
	  g.sessions.each do |s|
	    s.events.each do |e|
              if e.taught
	      cal.event do |event|
		event.dtstart = e.start_dt.to_time.utc
		event.dtend = e.finish_dt.to_time.utc
		event.summary = g.fancy_name
		event.location = s.building + " " + s.room
	      end
              end
	    end
	  end
	end
      end
      cal.to_s
    end
  end
  
end
