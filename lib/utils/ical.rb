require 'rubygems'
require 'ri_cal'
require 'date'
require 'time'

module Rota
  
  class TimetableEvent
    def to_ical(cal)
      cal.event do |event|
        event.dtstart = self.start_dt.to_time.utc
        event.dtend = self.finish_dt.to_time.utc
        event.summary = self.session.group.fancy_name
        event.location = self.session.building.room(self.session.room)
      end
    end
  end
  
  class TimetableSession
    def to_ical(cal)
      self.events.each do |ev|
        ev.to_ical(cal)
      end
    end
  end
  
  class TimetableGroup
    def to_ical(cal, excepts=[])
      self.sessions.each do |s|
        unless excepts.include?(s)
          s.to_ical(cal)
        end
      end
    end
  end
  
  class TimetableSeries
    def to_ical(cal, excepts=[])
      self.groups.each do |g|
        unless excepts.include?(g)
          g.to_ical(cal, excepts)
        end
      end
    end
  end
  
  class Offering
    def to_ical(cal, type=:timetable, excepts=[])
      if type == :timetable
        self.series.each do |s|
          unless excepts.include?(s)
            s.to_ical(cal, excepts)
          end
        end
      elsif type == :assessment
        
      end
    end
  end
  
  class Timetable
    def to_ical(cal)
      self.groups.each do |g|
        g.to_ical(cal, self.hidden_sessions)
      end
    end
  end
  
end

module Utils
  
  def self.ical(&block)
    ical = RiCal.Calendar do |cal|
      block(cal)
    end
    ical.to_s
  end

end
