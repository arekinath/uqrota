require 'rubygems'
require 'dm-core'
require 'dm-transactions'
require 'dm-constraints'
require 'digest/sha1'
require 'config'
require 'utils/json'

module Rota

  def Rota.setup_and_finalize
    DataMapper.setup(:default, Rota::Config['database']['uri'])
    DataMapper::Model.raise_on_save_failure = true
    DataMapper.finalize
  end

  class Setting
    include DataMapper::Resource

    property :name, String, :key => true
    property :value, String

    include JSON::Serializable
    json :attrs => [:value], :key => :name

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
    json :attrs => [:name, {:number => :semester_id}, :start_week, :finish_week, :midsem_week, {:current => :is_current?}, :pred, :succ]
    json_coreattrs :name, {:number => :semester_id}, :year

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

    def week_of(dt)
      sdt = DateTime.strptime("Mon #{self.start_week} #{self.year}", '%A %W %Y')

      if dt < sdt
        return :before
      end

      n = 1
      while dt.strftime('%W %Y') != sdt.strftime('%W %Y')
        sdt += Rational(7, 1)
        if sdt.strftime('%W').to_i == midsem_week
          if dt.strftime('%W %Y') == sdt.strftime('%W %Y')
            return :midsem
          end
          sdt += Rational(7, 1)
        end
        n += 1
      end

      if sdt.strftime('%W').to_i > self.finish_week
        return :after
      else
        return n
      end
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
    property :prereq_text, String, :length => 512, :required => false
    property :prereq_expr, Text, :required => false
    property :recommended_text, String, :length => 512, :required => false
    property :recommended_expr, Text, :required => false
    property :incompatible_text, String, :length => 512, :required => false
    property :last_update, DateTime

    has n, :course_groups, :through => Resource, :constraint => :skip
    has n, :offerings, :constraint => :destroy

    has n, :dependentships, 'Prereqship', :child_key => :prereq_code, :constraint => :destroy
    has n, :prereqships, 'Prereqship', :child_key => :dependent_code, :constraint => :destroy
    has n, :dependents, self, :through => :dependentships, :via => :dependent
    has n, :prereqs, self, :through => :prereqships, :via => :prereq

    has n, :incompatibilities, 'Incompatibility', :child_key => :source_code, :constraint => :destroy
    has n, :target_incompats, 'Incompatibility', :child_key => :target_code, :constraint => :destroy
    has n, :incompatibles, self, :through => :incompatibilities, :via => :target

    def prereq_struct
      blob = self.prereq_expr
      blob = "{}" if blob.nil? or blob == "null"
      JSON.parse(blob, :symbolize_names => true, :max_nesting => false)
    end
    def prereq_struct=(v); self.prereq_expr = v.to_json(:max_nesting => false); end

    def _clean(ctx, s, x)
      if s[:any_of] or s[:all_of] or s[:one_of]
        prop = s[:any_of] ? :any_of : (s[:all_of] ? :all_of : (s[:one_of] ? :one_of : nil))
        puts s.inspect if prop.nil?
        inx = []
        left = s[prop].first[:left]
        s[prop].each do |kid|
          kid[:left] = left
          newx = {}
          _clean(ctx, kid, newx)
          inx << newx
        end
        x[prop] = inx
      elsif s[:right]
        if s[:right][:stem]
          s[:right] = {:course => {:root => ctx[:last][:course][:root], :stem => s[:right][:stem]}}
          _clean(ctx, s[:right], x)
        elsif s[:right][:equivalent]
          eq = {}
          _clean(ctx, ctx[:last], eq)
          x[:equivalent] = eq
        else
          _clean(ctx, s[:right], x)
        end
      elsif s[:left]
        if s[:left][:stem]
          s[:left] = {:course => {:root => ctx[:last][:course][:root], :stem => s[:left][:stem]}}
          _clean(ctx, s[:left], x)
        else
          _clean(ctx, s[:left], x)
        end
      elsif s[:course]
        x[:course] = s[:course][:root] + s[:course][:stem]
        ctx[:last] = s
      elsif s[:highschool]
        hs = {}
        s[:highschool].each do |k,v|
          hs[k.to_sym] = v
        end
        x[:highschool_subject] = hs
      end
    end

    def prereq_struct_clean
      h = {}
      if self.prereq_struct[:exception]
        return {:failure => (self.prereq_struct[:exception] or true)}
      end
      root, stem = self.code.scan(/^([A-Z]+)([0-9]+)/).first
      _clean({:last => {:course => {:root => root, :stem => stem}}}, self.prereq_struct, h)
      h = {:all_of => [h]} if h[:course]
      h
    end

    def prereq_struct_courses
      s = prereq_struct_clean
      def walk(h)
        if h[:all_of]
          return h[:all_of].collect { |hh| walk(hh) }.flatten
        elsif h[:any_of]
          return h[:any_of].collect { |hh| walk(hh) }.flatten
        elsif h[:one_of]
          return h[:one_of].collect { |hh| walk(hh) }.flatten
        elsif h[:course]
          return [h[:course]]
        else
          return []
        end
      end
      walk(s)
    end

    def recommended_struct
      blob = self.recommended_expr
      blob = "{}" if blob.nil? or blob == "null"
      JSON.parse(blob, :symbolize_names => true, :max_nesting => false)
    end
    def recommended_struct=(v); self.recommended_expr = v.to_json(:max_nesting => false); end

    def recommended_struct_clean
      h = {}
      if self.recommended_struct[:exception]
        return {:failure => (self.recommended_struct[:exception] or true)}
      end
      root, stem = self.code.scan(/^([A-Z]+)([0-9]+)/).first
      _clean({:last => {:course => {:root => root, :stem => stem}}}, self.recommended_struct, h)
      h = {:all_of => [h]} if h[:course]
      h
    end

    include JSON::Serializable
    json_key :code
    json_attrs :units, :name, :description, :coordinator, :faculty, :school, :last_update, :prereqs, :dependents, :incompatibles, {:prereq_struct => :prereq_struct_clean}, {:recommended_struct => :recommended_struct_clean}, :prereq_text, :recommended_text, :incompatible_text
    json_children :offerings
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
    property :map_id, Integer, :index => true
    property :number, String, :index => true
    property :name, String, :length => 128

    belongs_to :campus
    has n, :timetable_sessions, :constraint => :skip

    include JSON::Serializable
    json_attrs :id, :map_id, :number, :name

    def room(r)
      "#{self.name} #{self.number}-#{r}"
    end

    def Building.find_or_create(campus, num, name)
      b = Building.first(:campus => campus, :number => num)
      if b.nil?
        b = Building.first(:campus => campus, :number => num.to_s.gsub(/^0+/,'').upcase)
        if b.nil?
          b = Building.new
          b.campus = campus
          b.number = num.to_s.gsub(/^0+/,'').upcase
          b.name = name
          b.save
        end
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

  class Incompatibility
    include DataMapper::Resource
    property :id, Serial

    belongs_to :source, 'Course'
    belongs_to :target, 'Course'
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
      end_year = end_date.strftime('%Y')
      date = DateTime.strptime("#{start_week} #{start_year} #{self.day} 00:01 +1000", '%W %Y %a %H:%M %Z')

      # destroy all current events
      self.events.each do |evt|
        evt.destroy!
      end

      self.exceptions = "" unless self.exceptions
      ds = self.exceptions.scan(/([0-9]{1,2})\/([0-9]{1,2})\/([0-9]{4})/)
      excepts = ds.collect do |d,m,y|
          "%04d-%02d-%02d" % [y.to_i, m.to_i, d.to_i]
      end

      # now create the new ones
      while date.strftime('%W').to_i <= end_week.to_i or date.year < end_year.to_i
        sdate = date.strftime('%Y-%m-%d')
        if date >= start_date and date <= end_date
          evt = TimetableEvent.new
          evt.date = sdate
          evt.timetable_session = self
          evt.week_number = date.strftime('%W').to_i
          evt.taught = (not excepts.include?(sdate))
          evt.update_times
          evt.save
          self.timetable_events << evt
        end
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
