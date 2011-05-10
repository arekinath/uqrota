require 'rubygems'
require 'json'
require 'json/add/core'
require 'config'
require 'rota/model'
require 'utils/xml'

module Rota
  
  class Program
    def to_json(o, *opts)
      o.id(self['id'])
      o.name(self.name)
      unless opts.include?(:no_children)
        o.plans(:array) do |pls|
          self.plans.each do |pl|
            pls.object do |ob|
              pl.to_json(ob, :no_children, :no_program)
            end
          end
        end
      end
    end
  end
  
  class Plan
    def to_json(o, *opts)
      o.id(self['id'])
      o.program(self.program['id']) unless opts.include?(:no_program)
      o.name(self.name)
      unless opts.include?(:no_children)
        o.groups(:array) do |gps|
          self.course_groups.each do |cg|
            gps.object do |ob|
              cg.to_json(ob, :no_plan)
            end
          end
        end
      end
    end
  end
  
  class CourseGroup
    def to_json(o, *opts)
      o.id(self['id'])
      o.text(self.text)
      o.plan(self.plan['id']) unless opts.include?(:no_plan)
      o.courses(:array) do |a|
        self.courses.each do |c|
          a << c.code
        end
      end
    end
  end
  
  class Semester
    def to_json(o, *opts)
      o.id(self['id'])
      o.name(self.name)
      o.weeks do |w|
        w.start(self.start_week)
        w.finish(self.finish_week)
        w.midsem(self.midsem_week)
      end
    end
  end
  
  class Course
    def to_json(o, *opts)
      o.code(self.code)
      o.units(self.units)
      o.name(self.name)
      o.description(self.description)
      o.coordinator(self.coordinator)
      o.faculty(self.faculty)
      o.school(self.school)
      o.prereqs(:array) do |a|
        self.prereqs.each do |c|
          a << c.code
        end
      end
      o.dependents(:array) do |a|
        self.dependents.each do |c|
          a << c.code
        end
      end
      unless opts.include?(:no_children)
        o.offerings(:array) do |a|
          self.offerings.each do |off|
            a.object do |ob|
              off.to_json(ob, :no_children, :no_course)
            end
          end
        end
      end
    end
  end
  
  class TimetableEvent
    def to_json(o, *opts)
      o.date self.date
      o.taught self.taught
    end
  end
  
  class TimetableSession
    def to_json(o, *opts)
      o.id(self['id'])
      o.day(self.day)
      o.start(self.start_time)
      o.finish(self.finish_time)
      o.startmins(self.start)
      o.finishmins(self.finish)
      o.room(self.room)
      o.building do |b|
        b.number(self.building.number)
        b.name(self.building.name)
      end
      unless opts.include?(:no_children)
        o.events(:array) do |a|
          self.events.each do |ev|
            a.object do |obj|
              ev.to_json(obj)
            end
          end
        end
      end
    end
  end
  
  class TimetableGroup
    def to_json(o, *opts)
      o.id(self['id'])
      o.name(self.name)
      o.groupname(self.group_name)
      unless opts.include?(:no_children)
        o.sessions(:array) do |a|
          self.sessions.each do |se|
            a.object do |obj|
              se.to_json(obj)
            end
          end
        end
      end
    end
  end
  
  class TimetableSeries
    def to_json(o, *opts)
      o.id(self['id'])
      o.name(self.name)
      unless opts.include?(:no_children)
        o.groups(:array) do |g|
          self.groups.each do |gg|
            g.object do |obj|
              gg.to_json(obj)
            end
          end
        end
      end
    end
  end
  
  class Offering
    def to_json(o, *opts)
      o.id(self['id'])
      o.course(self.course.code) unless opts.include?(:no_course)
      o.semester(self.semester['id']) unless opts.include?(:no_semester)
      o.location(self.location)
      o.mode(self.mode)
      o.lastupdated(self.last_update.strftime("%Y-%m-%d")) if self.last_update
      unless opts.include?(:no_children) or opts.include?(:no_series)
        o.series(:array) do |a|
          self.series.each do |ser|
            a.object do |obj|
              ser.to_json(obj)
            end
          end
        end
      end
      unless opts.include?(:no_children) or opts.include?(:no_assessment)
        o.assessment(:array) do |a|
          self.assessment_tasks.each do |t|
            a.object do |obj|
              t.to_json(obj)
            end
          end
        end
      end
    end
  end
  
  class AssessmentTask
    def to_json(o, *opts)
      o.id(self['id'])
      o.name(self.name)
      o.description(self.description)
      o.due(self.due_date)
      o.weight(self.weight)
      o.duedate(self.due_date_dt.strftime("%Y-%m-%d %H:%M")) if self.due_date_dt
    end
  end
  
  class SemesterPlan
    def to_json(o, *opts)
      o.id(self['id'])
      o.name(self.name)
      o.semester do |s|
        s.id(self.semester['id'])
      end
      o.owner do |u|
        u.email(self.owner.email)
      end
      o.courses(:array) do |a|
        self.courses.each do |c|
          a.object do |ob|
            ob.code(c.code)
          end
        end
      end
      o.timetables(:array) do |a|
        self.timetables.each do |t|
          a.object do |ob|
            if opts.include?(:no_children)
              ob.id(t['id'])
            else
              t.to_json(ob)
            end
          end
        end
      end
    end
  end
  
end

class JSONObjectContext
  def initialize(hash=nil)
    @hash = hash || Hash.new
  end
  
  def to_s
    @hash.to_json
  end
  
  def method_missing(sym, *args, &block)
    if args.size == 1
      if args[0] == :array
        arr = Array.new
        block.call(JSONArrayContext.new(arr))
        @hash[sym.to_s] = arr
      elsif args[0] == :object
        hash = Hash.new
        @hash[sym.to_s] = hash
        block.call(JSONObjectContext.new(hash))
      else
        @hash[sym.to_s] = args[0]
      end
    else
      hash = Hash.new
      @hash[sym.to_s] = hash
      block.call(JSONObjectContext.new(hash))
    end
  end
  
  def respond_to?(sym)
    true
  end
end

class JSONArrayContext
  def initialize(array=nil)
    @array = array || Array.new
  end
  
  def to_s
    @array.to_json
  end
  
  def <<(val)
    @array << val
  end
  
  def value(val)
    @array << val
  end
  
  def object(&block)
    hash = Hash.new
    block.call(JSONObjectContext.new(hash))
    @array << hash
  end
  
  def array(&block)
    arr = Array.new
    block.call(JSONArrayContext.new(arr))
    @array << arr
  end
end

module Utils
  def self.json(*ps, &block)
    c = JSONObjectContext.new
    ps.each do |p|
      p.to_json(c)
    end
    block.call(c) if block
    return c.to_s
  end
end