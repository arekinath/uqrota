require 'rubygems'
require 'builder'
require 'config'
require 'rota/model'

class Hash
  def _prereq_to_xml(ctx, x, amtop=false)
    if self[:any_of] or self[:all_of] or self[:one_of]
      prop = self[:any_of] ? :any_of : (self[:all_of] ? :all_of : (self[:one_of] ? :one_of : nil))
      puts self.inspect if prop.nil?
      x.__send__(prop) do |inx|
        left = self[prop].first[:left]
        self[prop].each do |kid|
          kid[:left] = left
          kid._prereq_to_xml(ctx, inx)
        end
      end
    elsif self[:right]
      if self[:right][:stem]
        self[:right] = {:course => {:root => ctx[:last][:course][:root], :stem => self[:right][:stem]}}
        self[:right]._prereq_to_xml(ctx, x)
      elsif self[:right][:equivalent]
        x.equivalent_to do |eq|
          ctx[:last]._prereq_to_xml(ctx, eq)
        end
      else
        self[:right]._prereq_to_xml(ctx, x)
      end
    elsif self[:left]
      if self[:left][:stem]
        self[:left] = {:course => {:root => ctx[:last][:course][:root], :stem => self[:left][:stem]}}
        self[:left]._prereq_to_xml(ctx, x)
      else
        self[:left]._prereq_to_xml(ctx, x)
      end
    elsif self[:course]
      if amtop
        x.all_of { |a| self._prereq_to_xml(ctx, a) }
      else
        x.course(self[:course][:root] + self[:course][:stem])
      end
      ctx[:last] = self
    elsif self[:highschool]
      if amtop
        x.all_of { |a| self._prereq_to_xml(ctx, a) }
      else
        x.highschool_subject do |hs|
          self[:highschool].each do |k,v|
            hs.__send__(k, v)
          end
        end
      end
    end
  end
end

module Rota

  class TimetableEvent
    def to_xml(b)
      b.event(:date => self.date, :taught => self.taught)
    end
  end

  class Clash
    def to_xml(b)
      b.clash do |c|
        c.send(@type, @objects[0]['id'])
        c.send(@type, @objects[1]['id'])
        c.description(@desc)
      end
    end
  end

  class ClashSummary
    def to_xml(b)
      b.summary do |s|
        s.offering(@o1['id'])
        s.offering(@o2['id'])
        s.status(self.clashes? ? 'clash' : 'clear')
        @clashes.each do |clash|
          clash.to_xml(s)
        end
      end
    end
  end

  class Program
    def to_xml(b, *opts)
      b.program do |p|
        p.id(self['id'])
        p.name(self.name)
        b.abbrev(self.abbrev)
        self.campus.to_xml(p) unless self.campus.nil?
        self.faculty.to_xml(p) unless self.faculty.nil?
        p.duals do |dls|
          self.duals.each do |prog|
            dls.program { |pp| pp.id(prog.id) }
          end
        end
        p.singulars do |sls|
          self.singulars.each do |prog|
            sls.program { |pp| pp.id(prog.id) }
          end
        end
        unless opts.include?(:no_children)
          p.plans do |pls|
            self.plans.each do |pl|
              pl.to_xml(pls, :no_children, :no_program)
            end
          end
        end
      end
    end
  end

  class Plan
    def to_xml(bu, *opts)
      bu.plan do |b|
        b.id(self['id'])
        b.program(self.program['id']) unless opts.include?(:no_program)
        b.name(self.name)
        unless opts.include?(:no_children)
          b.groups do |gps|
            self.course_groups.each do |cg|
              cg.to_xml(gps, :no_plan)
            end
          end
        end
      end
    end
  end

  class CourseGroup
    def to_xml(bu, *opts)
      bu.group do |b|
        b.id(self['id'])
        b.text(self.text)
        b.plan(self.plan['id']) unless opts.include?(:no_plan)
        b.courses do |cs|
          self.courses.each do |c|
            cs.course(c.code)
          end
        end
      end
    end
  end

  class TimetableSession
    def to_xml(b, *opts)
      b.session do |s|
        s.id(self['id'])
        self.group.to_xml(s, :parents, :no_children) if opts.include?(:parents)
        s.day(self.day)
        s.start(self.start_time)
        s.finish(self.finish_time)
        s.startmins(self.start)
        s.finishmins(self.finish)
        s.room(self.room)
        s.building do |b|
          b.id(self.building.id)
          b.campus(self.building.campus.code)
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

  class Building
    def to_xml(b, *opts)
      b.building do |b|
        b.id(self.id)
        self.campus.to_xml(b)
        b.number(self.number)
        b.name(self.name)
        b.map_id(self.map_id)
      end
    end
  end

  class TimetableGroup
    def to_xml(b, *opts)
      b.group do |g|
        g.id(self['id'])
        self.series.to_xml(g, :parents, :no_children) if opts.include?(:parents)
        g.name(self.name)
        g.groupname(self.group_name)
        unless opts.include?(:no_children)
          g.sessions do |s|
            self.sessions.each do |se|
              se.to_xml(s, :no_parents)
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
        self.offering.to_xml(ss, :parents, :no_children) if opts.include?(:parents)
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
        sem.number(self.semester_id)
        sem.year(self.year)
        unless opts.include?(:no_children)
          unless self.succ.nil?
            sem.succ do |s|
              s.id(self.succ['id'])
            end
          end
          unless self.pred.nil?
            sem.pred do |s|
              s.id(self.pred['id'])
            end
          end
        end
        sem.weeks do |w|
          w.start(self.start_week)
          w.finish(self.finish_week)
          w.midsem(self.midsem_week)
        end
      end
    end
  end

  class Faculty
    def to_xml(b, *opts)
      b.faculty do |fac|
        fac.code(self.code)
        fac.name(self.name)
      end
    end
  end

  class Campus
    def to_xml(b, *opts)
      b.campus do |camp|
        camp.code(self.code)
        camp.name(self.name)
      end
    end
  end

  class Offering
    def to_xml(b, *opts)
      b.offering do |off|
        off.id(self['id'])
        off.course(self.course.code) unless opts.include?(:no_course)
        unless opts.include?(:no_semester)
          off.semester do |sem|
            sem.id(self.semester.id)
            sem.name(self.semester.name)
            sem.number(self.semester.semester_id)
            sem.year(self.semester.year)
          end
        end
        off.location(self.location)
        off.mode(self.mode)
        off.sinet_class(self.sinet_class)
        self.campus.to_xml(off)
        off.last_update(self.last_update.to_s)
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
        cs.last_update(self.last_update.to_s)
        cs.prereqs do |x|
          x.text(self.prereq_text)
          self.prereqs.each do |c|
            x.course(c.code)
          end
          if self.prereq_struct and not self.prereq_struct[:exception]
            x.expression do |top|
              root, stem = self.code.scan(/^([A-Z]+)([0-9]+)/).first
              self.prereq_struct._prereq_to_xml({:last => {:course => {:root => root}}}, top, true)
            end
          else
            x.expression_failure(self.prereq_struct[:exception])
          end
        end
        cs.recommended do |x|
          x.text(self.recommended_text)
          if self.recommended_struct and not self.recommended_struct[:exception]
            x.expression do |top|
              root, stem = self.code.scan(/^([A-Z]+)([0-9]+)/).first
              self.recommended_struct._prereq_to_xml({:last => {:course => {:root => root}}}, top, true)
            end
          else
            x.expression_failure(self.recommended_struct[:exception])
          end
        end
        cs.incompatible do |x|
          x.text(self.incompatible_text)
          self.incompatibles.each do |c|
            x.course(c.code)
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
              o.to_xml(ox, :no_children, :no_course)
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
