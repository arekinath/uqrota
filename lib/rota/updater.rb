require 'config'
require 'rota/model'
require 'rota/queues_alerts'
require 'rota/fetcher'
require 'thread'

module Rota
  
  class TaskRunner
    def initialize(tasks, nth=Rota::Config['updater']['threads']['default'])
      @tasks = tasks
      @mutex = Mutex.new
      @nthreads = nth
      @total = tasks.size
    end
    
    def run(desc, terminal=false)
      mutex, tasks = [@mutex, @tasks]
      ths = []
      @nthreads.times do
        ths << Thread.new do
          count = 1
          while count > 0
            task = nil
            mutex.synchronize { task = tasks.pop }
            if task
              begin
                task.run
              rescue Exception => err
                puts err.inspect
                puts err.backtrace.join("\n")
                exit(1)
              end
            end
            
            mutex.synchronize { count = tasks.size }
          end
        end
      end
      
      if terminal
        print "[#{desc}] starting..."
        count = 1
        while count > 0
          sleep(1)
          @mutex.synchronize { count = @tasks.size }
          pc = "%.2f" % ((@total-count).to_f / @total.to_f * 100.0)
          print "\r[#{desc}] #{@total-count}/#{@total} tasks taken (#{pc}\%)"
        end
        ths.each { |th| th.join }
        print "\n[#{@desc}] done.\n"
      else
        puts "[#{Time.now.strftime('%Y-%m-%d %H:%M')}] Beginning #{desc}..."
        count = 1
        while count > 0
          sleep(5)
          @mutex.synchronize { count = @tasks.size }
        end
        ths.each { |th| th.join }
        puts "[#{Time.now.strftime('%Y-%m-%d %H:%M')}] #{desc} completed."
      end
    end
  end
  
  module UpdateTasks
    
    class SafeRunTask
      def run
        errcount = 0
        begin
          self.safe_run
        rescue Timeout::Error => err
          puts "[#{Time.now.strftime('%Y-%m-%d %H:%M')}] timeout on #{self.to_s}, retrying..."
          sleep(1)
          retry
        rescue Exception => err
          errcount += 1
          if errcount < 5
            puts "[#{Time.now.strftime('%Y-%m-%d %H:%M')}] error #{err.class.inspect} on #{self.to_s}... retrying..."
            sleep(2)
            retry
          else
            errstr = "[#{Time.now.strftime('%Y-%m-%d %H:%M')}] 5x repeated error on #{self.to_s}, giving up.\n"
            errstr += err.inspect + "\n"
            errstr += err.backtrace.join("\n\t")
            puts errstr
            
            em = Rota::QueuedEmail.new(:recipient => Rota::Config['updater']['reports'])
            em.subject = "Update task error: #{self.to_s}"
            em.body = errstr
            em.save
          end
        end
      end
    end
    
    class ProgramListTask < SafeRunTask
      def safe_run
        agent, page = Program.fetch_list
        Program.parse_list(page)
      end
      
      def to_s
        "ProgramList"
      end
    end
    
    class SemesterListTask < SafeRunTask
      def safe_run
        agent, page = Semester.fetch_list
        Semester.parse_list(page)
      end
      
      def to_s
        "SemesterList"
      end
    end
    
    class SemesterTask < SafeRunTask
      def initialize(sem)
        @semester = sem
      end
      
      def safe_run
        agent, page = @semester.fetch_dates
        @semester.parse_dates(page)
      end
      
      def to_s
        "SemesterTask<#{@semester['id']}>"
      end
    end
    
    class BuildingListTask < SafeRunTask
      def safe_run
        agent, page = Building.fetch_list
        Building.parse_list(page)
      end
      
      def to_s
        "BuildingList"
      end
    end
    
    class ProgramTask < SafeRunTask
      def initialize(program)
        @program = program
      end
      
      def safe_run
        agent, page = @program.fetch_courses
        @program.parse_courses(page)
      end
      
      def to_s
        "Program<#{@program.name}>"
      end
    end
    
    class CourseTask < SafeRunTask
      def initialize(course)
        @course = course
      end
      
      def safe_run
        agent, page = @course.fetch_details
        @course.parse_details(page)
        @course.parse_offerings(page)
      end
      
      def to_s
        "Course<#{@course.code}>"
      end
    end
    
    class ProfileTask < SafeRunTask
      def initialize(offering)
        @offering = offering
      end
      
      def safe_run
        agent,page = @offering.fetch_profile
        @offering.parse_profile(page)
      end
      
      def to_s
        "Profile<#{@offering.course.code}/#{@offering.semester['id']}>"
      end
    end
    
    class TimetableTask < SafeRunTask
      def initialize(offering)
        @offering = offering
      end
      
      def safe_run
        agent, page = @offering.fetch_timetable
        @offering.parse_timetable(page)
      end
      
      def to_s
        "Timetable<#{@offering.course.code}/#{@offering.semester['id']}>"
      end
    end
    
  end
  
end
