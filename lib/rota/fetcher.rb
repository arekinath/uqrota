require 'config'
require 'rota/model'
require 'rota/queues_alerts'

require 'rubygems'
require 'logger'
require 'net/https'
require 'mechanize'
require 'json'
require 'date'

module Rota
  
  class Timetable
    def fetch_user_page(user, pass)
      agent,page = login_page
      
      form = page.form('login')
      user_field = form.field_with(:name => 'userid')
      user_field.value = user.upcase
      pass_field = form.field_with(:name => 'pwd')
      pass_field.value = pass
      tz_field = form.field_with(:name => 'timezoneOffset')
      tz_field.value = '10'
      
      page = agent.submit(form)
      page = agent.get('https://www.sinet.uq.edu.au/psp/ps/EMPLOYEE/HRMS/h/?tab=UQ_MYPAGE&pageletname=MENU&cmd=refreshPglt')
      
      return [agent, page]
    end
    
    def parse_user_page(page)
      page = page.parser
      
      state = :idle
      semesters = {}
      last_semester = nil
      
      page.css('table.PSLEVEL1SCROLLAREABODY tr').each do |tr|
        case state
          when :idle
          tr.css('td span.PABOLDTEXT').each do |s|
            sem = Semester.first(:name => s.text.chomp.strip)
            if sem
              semesters[sem] = Array.new
              last_semester = sem
              puts "got semester #{sem.name}"
              state = :got_head
            end
          end
          when :got_head
          tr.css('td table td span.PSEDITBOX_DISPONLY').each do |cell|
            codes = cell.text.chomp.strip.scan(/[A-Z]{4}[0-9]{4}/)
            codes.each do |c|
              puts "got course #{c}"
              semesters[last_semester] << c
            end
          end
          state = :idle
        end
      end
      
      if (cs = semesters[Semester.current])
        cs.each do |code|
          c = Course.first(:code => code)
          o = c.offerings(:semester => Semester.current)
          if o
            # it's already found, add it
            o.series.each do |s|
              self.groups << s.groups[0]
            end
          else
            # fetch it
            course = Course.new(:code => code)
            course.save
            
            offering = Offering.new(:course => course, :semester => Semester.current)
            offering.save
            
            agent,page = offering.fetch_timetable
            offering.parse_timetable(page)
            
            offering.reload
            offering.series.each do |s|
              self.groups << s.groups[0]
            end
          end
        end
      end
      
      self.save
    end
  end
  
  class Program
    def Program.fetch_list
      Fetcher::standard_fetch('http://uq.edu.au/study/browse.html?level=ugpg')
    end
    
    def Program.parse_list(page)
      page = page.parser
      DataMapper::Transaction.new.commit do
        page.css("td.title").each do |tdt|
          tdt.css("a").each do |link|
            if link['href'] and link['href'].include?("acad_prog")
              link['href'].scan(/acad_prog=([0-9]+)([^0-9]|$)/).each do |prog_id, cl|
                p = Program.get(prog_id.to_i)
                if p.nil?
                  p = Program.new
                  p['id'] = prog_id.to_i
                  p.name = link.text.chomp.strip
                  p.save
                else
                  p.name = link.text.chomp.strip
                  p.save
                end
              end
            end
          end
        end
      end
    end
    
    def fetch_courses
      Fetcher::standard_fetch("http://uq.edu.au/study/program_list.html?acad_prog=#{self['id']}")
    end
    
    def parse_courses(page)
      page = page.parser
      DataMapper::Transaction.new.commit do
        self.plans.course_groups_each { |cg| cg.destroy! }
        self.plans.each { |pl| pl.destroy! }
        
        page.css("div.planlist").each do |plandiv|
          plan = Plan.new
          
          plan.name = plandiv.css('h1')[0].text.chomp.strip
          firstp = plandiv.css('p')[0]
          if not firstp.nil?
            txt = firstp.text.chomp.strip.gsub(/\n|\r/,' ').slice(0,50)
            plan.name += " (#{txt})" if txt.downcase.include?('major')
          end
          firsth2 = plandiv.css('h2')[0]
          if not firsth2.nil?
            txt = firsth2.text.chomp.strip.gsub(/\n|\r/,' ').slice(0,50)
            plan.name += " (#{txt})" if txt.downcase.include?('major')
          end
          
          plan.program = @program
          plan.save
          
          plandiv.css('div.courselist').each do |listdiv|
            grp = CourseGroup.new
            grp.plan = plan
            
            text = ""
            listdiv.css('h1').each do |t|
              text << t.text.chomp.strip
            end
            listdiv.css('h2').each do |t|
              text << t.text.chomp.strip
            end
            listdiv.css('p').each do |t|
              text << t.text.chomp.strip
            end
            
            grp.text = text
            grp.save
            
            listdiv.css('tr').each do |tr|
              cells = tr.css('td')
              unless cells[0].css('a')[0].nil?
                code = cells[0].css('a')[0].text.chomp.strip
                
                cse = Course.get(code)
                if cse.nil?
                  cse = Course.new
                  cse.code = code
                end
                cse.course_groups << grp if not cse.course_groups.include?(grp)
                cse.name = cells[2].text.chomp.strip
                cse.units = cells[1].text.chomp.strip.to_i
                cse.save
              end
            end
          end
        end
      end
    end
  end
  
  class Building
    def Building.fetch_list
      Fetcher::standard_fetch("http://uq.edu.au/maps/mapindex.html?menu=1")
    end
    
    def Building.parse_list(page)
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
            b = Building.first(:number => bnum)
            if b.nil?
              b = Building.new
            end
            b.map_id = bid
            b.name = bname
            b.number = bnum
            b.save
          end
        end
      end
    end
  end
  
  class Course
    def fetch_details
      Fetcher::standard_fetch("http://uq.edu.au/study/course.html?course_code=#{course.code}")
    end
    
    def parse_details(page)
      page = page.parser
      DataMapper::Transaction.new.commit do        
        sems = []
        t = page.to_s
        
        def check_sem(semname, sym)
          if t =~ /#{semname}, #{Time.now.year}/ or t =~ /#{semname}, #{Time.now.year-1}/
            sems << sym
          end
        end
        
        check_sem('Semester 1', 1)
        check_sem('Semester 2', 2)
        check_sem('Summer Semester', :summer)
        
        t = t.gsub("\n","")
        m = /<h1>Course description<\/h1>(.*)<h1>Archived offerings<\/h1>/.match(t)
        self.description = m[1] if m
        self.semesters_offered = sems.inspect
        self.save
        
        page.css('div#summary').each do |sumdiv|
          headings = Array.new
          sumdiv.css('h2').each do |h2|
            atp = h2.css('a.tooltip')[0]
            if atp.nil?
              headings << h2.text.chomp.strip
            else
              headings << atp.text.chomp.strip
            end
          end
          
          data = Hash.new
          i = 0
          sumdiv.css('p').each do |p|
            data[headings[i]] = p.text.chomp.strip
            i += 1
          end
          
          # now extract the prereq data
          t = ""
          data.each do |k,v|
            t += v.to_s if k.downcase.include?('prerequisite') or k.downcase.include?('recommended')
          end
          prereqs = t.scan(/[A-Z]{4}[0-9]{4}/)
          prereqs.each do |code|
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
          
          # and some other headings
          self.coordinator = data['Course coordinator'].to_s
          self.faculty = data['Faculty'].to_s
          self.school = data['School'].to_s
          self.save
        end
        
      end
    end
    
    def parse_offerings(page)
      page = page.parser
      DataMapper::Transaction.new.commit do
        self.prereqs.each { |p| p.destroy! }
        
        page.css('table.offerings').each do |otbl|
          otbl.css('tr').each do |tr|
            cells = tr.css('td')
            if (not cells[0].text.include?('Course offerings'))
              # not the header row
              pid = -1
              if cells[3].at_css('a')
                link = cells[3].at_css('a').attribute('href').value
                pid = link.scan(/profileId=([0-9]+)/).first.first
              end
              
              sem = Semester.first(:name => cells[0].text.chomp.strip)
              if not sem.nil?
                p = Offering.first(:profile_id => pid)
                if p.nil? or pid == -1
                  p = self.offerings.first(:semester => sem)
                  if p.nil?
                    p = Offering.new
                  end
                end
                p.course = self
                p.profile_id = pid
                p.semester = sem
                p.location = cells[1].text.chomp.strip
                p.current = true if tr['class'] and tr['class'].include?('current')
                p.mode = cells[2].text.chomp.strip
                p.save
              end
            end
          end
        end
      end
    end
  end
  
  class Semester
    def Semester.fetch_list
      Fetcher::SInet::tt_page
    end
    
    def Semester.parse_list(page)
      DataMapper::Transaction.new.commit do
        code = page.parser.to_s
        code.gsub!("\n","")
        code.gsub!(/&[a-z]*;/,"&")
        m = /var optionsArray_win0 = ([^;]*);/.match(code)
        json = m[1].gsub("\t","").gsub("'",'"')
        options = JSON.parse(json)
        sems = options[0]
        
        m = /var selectElemOptions_win0 = ([^;]*);/.match(code)
        json = m[1].gsub("\t","").gsub("'",'"')
        selects = JSON.parse(json)
        idx = selects.find { |d| d[0] == 'UQ_DRV_TT_GUEST_STRM' }[2][0]
        csem = sems[idx.to_i]
        
        Setting.set('current_semester', csem[0])
        sems.each do |opt|
          sem_id, sem_name = opt
          if (sem_id.to_i > 0 and (sem_id.to_i - csem[0].to_i).abs < 100)
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
  
  class Offering
    def fetch_profile
      Fetcher::standard_fetch("http://www.courses.uq.edu.au/student_section_loader.php?section=print_display&profileId=#{profile.profileId}")
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
      row_to_use = 0
      page.parser.css('table.PSLEVEL1GRIDNBO tr').each do |row|
        row.css('td').each do |cell|
          txt = cell.text
          sp = cell.css('span')[0]
          txt = sp.text if sp
          if txt
            txt = txt.chomp.strip
            # TODO: add support for other campuses
            ['Lucia','St Lucia'].each do |k|
              if txt.downcase.include?(k.downcase)
                row_to_use = row_n
              end
            end
          end
        end
        row_n += 1
      end
      
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
                best_s.day = r['Day']
                b = Building.find_or_create(r['Building'], r['Building Name'])
                best_s.building = b
                best_s.room = r['Room']
                best_s.start = TimetableSession.mins_from_string(r['Start'])
                best_s.finish = TimetableSession.mins_from_string(r['End'])
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
              b = Building.find_or_create(r['Building'], r['Building Name'])
              s.building = b
              s.room = r['Room']
              s.start = TimetableSession.mins_from_string(r['Start'])
              s.finish = TimetableSession.mins_from_string(r['End'])
              s.dates = r['Start/End Date (DD/MM/YYYY)']
              s.exceptions = r['Not taught on these dates (DD/MM/YYYY)']
              s.save
              
              s.build_events
              changed = true
            end
            
            # old sessions to destroy
            while sess_of_concern.size > 0
              s = sess_of_concern.pop
              s.destroy!
              changed = true
            end
            
            g.change_alert if changed
            
          end
        end
        
        # fire off series/course alerts
        if course_changed
          self.change_alert
        end
        
        changed_series.each do |s|
          s.change_alert
        end
        
        # any groups which haven't been touched have been removed from sinet!
        all_groups = series.collect { |s| s.groups }.flatten
        all_groups -= done_groups
        
        all_groups.each do |g|
          g.change_alert
          g.destroy!
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
        
        page = agent.click(page.link_with(:text => "Course & Timetable Info"))
        page = agent.click(page.iframe('TargetContent'))
        
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
