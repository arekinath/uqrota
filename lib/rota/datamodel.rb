require 'rubygems'
require 'dm-core'
require 'dm-transactions'
require 'dm-constraints'
require 'digest/sha1'
require 'config'
require 'utils/json'

DataMapper.setup(:default, Rota::Config['database']['uri'])
DataMapper::Model.raise_on_save_failure = true

module Rota
  class Setting
    include DataMapper::Resource
    
    property :name, String, :key => true
    property :value, String
    
    def Setting.set(name, value)
      s = Setting.get(name)
      if s.nil?
        s = Setting.new
        s.name = name
        s.value = value.to_s
        s.save
      else
        s.value = value.to_s
        s.save
      end
      s
    end
  end
  
  class Semester
    include DataMapper::Resource
    
    property :id, Serial
    property :name, String, :length => 100
    property :start_week, Integer
    property :finish_week, Integer
    property :midsem_week, Integer
    
    has n, :offerings, :constraint => :destroy
    
    include JSON::Serializable
    json :attrs => [:name, :start_week, :finish_week, :midsem_week, {:current => :is_current?}, :pred, :succ]
    
    def Semester.current
      Semester.get(Setting.get('current_semester').value)
    end
    
    def pred
      Semester.first(:id.lt => self.id, :name.like => '%Semester%', :order => [:id.desc])
    end
    
    def succ
      Semester.first(:id.gt => self.id, :name.like => '%Semester%', :order => [:id.asc])
    end
    
    def is_current?
      return self['id'].to_s == Setting.get('current_semester').value
    end
    
    def year
      self.name.split(",").last.to_i
    end
    
    def semester_id
      part = self.name.split(",").first
      if part =~ /Summer/
        return '3'
      else
        m = /^Semester ([0-9]+)$/.match(part)
        if m
          return m[1]
        else
          return '?'
        end
      end
    end
    
    def week(n)
      dt = DateTime.strptime("Mon #{self.start_week} #{self.year}", '%A %W %Y')
      
      while n > 1
        n -= 1
        dt += Rational(7, 1)
        if dt.strftime('%W').to_i == midsem_week
          dt += Rational(7, 1)
        end
      end
      
      return [dt.year, dt.strftime('%W').to_i]
    end
    
    def each_week(&block)
      dt = DateTime.strptime("Mon #{self.start_week} #{self.year}", '%A %W %Y')
      n = 0
      while (wkno = dt.strftime('%W').to_i) != finish_week + 1
        endwk = dt + Rational(5,1)
        if wkno == midsem_week
          block.call(:midsem, wkno, dt, endwk)
        else
          n += 1
          block.call(n, wkno, dt, endwk)
        end
        dt += Rational(7,1)
      end
    end
  end
  
  class Campus
    include DataMapper::Resource
    
    property :code, String, :length => 16, :key => true
    property :name, String, :length => 64
    
    has n, :offerings, :constraint => :destroy
    
    include JSON::Serializable
    json :attrs => [:code, :name], :key => [:code]
  end
  
  class Program
    include DataMapper::Resource
    
    property :id, Serial
    property :name, String, :length => 200
    
    has n, :plans, :constraint => :destroy
    
    include JSON::Serializable
    json :attrs => [:name], :children => [:plans]
  end
  
  class Plan
    include DataMapper::Resource
    
    property :id, Serial
    property :name, String, :length => 200
    
    belongs_to :program
    has n, :course_groups, :constraint => :destroy
    
    include JSON::Serializable
    json :attrs => [:name], :children => [:course_groups], :parent => :program
  end
  
  class CourseGroup
    include DataMapper::Resource
    
    property :id, Serial
    property :text, String, :length => 1024
    belongs_to :plan
    has n, :courses, :through => Resource, :constraint => :skip
    
    include JSON::Serializable
    json :attrs => [:text], :children => [:courses], :parent => :plan
  end
  
  class Course
    include DataMapper::Resource
    
    property :code, String, :length => 10, :key => true
    property :units, Integer
    property :name, String, :length => 200
    property :semesters_offered, String, :length => 20, :required => false
    property :description, Text, :required => false
    property :coordinator, String, :length => 512, :required => false
    property :faculty, String, :length => 512, :required => false
    property :school, String, :length => 512, :required => false
    
    has n, :course_groups, :through => Resource, :constraint => :skip
    has n, :offerings, :constraint => :destroy
    
    has n, :dependentships, 'Prereqship', :child_key => :prereq_code, :constraint => :destroy
    has n, :prereqships, 'Prereqship', :child_key => :dependent_code, :constraint => :destroy
    has n, :dependents, self, :through => :dependentships, :via => :dependent
    has n, :prereqs, self, :through => :prereqships, :via => :prereq
    
    include JSON::Serializable
    json_key :code
    json_attrs :units, :name, :description, :coordinator, :faculty, :school
    json_children :prereqs, :dependents, :offerings
  end
  
  class Offering
    include DataMapper::Resource
    
    property :id, Serial
    property :profile_id, Integer
    property :sinet_class, Integer
    property :location, String
    property :current, Boolean
    property :mode, String
    
    property :last_update, DateTime
    
    belongs_to :semester
    belongs_to :campus
    has n, :timetable_series, :model => 'Rota::TimetableSeries', :constraint => :destroy
    alias :series :timetable_series
    
    belongs_to :course
    has n, :assessment_tasks, :constraint => :destroy
    
    include JSON::Serializable
    json_attrs :location, :mode, :last_update, :sinet_class
    json_children :series, :assessment_tasks
    json_parents :course, :semester, :campus
  end
  
  class AssessmentTask
    include DataMapper::Resource
    
    property :id, Serial
    property :name, String, :length => 128
    property :description, String, :length => 128
    property :due_date, String, :length => 256
    property :weight, String, :length => 128
    
    belongs_to :offering
    
    include JSON::Serializable
    json_attrs :name, :description, :due_date, :weight, :due_date_dt
    json_parent :offering
    
    def to_s
      "#{self.offering.course.code} #{self.name} (#{self.weight})"
    end
    
    def due_date_dt
      tspans = self.due_date.scan(/([0-9]{1,2})\s+([A-Z][a-z]{2})\s+([0-9]{2})\s+-\s+([0-9]{1,2})\s+([A-Z][a-z]{2})\s+([0-9]{2})/)
      if tspans.size == 1
        _,_,_, day, month, year = tspans.first
        return DateTime.parse("#{day} #{month} #{year}")
      end
      
      tspans = self.due_date.scan(/([0-9]{1,2})\s+([A-Z][a-z]{2})\s+([0-9]{2})\s+([0-9]{1,2}):([0-9]{2})\s+-\s+([0-9]{1,2})\s+([A-Z][a-z]{2})\s+([0-9]{2})\s+([0-9]{1,2}):([0-9]{2})/)
      if tspans.size == 1
        _,_,_,_,_, day, month, year, hours, mins = tspans.first
        return DateTime.parse("#{day} #{month} #{year} #{hours}:#{mins}")
      end
      
      dates = self.due_date.scan(/([0-9]{1,2})\s+([A-Z][a-z]{2})\s+([0-9]{2})/)
      if dates.size > 0
        day, month, year = dates.last
        return DateTime.parse("#{day} #{month} #{year}")
      end
      
      weeks = self.due_date.scan(/([wW]eek|[Ww]k) ([0-9]{1,2})/)
      if weeks.size > 0
        _, week = weeks.last
        n = self.offering.semester.week(week)
        return DateTime.strptime("Mon #{n}", '%A %W')
      end
      
      if self.due_date.downcase.include?('examination period')
        n = self.offering.semester.finish_week + 2
        return DateTime.strptime("Mon #{n}", '%A %W')
      end
      
      begin
        dt = DateTime.parse(self.due_date)
        return dt
      rescue ArgumentError
      end
      
      return nil
    end
  end
  
  class Building
    include DataMapper::Resource
    
    property :id, Serial
    property :map_id, Integer
    property :number, String
    property :name, String, :length => 128
    
    has n, :timetable_sessions, :constraint => :skip
    
    include JSON::Serializable
    json_attrs :map_id, :number, :name
    
    def room(r)
      "#{self.name} #{self.number}-#{r}"
    end
    
    def Building.find_or_create(num, name)
      b = Building.first(:number => num)
      if b.nil?
        b = Building.new
        b.number = num
        b.name = name
        b.save
      end
      return b
    end
  end
  
  class Prereqship
    include DataMapper::Resource
    property :id, Serial
    
    belongs_to :dependent, 'Course'
    belongs_to :prereq, 'Course'
  end
  
  class TimetableSeries
    include DataMapper::Resource
    
    property :id, Serial
    property :name, String
    
    belongs_to :offering
    has n, :timetable_groups, :constraint => :destroy
    alias :groups :timetable_groups
    
    include JSON::Serializable
    json :attrs => [:name], :children => [:groups], :parent => :offering
  end
  
  class TimetableGroup
    include DataMapper::Resource
    
    property :id, Serial
    property :name, String
    property :group_name, String
    
    def fancy_name
        "#{self.series.offering.course.code} #{self.series.name}#{self.name}"
    end
    
    belongs_to :timetable_series
    has n, :timetable_sessions, :constraint => :destroy
    alias :sessions :timetable_sessions
    alias :series :timetable_series
    alias :series= :timetable_series=
    
    include JSON::Serializable
    json :attrs => [:name, :group_name], :children => [:sessions], :parent => :series
  end
  
  class TimetableSession
    include DataMapper::Resource
    
    # what
    property :id, Serial
    
    # when
    property :day, String
    property :start, Integer 		# start time as minutes from midnight
    property :finish, Integer		# finish time as minutes from midnight
    
    property :dates, String, :length => 100
    property :exceptions, String, :length => 500
    
    # where
    property :room, String
    belongs_to :building
    
    belongs_to :timetable_group
    has n, :timetable_events, :constraint => :destroy
    alias :group :timetable_group
    alias :group= :timetable_group=
    alias :events :timetable_events
    
    include JSON::Serializable
    json_attrs :day, :room, :start, :finish, :start_time, :finish_time, :building
    json_children :events
    json_parent :group
    
    def build_events
      return if self.dates.nil?
      return if self.day.nil? or self.day.size < 3
      
      begin
        start_date, end_date = self.dates.split(" - ").collect do |d| 
          DateTime.strptime(d + ' 00:01 +1000', '%d/%m/%Y %H:%M %Z')
        end
      rescue ArgumentError
        return
      end
      
      start_week = start_date.strftime('%W')
      end_week = end_date.strftime('%W')
      start_year = start_date.strftime('%Y')
      end_year = start_date.strftime('%Y')
      date = DateTime.strptime("#{start_week} #{start_year} #{self.day} 00:01 +1000", '%W %Y %a %H:%M %Z')
      
      # destroy all current events
      self.events.each do |evt|
        evt.destroy!
      end
      
      self.exceptions = "" unless self.exceptions
      ds = self.exceptions.scan(/([0-9]{2})\/([0-9]{2})\/([0-9]{4})/)
      excepts = ds.collect do |d,m,y|
          "#{y}-#{m}-#{d}"
      end
      
      # now create the new ones
      while date.strftime('%W').to_i <= end_week.to_i or date.year < end_year.to_i
        sdate = date.strftime('%Y-%m-%d')
        evt = TimetableEvent.new
        evt.date = sdate
        evt.timetable_session = self
        evt.week_number = date.strftime('%W').to_i
        evt.taught = (not excepts.include?(sdate))
        evt.update_times
        evt.save
        self.timetable_events << evt
        date += Rational(7,1)
      end
    end
    
    def start_time
      TimetableSession.mins_to_string(self.start)
    end
    
    def finish_time
      TimetableSession.mins_to_string(self.finish)
    end
    
    def start_time=(v)
      self.start = TimetableSession.mins_from_string(v)
    end
    
    def finish_time=(v)
      self.finish = TimetableSession.mins_from_string(v)
    end
    
    def TimetableSession.mins_from_string(str)
      m = /([0-9]{1,2}):([0-9]{1,2}) ([AP]M)/.match(str)
      return nil if m.nil?
      mins = m[1].to_i * 60 + (m[2].to_i)
      mins += 720 if m[3] == 'PM' and m[1].to_i < 12
      return mins
    end
    
    def TimetableSession.mins_to_string(mins)
      hrs = mins / 60
      mins = mins % 60
      tp = "AM"
      if hrs >= 12
        hrs -= 12 if hrs > 12
        tp = "PM"
      end
      "#{hrs}:%02d #{tp}" % mins
    end
  end
  
  # Represents weekly recurrences of a Session
  class TimetableEvent
    include DataMapper::Resource
    
    property :id, Serial
    property :date, String
    property :week_number, Integer
    property :taught, Boolean
    
    property :start, Integer
    property :finish, Integer
    
    belongs_to :timetable_session
    alias :session :timetable_session
    alias :session= :timetable_session=
    
    include JSON::Serializable
    json_attrs :date, :taught
    json_parent :session
    
    def update_times
      dt = DateTime.strptime("#{self.date} 00:00:00 +1000", "%Y-%m-%d %H:%M:%S %Z")
      self.start = dt.strftime('%s').to_i + 60*(self.session.start)
      self.finish = dt.strftime('%s').to_i + 60*(self.session.finish)
    end
    
    def short_date
      DateTime.strptime(self.date, '%Y-%m-%d').strftime('%d/%m')
    end
    
    def start_dt
      DateTime.strptime(self.start.to_s + ' +1000', '%s %Z')
    end
    
    def finish_dt
      DateTime.strptime(self.finish.to_s + ' +1000', '%s %Z')
    end
  end
end
