require 'rubygems'
require 'dm-core'
require 'dm-transactions'
require 'digest/sha1'
require 'config'

DataMapper.setup(:default, Rota::Config['database']['uri'])

module Rota
  module Model

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

    class User
      include DataMapper::Resource

      property :login, String, :key => true
      property :password_sha1, String
      property :email, String
      property :mobile, String

      property :last_login, DateTime

      property :admin, Boolean

      has n, :API_sessions
      has n, :timetables

      def password=(pw)
        self.password_sha1 = User.hash_password(pw)
      end

      def is_password?(pw)
        self.password_sha1 == User.hash_password(pw)
      end

      # Hash a password for storage and comparison
      # Currently just uses sha-1
      def User.hash_password(pw)
        Digest::SHA1.hexdigest(pw)
      end
    end

    class Timetable
      include DataMapper::Resource

      property :id, Serial
      property :name, String

      property :world_readable, Boolean, :default => false

      property :alert_sms, Boolean, :default => false
      property :alert_email, Boolean, :default => true

      belongs_to :user
      has n, :timetable_groups, :through => Resource
      
      alias :groups :timetable_groups
    end

    class Semester
      include DataMapper::Resource

      property :id, Serial
      property :name, String, :length => 100

      has n, :offerings

      def Semester.current
        Semester.get(Setting.get('current_semester').value)
      end
    end

    class Program
      include DataMapper::Resource

      property :id, Serial
      property :name, String, :length => 200

      has n, :plans
    end

    class Plan
      include DataMapper::Resource

      property :id, Serial
      property :name, String, :length => 200

      belongs_to :program
      has n, :course_groups
    end

    class CourseGroup
      include DataMapper::Resource

      property :id, Serial
      property :text, String, :length => 1024
      belongs_to :plan
      has n, :courses, :through => Resource
    end

    class Course
      include DataMapper::Resource

      property :code, String, :length => 9, :key => true
      property :units, Integer
      property :name, String, :length => 200
      property :semesters_offered, String, :length => 10
      property :description, String, :length => 4096
      property :coordinator, String, :length => 512
      property :faculty, String, :length => 512
      property :school, String, :length => 512

      has n, :course_groups, :through => Resource
      has n, :offerings
      has n, :dependents, :model => 'Prereqship', :child_key => :prereq_code
      has n, :prereqs, :model => 'Prereqship', :child_key => :dependent_code
    end
    
    class Offering
      include DataMapper::Resource
      
      property :id, Serial
      property :profile_id, Integer
      property :semester, String
      property :location, String
      property :current, Boolean
      property :mode, String
      
      property :update_thread_id, Integer, :default => 0
      property :last_update, DateTime
      
      belongs_to :semester
      has n, :timetable_series
      alias :series :timetable_series
      
      belongs_to :course
      has n, :assessment_tasks
    end
    
    class AssessmentTask
      include DataMapper::Resource
      
      property :id, Serial
      property :name, String, :length => 128
      property :description, String, :length => 128
      property :due_date, String, :length => 256
      property :weight, String, :length => 128
      
      belongs_to :offering
    end
    
    class Building
      include DataMapper::Resource
      
      property :id, Serial
      property :map_id, Integer
      property :number, String
      property :name, String, :length => 128
      
      has n, :timetable_sessions
    end

    class Prereqship
      include DataMapper::Resource
      property :id, Serial

      belongs_to :dependent, :model => Course
      belongs_to :prereq, :model => Course
    end

    class TimetableSeries
      include DataMapper::Resource

      property :id, Serial
      property :name, String

      belongs_to :offering
      has n, :timetable_groups
      alias :groups :timetable_groups
    end

    class TimetableGroup
      include DataMapper::Resource

      property :id, Serial
      property :name, String
      property :group_name, String

      def fancy_name
        "#{self.timetable_series.offering.course.code} #{self.timetable_series.name}#{self.name}"
      end

      belongs_to :timetable_series
      has n, :timetable_sessions
      alias :sessions :timetable_sessions
      alias :series :timetable_series
      has n, :timetables, :through => Resource
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
      has n, :timetable_events
      alias :group :timetable_group
      alias :events :timetable_events

      def build_events
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

      def Session.mins_from_string(str)
        m = /([0-9]{1,2}):([0-9]{1,2}) ([AP]M)/.match(str)
        mins = m[1].to_i * 60 + (m[2].to_i)
        mins += 720 if m[3] == 'PM' and m[1].to_i < 12
        return mins
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
end