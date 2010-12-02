require 'rubygems'
require 'dm-core'
require 'dm-transactions'
require 'digest/sha1'
require 'yaml'

DataMapper.setup(:default, "mysql://uqrota:uqrota@localhost/uqrota")

module Rota
  module Model

    class APISession
      include DataMapper::Resource

      property :id, String, :key => true
      property :created, DateTime
      property :remote_addr, String, :length => 100
      property :expires, Integer
      belongs_to :user, :required => false

      def expires_dt
        DateTime.strptime(self.expires.to_s, '%s')
      end

      def expired?
        self.expires_dt < DateTime.now
      end

      def APISession.create
        s = APISession.new
        s['id'] = APISession.gen_id
        s.expires = (DateTime.now + Rational(1,4)).strftime('%s').to_i
        return s
      end

      def APISession.gen_id
        f = File.new('/dev/urandom')
        Digest::SHA1.hexdigest(f.read(50))
      end
    end

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
      has n, :groups, :through => Resource
    end

    class Semester
      include DataMapper::Resource

      property :id, Serial
      property :name, String, :length => 100

      has n, :courses

      def Semester.current
        Semester.get(Setting.get('current_semester').value)
      end
    end

    class UqProgram
      include DataMapper::Resource

      property :id, Serial
      property :name, String, :length => 200

      has n, :uq_plans
    end

    class UqPlan
      include DataMapper::Resource

      property :id, Serial
      property :name, String, :length => 200

      belongs_to :uq_program
      has n, :uq_course_groups
    end

    class UqCourseGroup
      include DataMapper::Resource

      property :id, Serial
      property :text, String, :length => 1024
      belongs_to :uq_plan
      has n, :uq_courses, :through => Resource
    end

    class UqCourse
      include DataMapper::Resource

      property :code, String, :length => 9, :key => true
      property :units, Integer
      property :name, String, :length => 200
      property :semesters_offered, String, :length => 10
      property :description, String, :length => 4096
      property :coordinator, String, :length => 512
      property :faculty, String, :length => 512
      property :school, String, :length => 512

      has n, :uq_course_groups, :through => Resource
      has n, :uq_course_profiles
      has n, :dependents, :model => 'Prereqship', :child_key => :prereq_code
      has n, :prereqs, :model => 'Prereqship', :child_key => :dependent_code

      #def prereqs
      #self.prereqships.prereqs(:code.not => self.code)
      #end

      #def dependents
      #self.prereqships.dependents(:code.not => self.code)
      #end
    end
    
    class UqCourseProfile
      include DataMapper::Resource
      
      property :id, Serial
      property :profileId, Integer
      property :semester, String
      property :location, String
      property :current, Boolean
      property :mode, String
      
      belongs_to :uq_course
      has n, :uq_assessment_tasks
    end
    
    class UqAssessmentTask
      include DataMapper::Resource
      
      property :id, Serial
      property :name, String, :length => 128
      property :description, String, :length => 128
      property :due_date, String, :length => 256
      property :weight, String, :length => 128
      
      belongs_to :uq_course_profile
    end
    
    class UqBuilding
      include DataMapper::Resource
      
      property :map_id, Integer, :key => true
      property :number, String
      property :name, String, :length => 128
    end

    class Prereqship
      include DataMapper::Resource
      property :id, Serial

      belongs_to :dependent, :model => UqCourse
      belongs_to :prereq, :model => UqCourse
    end

    class Course
      include DataMapper::Resource

      property :id, Serial
      property :code, String, :length => 9
      property :description, String, :length => 100
      property :update_thread_id, Integer, :default => 0
      property :last_update, DateTime

      belongs_to :semester
      has n, :series
    end

    class Series
      include DataMapper::Resource

      property :id, Serial
      property :name, String

      belongs_to :course
      has n, :groups
    end

    class Group
      include DataMapper::Resource

      property :id, Serial
      property :name, String
      property :group_name, String

      def fancy_name
        "#{self.series.course.code} #{self.series.name}#{self.name}"
      end

      belongs_to :series
      has n, :sessions
      has n, :timetables, :through => Resource
    end

    class Session
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
      property :building, String, :length => 100
      property :room, String

      belongs_to :group
      has n, :events

      def build_events
        start_date, end_date = self.dates.split(" - ").collect do |d| 
          DateTime.strptime(d + ' 00:01 +1000', '%d/%m/%Y %H:%M %Z')
        end

        start_week = start_date.strftime('%W')
        end_week = end_date.strftime('%W')
        date = DateTime.strptime("#{start_week} #{self.day} 00:01 +1000", '%W %a %H:%M %Z')

        # destroy all current events
        self.events.each do |evt|
          evt.destroy!
        end

        excepts = self.exceptions.split(";").collect do |d|
          dt = d.strip.chomp
          dtt = nil
	  begin
            dtt = DateTime.strptime(dt, '%d/%m/%Y').strftime('%Y-%m-%d')
          rescue ArgumentError => ex
            # blank exception list
          end
          dtt
        end
        excepts = excepts.compact

        # now create the new ones
        while date.strftime('%W').to_i <= end_week.to_i
          sdate = date.strftime('%Y-%m-%d')
          evt = Event.new
          evt.date = sdate
          evt.session = self
          evt.week_number = date.strftime('%W').to_i
          evt.taught = (not excepts.include?(sdate))
          evt.update_times
          evt.save
          date += Rational(7,1)
        end
      end

      def Session.mins_from_string(str)
        m = /([0-9]{2}):([0-9]{2}) ([AP]M)/.match(str)
        mins = m[1].to_i * 60 + (m[2].to_i)
        mins += 720 if m[3] == 'PM' and m[1].to_i < 12
        return mins
      end
    end

    # Represents weekly recurrences of a Session
    class Event
      include DataMapper::Resource

      property :id, Serial
      property :date, String
      property :week_number, Integer
      property :taught, Boolean

      property :start, Integer
      property :finish, Integer

      belongs_to :session

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
