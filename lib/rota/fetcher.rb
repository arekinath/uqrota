require 'config'
require 'rota/model'
require 'rota/queues_alerts'

require 'rubygems'
require 'logger'
require 'net/https'
require 'mechanize'
require 'json'
require 'date'
require 'savon'

HTTPI.log = false
Savon.configure do |config|
  config.log = false
end

module Rota

  SinetEndpoint = "https://www.sinet.uq.edu.au/PSIGW/PeopleSoftServiceListeningConnector"

  class Program
    @@newprogram = Message.new("854d3d56-0958-487a-b867-479dc9ea00c0",
                               "New program available",
                               "A new program has become available.",
                               [:program])
    @@programname = Message.new("6b6dc097-631f-4622-9d6f-a444e0c06331",
                                "Program name changed",
                                "The name of a program has been changed.",
                                [:program, :old_name])

    def Program.fetch_list
      list_client = Savon::Client.new do
        wsdl.document = "#{SinetEndpoint}/UQ_CP_SEARCH_REQUEST.1.wsdl"
        wsdl.endpoint = SinetEndpoint
      end

      builder = Builder::XmlMarkup.new
      response = list_client.request :uq_cp_search_request do
        soap.body = builder.MsgData do |m|
          m.Transaction do |t|
            t.parameters(:class => 'R') do |p|
              p.LEVEL('UGRD')
              p.SEARCHTYPE('PROGRAM')
            end
          end
        end
      end

      h = response.to_hash
      return response, h[h.keys.first][:msg_data][:transaction][:search_results]
    end

    def Program.parse_list(h)
      h[:program].each do |ph|
        Program.transaction do
          p = Program.get(ph[:code].to_i)
          if p.nil?
            p = Program.new
            p['id'] = ph[:code].to_i
            p.name = ph[:title]
            p.save
            ChangelogEntry.make($0, @@newprogram, {:program => p})
          else
            if (p.name != ph[:title])
              ChangelogEntry.make($0, @@programname, {:program => p, :old_name => p.name})
            end
            p.name = ph[:title]
            p.save
          end
        end
      end
    end

    def fetch_courses
      prog_client = Savon::Client.new do
        wsdl.document = "#{SinetEndpoint}/UQ_CP_DISPLAY_PRGLIST_REQUEST.1.wsdl"
        wsdl.endpoint = SinetEndpoint
      end

      builder = Builder::XmlMarkup.new
      response = prog_client.request :uq_cp_display_prglist_request do
        soap.body = builder.MsgData do |m|
          m.Transaction do |t|
            t.ProgramList(:class => 'R') do |p|
              p.YEAR(Time.now.year.to_s)
              p.CODE(self['id'].to_s)
            end
          end
        end
      end

      h = response.to_xml
      return response, h
    end

    def parse_courses(x)
      Program.transaction do
        if self.plans.size > 0
          if self.plans.course_groups.size > 0
            self.plans.course_groups.each { |cg| cg.destroy! }
          end
          self.plans.each { |pl| pl.destroy! }
        end
      end

      defaultplan = Plan.new
      defaultplan.name = self.name
      defaultplan.program = self

      doc = Nokogiri::XML(x)
      ns = doc.root.namespaces
      ns['xmlns:soapenv'] = 'http://schemas.xmlsoap.org/soap/envelope/'
      ns['xmlns:uq'] = 'http://peoplesoft.com/UQ_CP_DISPLAY_PRGLIST_RESPONSEResponse'

      resp = doc.xpath('/soapenv:Envelope/soapenv:Body/uq:UQ_CP_DISPLAY_PRGLIST_RESPONSE', ns).first
      orders = resp.xpath('./uq:MsgData/uq:Transaction/uq:ProgramListDetail/uq:Order', ns)

      orders.each do |order|
        pl = order.xpath('./uq:PlanListDetail', ns)
        cl = order.xpath('./uq:CourseListDetail', ns)

        cl.each do |cld|
          title = cld.xpath('./uq:TITLE', ns)[0].text
          header = cld.xpath('./uq:HEADER', ns)[0].text

          cg = CourseGroup.new
          cg.plan = defaultplan
          t = []
          t << title if title.size > 0
          t << header if header.size > 0
          cg.text = t.join(" - ")

          cg.save
          defaultplan.save

          cld.xpath('./uq:Course', ns).each do |cs|
            off = cs.xpath('./uq:Offering', ns)[0]
            if not off.nil?
              code = off.xpath('./uq:CODE', ns)[0].text
              title = cs.xpath('./uq:TITLE', ns)[0].text
              units = cs.xpath('./uq:UNITS', ns)[0].text.to_i

              c = nil
              Course.transaction do
                c = Course.get(code)
                if c.nil?
                  c = Course.create(:code => code,
                                    :name => title,
                                    :units => units)
                  c.save
                end
              end
              c.course_groups << cg unless c.course_groups.include?(cg)
              c.save
            end
          end
        end

        pl.each do |pld|
          title = pld.xpath('./uq:TITLE', ns)[0].text

          plan = Plan.new
          plan.name = title
          plan.program = self
          plan.save

          pld.xpath('./uq:PlanCourseList', ns).each do |pcl|
            title = pcl.xpath('./uq:TITLE', ns)[0].text
            header = pcl.xpath('./uq:HEADER', ns)[0].text

            cg = CourseGroup.new
            cg.plan = plan
            t = []
            t << title if title.size > 0
            t << header if header.size > 0
            cg.text = t.join(" - ")
            cg.text = cg.text.slice(0,500)
            cg.save

            pcl.xpath('./uq:PlanCourse', ns).each do |cs|
              off = cs.xpath('./uq:PlanOffering', ns)[0]
              code = off.xpath('./uq:CODE', ns)[0].text
              title = cs.xpath('./uq:TITLE', ns)[0].text
              units = cs.xpath('./uq:UNITS', ns)[0].text.to_i

              c = nil
              Course.transaction do
                c = Course.get(code)
                if c.nil?
                  c = Course.create(:code => code,
                                    :name => title,
                                    :units => units)
                  c.save
                end
              end
              c.course_groups << cg unless c.course_groups.include?(cg)
              c.save
            end
          end
        end
      end
    end
  end

  class Building
    def Building.fetch_list(n=1)
      Fetcher::standard_fetch("http://uq.edu.au/maps/mapindex.html?menu=#{n}")
    end

    def Building.parse_list(page, campus)
      page = page.parser
      DataMapper::Transaction.new.commit do
        page.css("br").each do |br|
          br.content = "."
        end

        t = page.text
        page.css("a.mapindex-links").each do |a|
          bname = a.text
          bnum = t.scan(/#{bname}, ([A-Z0-9]+)/)
          bid = a['href'].scan(/id=([0-9]+)/)
          if bid[0] and bid[0][0] and bnum[0] and bnum[0][0]
            bnum, bid = [bnum[0][0], bid[0][0]]
            bnum = bnum.gsub(/^0+/,'').upcase
            b = Building.first(:campus => campus, :number => bnum)
            if b.nil?
              b = Building.new
            end
            b.map_id = bid
            b.campus = campus
            b.name = bname
            b.number = bnum
            b.save
          end
        end
      end
    end
  end

  class Course

    def Course.fetch_list
      c = Savon::Client.new do
        wsdl.document = "#{SinetEndpoint}/UQ_CP_SEARCH_REQUEST.1.wsdl"
        wsdl.endpoint = SinetEndpoint
      end
      c.http.read_timeout = 300
      builder = Builder::XmlMarkup.new
      response = c.request :uq_cp_search_request do
        soap.body = builder.MsgData do |m|
          m.Transaction do |t|
            t.parameters(:class => 'R') do |p|
              p.SEARCHTYPE('COURSE')
              p.CourseParameters(:class => 'R') do |cp|
                cp.INCLUDE_UNSCHEDULED('TRUE')
                cp.Semester(:class => 'R') do |s|
                  scur = Semester.current
                  s.SEMESTERID(scur.semester_id)
                  s.YEAR("#{scur.year}")
                end
              end
            end
          end
        end
      end
      return response, response.to_xml
    end

    def Course.parse_list(x)
      doc = Nokogiri::XML(x)
      ns = doc.root.namespaces
      ns['xmlns:soapenv'] = 'http://schemas.xmlsoap.org/soap/envelope/'
      ns['xmlns:uq'] = 'http://peoplesoft.com/UQ_CP_SEARCH_RESPONSEResponse'

      resp = doc.xpath('/soapenv:Envelope/soapenv:Body/uq:UQ_CP_SEARCH_RESPONSE', ns).first
      courses = resp.xpath('./uq:MsgData/uq:Transaction/uq:SearchResults/uq:Course', ns)

      courses.each do |cx|
        code = cx.xpath('./uq:CODE', ns)[0].text
        title = cx.xpath('./uq:TITLE', ns)[0].text
        units = cx.xpath('./uq:UNITS', ns)[0].text.to_i

        c = nil
        Course.transaction do
          c = Course.get(code)
          if c.nil?
            c = Course.create(:code => code,
                              :name => title,
                              :units => units)
            c.save
          end
        end
      end
    end

    def fetch_details
      client = Savon::Client.new do
        wsdl.document = "#{SinetEndpoint}/UQ_CP_DISPLAY_COURSE_REQUEST.1.wsdl"
        wsdl.endpoint = SinetEndpoint
      end
      builder = Builder::XmlMarkup.new
      response = client.request :uq_cp_display_course_request do
        soap.body = builder.MsgData do |m|
          m.Transaction do |t|
            t.Course(:class => 'R') do |p|
              p.CODE(self.code)
              p.YEAR(Time.now.year.to_s)
            end
          end
        end
      end
      return response, response.to_xml
    end

    @@coursename = Message.new("edd36b27-9b53-4d27-bcaf-7b400a047ca7",
                               "Course name or description changed",
                               "The name of a course or its detailed description has been changed.",
                               [:course, :old_name])
    @@courseunits = Message.new("4369daf7-839f-4720-9292-e46e8561c346",
                                "Course unit value changed",
                                "The unit value of a course has changed.",
                                [:course, :old_units])
    @@coursecoord = Message.new("be66aa23-1190-4146-bbed-1033f614b428",
                                "Course coordinator, school or faculty changed",
                                "The coordinator, school or faculty responsible for a course has been changed.",
                                [:course, :old_coordinator, :old_faculty, :old_school])

    def parse_details(x)
      doc = Nokogiri::XML(x)
      ns = doc.root.namespaces
      ns['xmlns:soapenv'] = 'http://schemas.xmlsoap.org/soap/envelope/'
      ns['xmlns:uq'] = 'http://peoplesoft.com/UQ_CP_DISPLAY_COURSE_RESPONSEResponse'

      resp = doc.xpath('/soapenv:Envelope/soapenv:Body/uq:UQ_CP_DISPLAY_COURSE_RESPONSE', ns).first
      cd = resp.xpath('./uq:MsgData/uq:Transaction/uq:CourseDetails', ns)[0]

      return if cd.nil?

      DataMapper::Transaction.new.commit do
        name = cd.xpath('./uq:TITLE', ns).first.text
        units = cd.xpath('./uq:UNITS', ns).first.text.to_i
        desc = cd.xpath('./uq:SUMMARY', ns).first.text
        coord = cd.xpath('./uq:COORDINATOR', ns).first.text
        faculty = self.faculty
        school = self.school

        foff = cd.xpath('./uq:Offerings/uq:Offering[1]', ns).first
        unless foff.nil?
          faculty = foff.xpath('./uq:FACULTY_VALUE', ns).first.text
          schoole = foff.xpath('./uq:School/uq:SCHOOL_VALUE', ns).first
          unless schoole.nil?
            school = schoole.text
          end
        end

        if self.name != name or self.description != desc
          ChangelogEntry.make($0, @@coursename, {:course => self, :old_name => self.name})
        end
        if self.units != units
          ChangelogEntry.make($0, @@courseunits, {:course => self, :old_units => self.units})
        end
        if self.coordinator != coord or self.faculty != faculty or self.school != school
          ChangelogEntry.make($0, @@coursecoord, {:course => self, :old_coordinator => self.coordinator, :old_faculty => self.faculty, :old_school => self.school})
        end

        self.name = name
        self.units = units
        self.description = desc
        self.coordinator = coord
        self.last_update = DateTime.now
        self.faculty = faculty
        self.school = school
      end

      DataMapper::Transaction.new.commit do
        self.prereqships.each { |p| p.destroy! }
        prs = ""
        prs += cd.xpath('./uq:PREREQUISITE', ns).first.text
        prs += cd.xpath('./uq:RECOMMENDEDPREREQUISITE', ns).first.text
        prereqs = prs.scan(/[A-Z]{4}[0-9]{4}/)
        prereqs.each do |code|
          next if code == self.code

          cse = Course.get(code)
          if cse.nil?
            cse = Course.new
            cse.code = code
            cse.save
          end
          p = Prereqship.new
          p.dependent = self
          p.prereq = cse
          p.save
        end
      end
    end

    @@newoffering = Message.new("a071e8a7-8ed2-4300-a166-6cc07f064737",
                                "New offering available",
                                "A new offering is available for the course.",
                                [:offering])
    @@goneoffering = Message.new("478c4d82-5174-4b3a-a61f-1290b0d246ae",
                                 "Offering withdrawn",
                                 "An offering for the course has been withdrawn.",
                                 [:course, :old_id, :old_sinet_class, :old_semester, :old_campus])

    def parse_offerings(x)
      doc = Nokogiri::XML(x)
      ns = doc.root.namespaces
      ns['xmlns:soapenv'] = 'http://schemas.xmlsoap.org/soap/envelope/'
      ns['xmlns:uq'] = 'http://peoplesoft.com/UQ_CP_DISPLAY_COURSE_RESPONSEResponse'

      resp = doc.xpath('/soapenv:Envelope/soapenv:Body/uq:UQ_CP_DISPLAY_COURSE_RESPONSE', ns).first
      cd = resp.xpath('./uq:MsgData/uq:Transaction/uq:CourseDetails', ns)[0]

      return if cd.nil?

      cur_offerings = self.offerings

      DataMapper::Transaction.new.commit do
        is_first = true
        cd.xpath('./uq:Offerings/uq:Offering', ns).each do |off|
          sem_id = off.xpath('./uq:Commencement/uq:SEMESTER',ns).first.text.to_i
          campus_key = off.xpath('./uq:CAMPUS_KEY',ns).first.text
          campus_val = off.xpath('./uq:CAMPUS_VALUE',ns).first.text
          mode = off.xpath('./uq:MODE_VALUE',ns).first.text
          location = off.xpath('./uq:LOCATION_VALUE',ns).first.text
          classid = off.xpath('./uq:CLASS',ns).first.text.to_i

          sem = Semester.get(sem_id)
          camp = Campus.get(campus_key)
          if camp.nil?
            camp = Campus.create(:code => campus_key, :name => campus_val)
            camp.save
          end
          if not sem.nil?
            is_new = false
            p = Offering.first(:semester => sem, :sinet_class => classid)
            if p.nil?
              p = self.offerings.first(:semester => sem, :campus => camp,
                                       :mode => mode, :location => location)
              if p.nil?
                p = self.offerings.first(:semester => sem, :campus => camp)
                if (p.nil? or (p.mode and p.mode.size > 0) or
                    (p.location and p.location.size > 0))
                  p = Offering.new
                  is_new = true
                end
              end
            end
            p.course = self
            p.sinet_class = classid
            p.semester = sem
            p.campus = camp
            p.location = location
            p.current = is_first
            p.mode = mode
            p.save

            if is_new
              ChangelogEntry.make($0, @@newoffering, {:offering => p})
            end

            cur_offerings.delete(p)
          end
          is_first = false
        end
      end

      # remove outdated offerings
      cur_offerings.each do |off|
        ChangelogEntry.make($0, @@goneoffering, {:course => self, :old_id => off.id, :old_sinet_class => off.sinet_class, :old_semester => off.semester, :old_campus => off.campus})
        off.destroy!
      end
    end
  end

  class Semester
    def fetch_dates
      Fetcher::standard_fetch("http://uq.edu.au/events/calendar_view.php?category_id=16&year=#{self.year}")
    end

    def parse_dates(page)
      ordinal = case
        when self.name.include?('Semester 1'); 'first'
        when self.name.include?('Semester 2'); 'second'
        when self.name.include?('Summer'); 'summer'
        when self.name.include?('Trimester 1'); ''
        when self.name.include?('Trimester 2'); ''
        when self.name.include?('Trimester 3'); ''
      end

      state = :idle
      page.parser.css("li.event_row").each do |rli|
        date = rli.css('li.first').first.text.downcase
        desc = rli.css('li.description-calendar-view').first.text.downcase
        if desc.include?(ordinal) and desc.include?('semester') and (desc.include?('commence') or desc.include?('start') or desc.include?('begin'))
          self.start_week = DateTime.parse(date).strftime('%W').to_i
          state = :start
        end
        if state == :start and desc.include?(ordinal) and desc.include?('semester') and (desc.include?('end') or desc.include?('finish'))
          self.finish_week = DateTime.parse(date).strftime('%W').to_i
          state = :idle
        end
        if state == :start and desc.include?('mid') and desc.include?('semester') and desc.include?('break') and not desc.include?('after') and not desc.include?('classes')
          self.midsem_week = DateTime.parse(date).strftime('%W').to_i
        end
      end
      self.save
    end

    def Semester.fetch_list
      Fetcher::SInet::tt_page
    end

    def Semester.parse_list(page)
      DataMapper::Transaction.new.commit do
        form = page.form('win0')
        strm_sel = form.field_with(:name => 'UQ_DRV_TT_GUEST_STRM')

        Setting.set('current_semester', strm_sel.value)
        strm_sel.options.each do |opt|
          sem_id, sem_name = [opt.value, opt.text]
          if (sem_id.to_i > 0 and (sem_id.to_i - strm_sel.value.to_i).abs < 100)
            sem = Semester.get(sem_id.to_i)
            if sem.nil?
              sem = Semester.new
              sem['id'] = sem_id.to_i
              sem.name = sem_name.gsub("#{sem_id} - ", '')
              sem.save
            end
          end
        end
      end
    end
  end

  class Campus
    def Campus.fetch_list
      Fetcher::SInet::tt_page
    end

    def Campus.parse_list(page)
      DataMapper::Transaction.new.commit do
        form = page.form('win0')
        src_sel = form.field_with(:name => 'UQ_DRV_CRSE_SRC_DESCRSHORT')
        src_sel.options.each do |opt|
          code, name = [opt.value, opt.text]
          if code.size > 1
            camp = Campus.get(code)
            if camp.nil?
              camp = Campus.create(:code => code, :name => name)
              camp.save
            end
          end
        end
      end
    end
  end

  class Offering
    def fetch_profile
      Fetcher::standard_fetch("http://www.courses.uq.edu.au/student_section_loader.php?section=print_display&profileId=#{self.profile_id}")
    end

    def parse_profile(page)
      page = page.parser
      DataMapper::Transaction.new.commit do
        self.assessment_tasks.each { |t| t.destroy! }

        found = false
        page.css("table").each do |tbl|
          if not found
            first_row = tbl.css("tr")[0]
            first_cell = first_row.css('td')[0] if first_row
            if first_row and first_cell and first_cell.text.include?("Assessment Task")
              found = true
              tbl.css("tr").each do |tr|
                unless tr.css("td")[0].text.include?("Assessment Task")
                  # got non-header row
                  tr.css("br").each do |br|
                    br.content = " "
                  end

                  cells = tr.css("td")

                  name = nil; desc = nil
                  if cells[0].at_css('i')
                    desc = cells[0].at_css("i").text.chomp.strip
                    name = cells[0].text.chomp.strip.sub(desc, "")
                    if name.size < 5
                      name = desc + name
                      desc = nil
                    end
                  else
                    name = cells[0].text.chomp.strip
                  end

                  t = AssessmentTask.new
                  t.offering = self
                  t.name = name
                  t.description = desc
                  t.due_date = cells[1].text.chomp.strip if cells[1]
                  t.weight = cells[2].text.chomp.strip if cells[2]
                  t.save
                end
              end
            end
          end

        end
      end
    end

    @@zeromatch = Message.new("ead0ca85-27b4-4d2a-ab70-95caafce5079",
                              "SI-net returned no matching classes",
                              "Occurs when SI-net's timetable search page returns no results for a course, even though that course has previously been indexed by SOAP services.",
                              [:offering])
    @@newseries = Message.new("90ec190c-f5e6-4edf-8c74-186ba23b797d",
                              "New series available in offering",
                              "A new timetable series has been made available for the course. For example, the course has begun offering prac sessions as well as just lectures.",
                              [:series])
    @@goneseries = Message.new("d8f91a66-bae6-4a00-b66d-2912354bdcab",
                               "Series removed from offering",
                               "A timetable series has been withdrawn from the course offering. For example, previously prac sessions were offered, but now only lectures are.",
                               [:offering, :old_name, :old_id])
    @@newgroup = Message.new("b71a3c12-78ec-4fac-9c60-4231b1397d56",
                             "New group available in series",
                             "A new timetable group has been made available in the series for course. For example, a new prac session has been made available.",
                             [:group])
    @@locationchanged = Message.new("e1580d7e-8954-4ae8-a99f-579139d989d7",
                                    "Session location changed",
                                    "The location (building/room) of the target session has changed, and it has been moved to a new location.",
                                    [:session, :old_building, :old_room])
    @@timechanged = Message.new("6623a30d-7321-4e7b-99fc-b3e9d585039a",
                                "Session time changed",
                                "The day of the week, start or finish time of the target session has changed.",
                                [:session, :old_day, :old_start_time, :old_finish_time])
    @@schedulechanged = Message.new("bb16ed5e-e20f-4005-b0d3-5206c3d1b704",
                                    "Session schedule changed",
                                    "The by-week schedule for the session changed -- either the start and end dates of its run or the 'not taught weeks' have been updated.",
                                    [:session, :old_dates, :old_exceptions])
    @@newsession = Message.new("0172961a-963b-4aba-89d8-2a6f834358f9",
                               "New session available",
                               "A new session is available within a timetable group. For example, a prac P2 is now occuring on Monday as well as Wednesday.",
                               [:session])
    @@gonesession = Message.new("66ef1585-dfc9-493c-a6e4-5f9c92f83f8c",
                                "Session removed from group",
                                "A session that was previously associated with this group has been removed.",
                                [:group, :old_id, :old_day, :old_start_time])
    @@groupbubble = Message.new("60d6e320-758f-445e-897d-7ad315db48c0",
                                "Sessions within group have been changed",
                                "Sessions in this group have changed -- these may be additions, removals or alterations.",
                                [:group])
    @@seriesbubble = Message.new("d1a45481-ca57-4ba0-9902-d31e13175823",
                                 "Groups within series have been changed",
                                 "Groups within this series have changed -- these may be additions, removals or alterations.",
                                 [:series])
    @@coursebubble = Message.new("a2ce5857-2d79-4de6-bf44-08c5df7f4b96",
                                 "Timetable information for offering has changed",
                                 "Timetable information for this offering has been changed -- these may be additions, removals or alterations.",
                                 [:offering])
    @@gonegroup = Message.new("b57d0973-a49a-4624-83f9-4174bd1c5ece",
                              "Timetable group withdrawn from series",
                              "A timetable group (eg P1) has been withdrawn from the series (eg P) and no close equivalent was found.",
                              [:series, :old_id, :old_name])



    def fetch_timetable
      agent, page = Fetcher::SInet::sem_page(self.semester)
      form = page.form('win0')

      # fill out the course code field
      cc = form.field_with(:name => 'UQ_DRV_CRSE_SRC_UQ_SUBJECT_SRCH')
      cc.value = self.course.code

      # this is what the javascript does to submit
      form.ICAction = 'UQ_DRV_TT_GUEST_UQ_SEARCH_PB'
      form.ICXPos = 100
      form.ICYPos = 100
      form.ICResubmit = 0
      page = agent.submit(form)

      # now figure out which row of the table is the one we want (at St Lucia)
      row_n = -1
      row_weights = Hash.new(0)
      page.parser.css('table.PSLEVEL1GRIDNBO tr').each do |row|
        row.css('td').each do |cell|
          txt = cell.text
          sp = cell.css('span')[0]
          txt = sp.text if sp
          if txt
            txt = txt.chomp.strip
            if txt.downcase.include?(self.mode.downcase)
              row_weights[row_n] += 1
            end
            if txt.downcase.include?(self.campus.code.downcase)
              row_weights[row_n] += 1
            end
            if txt.downcase.include?(self.campus.name.downcase)
              row_weights[row_n] += 1
            end
            if txt.downcase.include?(self.location.downcase)
              row_weights[row_n] += 1
            end
          end
        end
        row_n += 1
      end

      if row_n == -1
        ChangelogEntry.make($0, @@zeromatch, {:offering => self})
        return [agent, nil]
      end
      row_to_use = row_weights.sort_by { |r,w| w }.reverse.first[0]

      # and tick the check box on that row
      form = page.form('win0')
      chk = form.field_with(:name => "UQ_DRV_TT_GUEST$selmh$#{row_to_use}$$0")
      chk.value = 'Y'

      # now do the submit voodoo again
      form.ICAction = 'UQ_DRV_TT_GUEST_UQ_NEXT_BUTTON$0'
      form.ICXPos = 200
      form.ICYPos = 200
      form.ICResubmit = 0
      page = agent.submit(form)

      # and we should have the course page!
      return [agent, page]
    end

    def parse_timetable(page)
      return if page.nil?

      page = page.parser
      DataMapper::Transaction.new.commit do
        self.last_update = DateTime.now
        self.save

        headings = []

        page.css('table.PSLEVEL2GRIDWBO tr').each do |tr|
          tr.css('th').each do |th|
            headings << th.text
          end
        end

        series = self.series
        rows_by_class = Hash.new([])
        page.css('table.PSLEVEL2GRIDWBO tr').each do |tr|
          n = 0
          row = {}
          tr.css('td').each do |td|
            td.css('span').each do |cell|
              row[headings[n]] = cell.text.strip.chomp
            end
            n += 1
          end

          cls = row['Class']
          rows_by_class[cls] = rows_by_class[cls] + [ row ]
        end

        #puts rows_by_class.inspect

        done_series = []
        done_groups = []

        course_changed = false
        changed_series = Array.new

        rows_by_class.each do |cls, rows|
          # use the UQ convention for names
          m = /([A-Z]*)([0-9]*)/.match(cls)
          if not m.nil?
            series_name = m[1]
            group_name = m[2]

            # now see if the series exists
            s = series.find { |s| s.name == series_name }
            if s.nil?
              s = TimetableSeries.new
              s.name = series_name
              s.offering = self
              s.save
              series << s
              ChangelogEntry.make($0, @@newseries, {:series => s})
              course_changed = true
            end
            done_series << s

            # and the group
            groups = s.groups
            g = groups.find { |g| g.name == group_name }
            if g.nil?
              g = TimetableGroup.new
              g.name = group_name
              g.series = s
              g.save
              ChangelogEntry.make($0, @@newgroup, {:group => g})
              groups << g
              changed_series << s
            else
              # invalidate the group in case we did another update recently
              g.reload
            end
            done_groups << g

            # now grab the existing sessions (if any)
            sessions = g.sessions

            # and build similarity map
            sim_map = Hash.new

            # build similarity map
            sessions.each do |sess|
              rows.each do |r|
                sim = 0
                sim += 1 if sess.day == r['Day']
                sim += 1 if sess.building.number == r['Building']
                sim += 1 if sess.room == r['Room']
                sim += 1 if sess.start == TimetableSession.mins_from_string(r['Start'])
                sim += 1 if sess.finish == TimetableSession.mins_from_string(r['End'])
                sim += 1 if sess.dates == r['Start/End Date (DD/MM/YYYY)']
                sim += 1 if sess.exceptions == r['Not taught on these dates (DD/MM/YYYY)']
                sim_map[[r,sess]] = sim
              end
            end

            rows_of_concern = rows.clone
            sess_of_concern = sessions.clone

            changed = false

            while rows_of_concern.size > 0 and sess_of_concern.size > 0
              r = rows_of_concern.pop

              best_s = nil
              sess_of_concern.each do |s|
                if best_s.nil? or sim_map[[r,s]] > sim_map[[r,best_s]]
                  best_s = s
                end
              end

              if sim_map[[r, best_s]] < 7
                # we have to make changes
                # TODO: handle alerts here
                b = Building.find_or_create(self.campus, r['Building'], r['Building Name'])
                if (best_s.building != b or best_s.room != r['Room'])
                  ChangelogEntry.make($0, @@locationchanged, {:session => best_s, :old_building => best_s.building, :old_room => best_s.room})
                end
                best_s.building = b
                best_s.room = r['Room']
                if (best_s.day != r['Day'] or best_s.start_time != r['Start'] or best_s.finish_time != r['End'])
                  ChangelogEntry.make($0, @@timechanged, {:session => best_s, :old_day => best_s.day, :old_start_time => best_s.start_time, :old_finish_time => best_s.finish_time})
                end
                best_s.day = r['Day']
                best_s.start_time = r['Start']
                best_s.finish_time = r['End']

                if (best_s.dates != r['Start/End Date (DD/MM/YYYY)'] or best_s.exceptions != r['Not taught on these dates (DD/MM/YYYY)'])
                  ChangelogEntry.make($0, @@schedulechanged, {:session => best_s, :old_dates => best_s.dates, :old_exceptions => best_s.exceptions})
                end
                best_s.dates = r['Start/End Date (DD/MM/YYYY)']
                best_s.exceptions = r['Not taught on these dates (DD/MM/YYYY)']
                best_s.save

                best_s.build_events
                changed = true
              end

              sess_of_concern.delete(best_s)
            end

            # new sessions to add
            while rows_of_concern.size > 0
              r = rows_of_concern.pop

              s = TimetableSession.new
              s.group = g
              s.day = r['Day']
              b = Building.find_or_create(self.campus, r['Building'], r['Building Name'])
              s.building = b
              s.room = r['Room']
              s.start = TimetableSession.mins_from_string(r['Start'])
              s.finish = TimetableSession.mins_from_string(r['End'])
              s.dates = r['Start/End Date (DD/MM/YYYY)']
              s.exceptions = r['Not taught on these dates (DD/MM/YYYY)']
              s.save

              ChangelogEntry.make($0, @@newsession, {:session => s})

              s.build_events
              changed = true
            end

            # old sessions to destroy
            while sess_of_concern.size > 0
              s = sess_of_concern.pop
              ChangelogEntry.make($0, @@gonesession, {:group => g, :old_id => s.id, :old_day => s.day, :old_start_time => s.start_time})
              s.destroy!
              changed = true
            end

            ChangelogEntry.make($0, @@groupbubble, {:group => g}) if changed

          end
        end

        # fire off series/course alerts
        if course_changed
          ChangelogEntry.make($0, @@coursebubble, {:offering => self})
        end

        changed_series.each do |s|
          ChangelogEntry.make($0, @@seriesbubble, {:series => s})
        end

        # any groups which haven't been touched have been removed from sinet!
        all_groups = self.series.collect { |s| s.groups }.flatten
        all_groups -= done_groups

        all_groups.each do |g|
          ChangelogEntry.make($0, @@gonegroup, {:series => g.series, :old_id => g.id, :old_name => g.name})
          g.destroy!
        end

        # any series that haven't been touched are gone, too
        all_series = self.series
        all_series -= done_series

        all_series.each do |s|
          ChangelogEntry.make($0, @@goneseries, {:offering => self, :old_id => s.id, :old_name => s.name})
          s.destroy!
        end

      end

    end
  end

  module Fetcher
    UserAgent = Rota::Config['updater']['useragent']
    Timeout = Rota::Config['updater']['timeout'].to_i

    def self.standard_fetch(url)
      agent = Mechanize.new
      agent.user_agent = UserAgent
      agent.keep_alive = false
      agent.read_timeout = Timeout

      page = agent.get(url)
      return [agent, page]
    end

    module SInet
      def self.tt_page
        agent,page = login_page

        page = agent.get('https://www.sinet.uq.edu.au/psc/ps/EMPLOYEE/HRMS/c/UQMY_GUEST.UQMY_GUEST_TTBLE.GBL?FolderPath=PORTAL_ROOT_')

        return [agent, page]
      end

      def self.login_page
        agent = Mechanize.new
        agent.user_agent = UserAgent
        agent.keep_alive = false
        agent.read_timeout = Timeout

        page = agent.get('https://www.sinet.uq.edu.au/')
        page = agent.get('https://www.sinet.uq.edu.au/psp/ps/?cmd=login')
        page = agent.get('https://www.sinet.uq.edu.au/psp/ps/EMPLOYEE/HRMS/h/?tab=UQ_GENERAL')

        return [agent, page]
      end

      def self.sem_page(sem)
        agent, page = tt_page

        form = page.form('win0')
        pd = form.field_with(:name => 'UQ_DRV_TT_GUEST_STRM')
        pd.value = sem['id'].to_s

        return [agent, page]
      end

    end

  end

end
