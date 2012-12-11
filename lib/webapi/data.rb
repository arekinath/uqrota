require 'rubygems'
require 'config'
require 'rota/model'
require 'utils/ical'
require 'utils/xml'
require 'utils/cache'
require 'rota/temporal'
require 'webapi/common'
require 'sinatra/base'

class << Sinatra::Base
  def http_options path,opts={}, &blk
    route 'OPTIONS', path, opts, &blk
  end
end
Sinatra::Delegator.delegate :http_options

class DataService < Sinatra::Base

  before do
    response.headers['Access-Control-Allow-Origin'] = '*'
  end

  http_options(/(programs|semester|plan|course|group|session|offering).+/) do
    content_type :plain
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'HEAD, POST, GET, PUT, DELETE, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = request.env['HTTP_ACCESS_CONTROL_REQUEST_HEADERS'] || '*'
    response.headers['Access-Control-Max-Age'] = '12000'
    ''
  end

  get '/programs.xml' do
    content_type :xml
    Utils.xml do |x|
      x.programs do |b|
        Rota::Program.all.each do |prog|
          prog.to_xml(b, :no_children)
        end
      end
    end
  end

  get '/programs.json' do
    content_type :json
    Rota::Programs.all.to_a.to_rota_json
  end

  get '/programs/find.json' do
    content_type :json
    fc = FindConditions.new(Rota::Program, params[:with])
    fc.to_json
  end

  get '/programs/find.xml' do
    content_type :xml
    fc = FindConditions.new(Rota::Program, params[:with])
    Utils.xml do |x|
      x.programs do |b|
        fc.to_a.each do |prog|
          prog.to_xml(b, :no_children)
        end
      end
    end
  end

  get '/program/:id.xml' do |id|
    content_type :xml
    prog = Rota::Program.get(id.to_i)
    return 404 if prog.nil?
    Utils.xml(prog)
  end

  get '/program/:id.json' do |id|
    content_type :json
    prog = Rota::Program.get(id.to_i)
    return 404 if prog.nil?
    prog.to_json
  end

  get '/plan/:id.xml' do |id|
    content_type :xml
    plan = Rota::Plan.get(id.to_i)
    return 404 if plan.nil?
    Utils.xml(plan)
  end

  get '/plan/:id.json' do |id|
    content_type :json
    plan = Rota::Plan.get(id.to_i)
    return 404 if plan.nil?
    plan.to_json
  end

  get '/coursegroup/:id.json' do |id|
    content_type :json
    cg = Rota::CourseGroup.get(id.to_i)
    return 404 if cg.nil?
    cg.to_json
  end

  get '/semesters.xml' do
    content_type :xml
    Utils.xml do |x|
      x.semesters do |b|
        Rota::Semester.all.each do |sem|
          hash = {}
          hash[:current] = 'true' if sem == Rota::Semester.current
          b.semester(sem['id'], hash)
        end
      end
    end
  end

  get '/semesters.json' do
    content_type :json
    Rota::Semester.all.to_a.to_rota_json
  end

  get '/semester/:id.xml' do |id|
    content_type :xml
    sem = Rota::Semester.get(id.to_i)
    if sem.nil?
      if id == 'current'
        sem = Rota::Semester.current
      else
        return 404
      end
    end
    Utils.xml(sem)
  end

  get '/semester/:id.json' do |id|
    content_type :json
    sem = Rota::Semester.get(id.to_i)
    if sem.nil?
      if id == 'current'
        sem = Rota::Semester.current
      else
        return 404
      end
    end
    sem.to_json
  end

  get '/semester/:id.ics' do |id|
    content_type :ical
    sem = Rota::Semester.get(id.to_i)
    return 404 if sem.nil?
    Utils.ical(sem)
  end

  get '/semester/:id/courses.xml' do |id|
    content_type :xml
    sem = Rota::Semester.get(id.to_i)
    return 404 if sem.nil?
    Utils.xml do |b|
      b.semester do |s|
        s.id(sem['id'])
        s.courses do |cs|
          sem.offerings.each do |o|
            cs.course(o.course.code)
          end
        end
      end
    end
  end

  get '/semester/:id/courses.json' do |id|
    content_type :json
    sem = Rota::Semester.get(id.to_i)
    return 404 if sem.nil?
    sem.offerings.courses.to_a.uniq.to_rota_json
  end

  get '/semester/:id/offerings.json' do |id|
    content_type :json
    sem = Rota::Semester.get(id.to_i)
    return 404 if sem.nil?
    sem.offerings.to_a.to_rota_json
  end

  get '/courses/find.json' do
    content_type :json
    fc = FindConditions.new(Rota::Course, params[:with])
    fc.to_json
  end

  get '/courses/find.xml' do
    content_type :xml
    fc = FindConditions.new(Rota::Course, params[:with])
    Utils.xml do |x|
      x.courses do |b|
        fc.to_a.each do |crs|
          crs.to_xml(b, :no_children)
        end
      end
    end
  end

  get '/course/:code.xml' do |code|
    content_type :xml
    course = Rota::Course.get(code.upcase)
    return 404 if course.nil?
    Utils.xml(course)
  end

  get '/course/:code.json' do |code|
    content_type :json
    course = Rota::Course.get(code.upcase)
    return 404 if course.nil?
    course.to_json(2)
  end

  get '/course/:code/plans.xml' do |code|
    content_type :xml
    course = Rota::Course.get(code.upcase)
    return 404 if course.nil?
    Utils.xml do |x|
      x.plans do |b|
        course.course_groups.plans.uniq.each do |pl|
          b.plan do |p|
            p.id(pl['id'])
            b.name(pl.name)
            b.program do |pg|
              pg.id(pl.program['id'])
              pg.name(pl.program.name)
            end
          end
        end
      end
    end
  end

  get '/course/:code/plans.json' do |code|
    content_type :json
    course = Rota::Course.get(code.upcase)
    return 404 if course.nil?
    course.plans.to_a.to_rota_json
  end

  get '/course/:code.ics' do |code|
    content_type :ical
    course = Rota::Course.get(code.upcase)
    return 404 if course.nil?
    Utils.ical(course)
  end

  get '/clashes/:id1/:id2.xml' do |id1, id2|
    content_type :xml
    o1 = Rota::Offering.get(id1.to_i)
    o2 = Rota::Offering.get(id2.to_i)
    return 404 if o1.nil? or o2.nil?
    cs = Rota::ClashSummary.new(o1, o2)
    Utils.xml(cs)
  end

  get '/offerings/find.json' do
    content_type :json
    fc = FindConditions.new(Rota::Offering, params[:with])
    fc.to_json
  end

  get '/offerings/find.xml' do
    content_type :xml
    fc = FindConditions.new(Rota::Offering, params[:with])
    Utils.xml do |x|
      x.offerings do |b|
        fc.to_a.each do |off|
          off.to_xml(b, :no_children)
        end
      end
    end
  end

  get '/offering/:id.xml' do |id|
    content_type :xml
    offering = nil
    if id.start_with?('sinet.')
      sem, siclass = id.gsub(/^sinet\./, '').split('-')
      offering = Rota::Offering.first(:semester => Rota::Semester.get(sem.to_i),
                                      :sinet_class => siclass.to_i)
    else
      offering = Rota::Offering.get(id.to_i)
    end
    return 404 if offering.nil?
    Sinatra::Cache.cache("offering.xml" + id + offering.last_update.to_s) do
      Utils.xml(offering)
    end
  end

  get '/offering/:id.json' do |id|
    content_type :json
    offering = nil
    if id.start_with?('sinet.')
      sem, siclass = id.gsub(/^sinet\./, '').split('-')
      offering = Rota::Offering.first(:semester => Rota::Semester.get(sem.to_i),
                                      :sinet_class => siclass.to_i)
    else
      offering = Rota::Offering.get(id.to_i)
    end
    return 404 if offering.nil?
    Sinatra::Cache.cache("offering.json" + id + offering.last_update.to_s) do
      offering.to_json(5)
    end
  end

  get '/offering/:id.ics' do |id|
    content_type :ical
    offering = nil
    if id.start_with?('sinet.')
      sem, siclass = id.gsub(/^sinet\./, '').split('-')
      offering = Rota::Offering.first(:semester => Rota::Semester.get(sem.to_i),
                                      :sinet_class => siclass.to_i)
    else
      offering = Rota::Offering.get(id.to_i)
    end
    return 404 if offering.nil?
    Sinatra::Cache.cache("offering.ics" + id + offering.last_update.to_s) do
      Utils.ical do |i|
        offering.to_ical(i, :all)
      end
    end
  end

  get '/offering/:id/assessment.ics' do |id|
    content_type :ical
    offering = nil
    if id.start_with?('sinet.')
      sem, siclass = id.gsub(/^sinet\./, '').split('-')
      offering = Rota::Offering.first(:semester => Rota::Semester.get(sem.to_i),
                                      :sinet_class => siclass.to_i)
    else
      offering = Rota::Offering.get(id.to_i)
    end
    return 404 if offering.nil?
    Sinatra::Cache.cache("offering/assessment.ics" + id + offering.last_update.to_s) do
      Utils.ical do |i|
        offering.to_ical(i, :assessment)
      end
    end
  end

  get '/offering/:id/timetable.ics' do |id|
    content_type :ical
    offering = nil
    if id.start_with?('sinet.')
      sem, siclass = id.gsub(/^sinet\./, '').split('-')
      offering = Rota::Offering.first(:semester => Rota::Semester.get(sem.to_i),
                                      :sinet_class => siclass.to_i)
    else
      offering = Rota::Offering.get(id.to_i)
    end
    return 404 if offering.nil?
    Sinatra::Cache.cache("offering/timetable.ics" + id + offering.last_update.to_s) do
      Utils.ical do |i|
        offering.to_ical(i, :timetable)
      end
    end
  end

  get '/group/:id.xml' do |id|
    content_type :xml
    group = Rota::TimetableGroup.get(id.to_i)
    return 404 if group.nil?
    Sinatra::Cache.cache("group.xml" + id + group.series.offering.last_update.to_s) do
      Utils.xml(group)
    end
  end

  get '/group/:id.ics' do |id|
    content_type :ical
    group = Rota::TimetableGroup.get(id.to_i)
    return 404 if group.nil?
    Sinatra::Cache.cache("group.ics" + id + group.series.offering.last_update.to_s) do
      Utils.ical(group)
    end
  end

  get '/session/:id.xml' do |id|
    content_type :xml
    session = Rota::TimetableSession.get(id.to_i)
    return 404 if session.nil?
    Sinatra::Cache.cache("session.xml" + id + session.group.series.offering.last_update.to_s) do
      Utils.xml(session)
    end
  end

  get '/session/:id.ics' do |id|
    content_type :ical
    session = Rota::TimetableSession.get(id.to_i)
    return 404 if session.nil?
    Sinatra::Cache.cache("session.ics" + id + session.group.series.offering.last_update.to_s) do
      Utils.ical(session)
    end
  end

  get '/sessions/find.xml' do
    content_type :json
    fc = FindConditions.new(Rota::Session, params[:with])
    Utils.xml do |x|
      x.sessions do |ss|
        fc.to_a.each { |s| s.to_xml(ss) }
      end
    end
  end

  get '/buildings.xml' do
    content_type :xml
    buildings = Rota::Building.all
    Utils.xml do |x|
      x.buildings do |b|
        buildings.each do |bb|
          bb.to_xml(b)
        end
      end
    end
  end

  get '/building/:id.xml' do |id|
    content_type :xml
    building = Rota::Building.get(id.to_i)
    building = Rota::Building.first(:number => id.upcase) if building.nil?
    return 404 if building.nil?
    Utils.xml(building)
  end

  get '/building/:id.json' do |id|
    content_type :json
    building = Rota::Building.get(id.to_i)
    building = Rota::Building.first(:number => id.upcase) if building.nil?
    return 404 if building.nil?
    building.to_json
  end

  get '/building/:id/rooms.xml' do |id|
    content_type :xml
    building = Rota::Building.get(id.to_i)
    building = Rota::Building.first(:number => id.upcase) if building.nil?
    return 404 if building.nil?
    sessions = building.timetable_sessions
    rooms = sessions.collect { |s| s.room }.uniq
    Utils.xml do |x|
      x.building do |b|
        b.id(building.id)
        b.number(building.number)
        b.rooms do |r|
          rooms.each do |room|
            r.room(room)
          end
        end
      end
    end
  end

  get '/building/:id/room/:room/sessions.xml' do |id, room|
    content_type :xml
    building = Rota::Building.get(id.to_i)
    building = Rota::Building.first(:number => id.upcase) if building.nil?
    return 404 if building.nil?
    sessions = building.timetable_sessions.all(:room => room)
    Utils.xml do |x|
      x.sessions do |ss|
        sessions.each do |sess|
          sess.to_xml(ss, :parents)
        end
      end
    end
  end

  get '/building/:id/room/:room/sessions.ics' do |id, room|
    content_type :ical
    building = Rota::Building.get(id.to_i)
    building = Rota::Building.first(:number => id.upcase) if building.nil?
    return 404 if building.nil?
    sessions = building.timetable_sessions.all(:room => room)
    Utils.ical do |i|
      sessions.each { |s| s.to_ical(i) }
    end
  end

  get '/messages.xml' do
    content_type :xml
    Utils.xml do |x|
      x.messages do |m|
        Rota::Message.all.each do |mes|
          m.message do |mm|
            mm.uuid(mes.uuid)
            mm.name(mes.short)
            mm.description(mes.full)
            mm.parameters do |pr|
              mes.params.each do |pp|
                pr.parameter(pp.to_s)
              end
            end
          end
        end
      end
    end
  end

  get '/messages.json' do
    content_type :json
    Rota::Message.all.to_json
  end

  get '/changes/:class/:key.xml' do |cls,key|
    changes = []
    Rota::ChangelogEntry.all(:objkey.like => "%#{key}%").each do |ce|
      if ce.objkey and ce.objkey.size > 2
        o = JSON.parse(ce.objkey)
        o.values.each do |v|
          if (v.is_a?(Hash) \
              and (v['class'].downcase == cls or v['class'].downcase == 'timetable' + cls) \
              and v['key'].first.to_s == key)
            changes << ce
          end
        end
      end
    end

    content_type :xml
    Utils.xml do |x|
      x.changes do |x|
        changes.each do |ch|
          x.change do |x|
            x.id(ch.id)
            x.created(ch.created)
            x.message do |x|
              x.uuid(ch.message.uuid)
              x.name(ch.message.short)
            end
            x.parameters do |x|
              ch.targets.each do |k,v|
                if v.respond_to?(:to_xml)
                  x.parameter(:name => k) do |x|
                    v.to_xml(x, :no_children)
                  end
                else
                  x.parameter(v, :name => k)
                end
              end
            end
          end
        end
      end
    end
  end
end
