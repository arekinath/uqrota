require 'rubygems'
require 'ri_cal'
require 'date'
require 'time'
require 'config'
require 'rota/model'

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
  
  class AssessmentTask
    def to_ical(cal)
      due = self.due_date_dt
      unless due.nil?
        cal.event do |event|
          event.dtstart = due.to_time.utc
          event.dtend = (due + Rational(1,24)).to_time.utc
          event.summary = self.to_s
        end
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
    def to_ical(cal, type=:all, excepts=[])
      if type == :timetable or type == :all
        self.series.each do |s|
          unless excepts.include?(s)
            s.to_ical(cal, excepts)
          end
        end
      elsif type == :assessment or type == :all
        self.assessment_tasks.each do |t|
          unless excepts.include?(t)
            t.to_ical(cal)
          end
        end
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
  
  def self.ical(*ps, &block)
    ical = RiCal.Calendar do |cal|
      ps.each do |p|
        p.to_ical(cal)
      end
      if block_given?
        block.call(cal)
      end
    end
    ical.to_s
  end

end
