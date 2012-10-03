require 'config'
require 'rota/model'
require 'rota/queues_alerts'
require 'rota/fetcher'
require 'io/wait'
require 'thread'

module Rota

  class TaskWorker
    def initialize
      @parent_read, @child_write = IO.pipe
      @child_read, @parent_write = IO.pipe
    end

    def read_pipe; @parent_read; end
    def write_pipe; @parent_write; end
    def ready?; @parent_read.ready?; end
    def _ready?; @child_read.ready?; end
    def send(msg); Marshal.dump(msg, @parent_write); end
    def recv; Marshal.load(@parent_read); end
    def _send(msg); Marshal.dump(msg, @child_write); end
    def _recv; Marshal.load(@child_read); end

    def run
      sleep 0.5
      @pid = fork {

        # we have to re-do the connection in the child otherwise fork will screw things up
        Rota.setup_and_finalize

        loop do
          resp = nil
          while resp.nil?
            _send([:next_job])
            resp = IO.select([@child_read], [], [], 5)
          end

          job = _recv()
          if job[0] == :job
            task = job[1]
            begin
              task.run
            rescue Exception => err
              puts err.inspect
              puts err.backtrace.join("\n")
              exit(1)
              #Thread.exit()
            end
          elsif job[0] == :done
            exit(0)
            #Thread.exit()
          end
        end
        exit(0)
        #Thread.exit()
      }
    end

    def wait
      Process.waitpid(@pid, 0)
      #@pid.join
    end
  end

  class TaskRunner
    def initialize(tasks, workers)
      @tasks = tasks
      @workers = workers
    end

    def run(desc, terminal=false)
      puts "[#{Time.now.strftime('%Y-%m-%d %H:%M')}] Beginning #{desc}..."

      idx = 0
      last_pc = Time.now
      last_idx = 0
      rdpipes = []
      @workers.each { |w| rdpipes << w.read_pipe }
      while idx < @tasks.size
        rios, wios = IO.select(Array.new(rdpipes), [])

        rios.each do |io|
          i = rdpipes.index(io)
          w = @workers[i]
          req = nil
          req = w.recv while w.ready?
          if req[0] == :next_job and idx < @tasks.size
            resp = [:job, @tasks[idx]]
            w.send(resp)
            idx += 1
          end
        end

        pcdone = 100.0 * (idx.to_f / @tasks.size.to_f)
        t = Time.now
        if terminal and (t - last_pc > 5.0)
          rate = (idx - last_idx).to_f / (t - last_pc).to_f
          print ("[#{Time.now.strftime('%Y-%m-%d %H:%M')}] dispensed %d/%d jobs (%.02f%%) @%.2f/sec   \r" % [idx+1, @tasks.size, pcdone, rate])
          last_pc = Time.now
          last_idx = idx
        end
      end

      print "\n" if terminal
      puts "[#{Time.now.strftime('%Y-%m-%d %H:%M')}] #{desc} completed."
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
          if errcount < 3
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

    class CampusListTask < SafeRunTask
      def safe_run
        agent, page = Campus.fetch_list
        Campus.parse_list(page)
      end

      def to_s
        "CampusList"
      end
    end

    class SemesterTask < SafeRunTask
      def initialize(sem)
        @semester_id = sem.id
      end

      def safe_run
        semester = Semester.get(@semester_id)
        agent, page = semester.fetch_dates
        semester.parse_dates(page)
      end

      def to_s
        "SemesterTask<#{@semester_id}>"
      end
    end

    class BuildingListTask < SafeRunTask
      def safe_run
        [[1, 'STLUC'], [3, 'IPSWC'], [2, 'GATTN']].each do |n,camp|
          campus = Campus.get(camp)
          agent, page = Building.fetch_list(n)
          Building.parse_list(page, campus)
        end
      end

      def to_s
        "BuildingList"
      end
    end

    class CourseListTask < SafeRunTask
      def safe_run
        agent, page = Course.fetch_list
        Course.parse_list(page)
      end

      def to_s
        "CourseList"
      end
    end

    class ProgramTask < SafeRunTask
      def initialize(program)
        @program_id = program.id
      end

      def safe_run
        program = Program.get(@program_id)
        agent, page = program.fetch_courses
        program.parse_courses(page)
      end

      def to_s
        "Program<#{Program.get(@program_id).name}>"
      end
    end

    class CourseTask < SafeRunTask
      def initialize(course)
        @course_code = course.code
      end

      def safe_run
        course = Course.get(@course_code)
        agent, page = course.fetch_details
        course.parse_details(page)
        course.parse_offerings(page)
      end

      def to_s
        "Course<#{@course_code}>"
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
        @offering_id = offering.id
      end

      def safe_run
        offering = Offering.get(@offering_id)
        agent, page = offering.fetch_timetable
        offering.parse_timetable(page)
      end

      def to_s
        offering = Offering.get(@offering_id)
        "Timetable<#{offering.course.code}/#{offering.semester['id']}>"
      end
    end

  end

end
