require 'config'
require 'rota/model'
require 'rota/fetcher'
require 'thread'

module Rota
  
  class TaskRunner
    def initialize(tasks, nth=Rota::Config['updater']['threads']['default'])
      @tasks = tasks
      @mutex = Mutex.new
      @nthreads = nth
      @total = tasks.size
      self.run
    end
    
    def run
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
      
      print "starting..."
      count = 1
      while count > 0
        sleep(1)
        @mutex.synchronize { count = @tasks.size }
        pc = "%.2f" % ((@total-count).to_f / @total.to_f * 100.0)
        print "\r#{@total-count}/#{@total} tasks taken (#{pc}\%)"
      end
      
      ths.each { |th| th.join }
    end
  end
  
  module UpdateTasks
    
    class ProgramTask
      def initialize(program)
        @program = program
        @f = Rota::Fetcher.new
      end
      
      def run
        begin
          agent,page = @f.get_pgm_course_list_page(@program)
          p = Rota::CourseListPageParser.new(@program, page)
          p.parse
        rescue Timeout::Error => err
          puts "> timeout, retrying..."
          sleep(1)
          retry
        rescue Exception => err
          puts "> error #{err.class.inspect} on #{@course.code}... retrying..."
          sleep(2)
          retry
        end
      end
    end
    
    class CourseTask
      def initialize(course)
        @course = course
        @f = Rota::Fetcher.new
      end
      
      def run
        begin
          agent,page = @f.get_course_detail_page(@course)
          p = Rota::CourseDetailPageParser.new(@course, page)
          p.parse
        rescue Timeout::Error => err
          puts "> timeout on #{@course.code}, retrying..."
          sleep(1)
          retry
        rescue Exception => err
          puts "> error #{err.class.inspect} on #{@course.code}... retrying..."
          sleep(2)
          retry
        end
      end
    end
    
    class ProfileTask
      def initialize(profile)
        @profile = profile
        @f = Rota::Fetcher.new
      end
      
      def run
        begin
          agent,page = @f.get_course_profile(@profile)
          p = Rota::CourseProfileParser.new(@profile, page)
          p.parse
        rescue Timeout::Error => err
          puts "> timeout, retrying..."
          sleep(1)
          retry
        rescue Exception => err
          puts "> error #{err.class.inspect} on #{@profile.course.code}... retrying..."
          sleep(2)
          retry
        end
      end
    end
    
  end
  
end
