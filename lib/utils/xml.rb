require 'rubygems'
require 'builder'
require 'config'
require 'rota/model'

module Rota
  
  class TimetableEvent
    def to_xml(b)
      b.event(:date => self.date, :taught => self.taught)
    end
  end
  
  class TimetableSession
    def to_xml(b, *opts)
      b.session do |s|
        s.id(self['id'])
        s.day(self.day)
        s.start(self.start_time)
        s.finish(self.finish_time)
        s.startmins(self.start)
        s.finishmins(self.finish)
        s.room(self.room)
        s.building do |b|
          b.number(self.building.number)
          b.name(self.building.name)
        end
        unless opts.include?(:no_children)
          s.events do |e|
            self.events.each do |ev|
              ev.to_xml(e)
            end
          end
        end
      end
    end
  end
  
  class TimetableGroup
    def to_xml(b, *opts)
      b.group do |g|
        g.id(self['id'])
        g.name(self.name)
        g.groupname(self.group_name)
        unless opts.include?(:no_children)
          g.sessions do |s|
            self.sessions.each do |se|
              se.to_xml(s)
            end
          end
        end
      end
    end
  end
  
  class TimetableSeries
    def to_xml(b, *opts)
      b.series do |ss|
        ss.id(self['id'])
        ss.name(self.name)
        unless opts.include?(:no_children)
          ss.groups do |g|
            self.groups.each do |gg|
              gg.to_xml(g)
            end
          end
        end
      end
    end
  end
  
  class Semester
    def to_xml(b, *opts)
      b.semester do |sem|
        sem.id(self['id'])
        sem.name(self.name)
        sem.weeks do |w|
          w.start(self.start_week)
          w.finish(self.finish_week)
          w.midsem(self.midsem_week)
        end
      end
    end
  end
  
  class Offering
    def to_xml(b, *opts)
      b.offering do |off|
        off.id(self['id'])
        off.course(self.course.code) unless opts.include?(:no_course)
        off.semester(self.semester['id']) unless opts.include?(:no_semester)
        off.location(self.location)
        off.mode(self.mode)
        off.lastupdated(self.last_update.strftime("%Y-%m-%d")) if self.last_update
        unless opts.include?(:no_children) or opts.include?(:no_series)
          off.series do |ss|
            self.series.each do |ser|
              ser.to_xml(ss)
            end
          end
        end
        unless opts.include?(:no_children) or opts.include?(:no_assessment)
          off.assessment do |ass|
            self.assessment_tasks.each do |t|
              t.to_xml(ass)
            end
          end
        end
      end
    end
  end
  
  class Course
    def to_xml(b, *opts)
      b.course do |cs|
        cs.code(self.code)
        cs.units(self.units)
        cs.name(self.name)
        cs.description(self.description)
        cs.coordinator(self.coordinator)
        cs.faculty(self.faculty)
        cs.school(self.school)
        cs.prereqs do |p|
          self.prereqs.each do |c|
            p.course(c.code)
          end
        end
        cs.dependents do |d|
          self.dependents.each do |c|
            d.course(c.code)
          end
        end
        unless opts.include?(:no_children)
          cs.offerings do |ox|
            self.offerings.each do |o|
              o.to_xml(ox, :no_children, :with_semester)
            end
          end
        end
      end
    end
  end
  
  class AssessmentTask
    def to_xml(b, *opts)
      b.task do |task|
        task.id(self['id'])
        task.name(self.name)
        task.description(self.description)
        task.due(self.due_date)
        task.weight(self.weight)
        task.duedate(self.due_date_dt) if self.due_date_dt
      end
    end
  end
  
end

module Utils
  def self.xml(*ps, &block)
    builder = Builder::XmlMarkup.new(:indent=>2)
    builder.instruct!
    ps.each do |p|
      p.to_xml(builder)
    end
    block.call(builder) if block
    return builder.target!
  end
end