module Utils
  class PlanSVGDSLHelper
    def initialize(renderer)
      @renderer = renderer
    end

    def plan(plan)
      if not plan.respond_to?(:uq_course_groups) or not plan.uq_course_groups.respond_to?(:uq_courses)
        raise Exception.new("Does not look like a valid plan object: #{plan.inspect}")
      end
      [:plan, plan]
    end
    def set(*operands)
      operands.each do |o|
        if o[0] == :plan
          @renderer.plan = o[1]
        end
      end
    end
    def svg; 'svg'; end
    def png; 'png'; end
    def output(fmt); @renderer.format =  fmt.to_s; end
    def highlight(*operands)
      operands.each do |o|
        if o[0] == :courses
          @renderer.highlighted_courses += o[1]
        end
      end
    end
    def courses(*courselist)
      cl = courselist.flatten.collect do |c| 
        if c.respond_to?(:code); c.code.to_s
        elsif c.respond_to?(:to_s); c.to_s
        else; raise Exception.new("Not a valid course identifier/object: #{c.inspect}")
        end
      end
      return [:courses, cl]
    end
  end

  class PlanSVGRenderer
    attr_accessor :plan, :format, :highlighted_courses

    def initialize(path_to_dot="/usr/bin/dot", &block)
      @path_to_dot = path_to_dot
      @format = 'svg'
      @highlighted_courses = []
      dslhelper = PlanSVGDSLHelper.new(self)
      dslhelper.instance_eval(&block)
      if not (@plan and @format)
        raise Exception.new("Plan SVG renderer not correctly configured, make sure you set the plan and format")
      end
    end

    def render
      # open dot
      dot = IO.popen("#{@path_to_dot} -T#{@format}", "r+")
      dot.puts "digraph G {"

      # basic graph configuration
      dot.puts "node [fontsize=8];"
      dot.puts "graph [fontsize=10, colorscheme=x11, outputMode=edgesfirst, remincross=true];"
      dot.puts "edge [color=gray40];"

      cs = @plan.uq_course_groups.uq_courses
      used_courses = Array.new

      # useful inner functions
      def level_of(coursecode)
        m = /[A-Za-z]{4}([0-9])[0-9]{3}/.match(coursecode)
        m[1]
      end

      # work out a list of course levels
      levels = {}
      cs.each do |course|
        level = level_of(course.code)
        levels[level] = Array.new unless levels[level]
        levels[level] << course.code
      end

      # now the groups
      extra_edges = []
      @plan.uq_course_groups.each do |course_group|
        courses = course_group.uq_courses.select { |c| not used_courses.include?(c.code) }
        # STDERR.puts "\n\n>>GROUP:"
        # STDERR.puts courses.collect { |c| c.code }.inspect
        if courses.size > 0

          dot.puts "subgraph cluster_#{course_group['id']} {"

          label = course_group.text.gsub(/[^a-zA-Z0-9\:\.\#\/]/,' ')

          # STDERR.puts "in cluster #{label.slice(0,30)}"
          dot.puts "label = \"#{label.slice(0,30)}\";"
          dot.puts "graph [color=gray60, fontcolor=gray50];"

          found_with_prereqs = false
          courses.each do |course|
            lbl = "#{course.code}\\n#{course.semesters_offered}"
            dot.puts "#{course.code} [label=\"#{lbl}\", color=gray50, fontcolor=gray50];"
            used_courses << course.code
            if not found_with_prereqs
              vpr = course.prereqs.select { |pr| cs.include?(pr.prereq) and cs.include?(pr.dependent) }
              vpr = vpr.select { |pr| 
                (courses.include?(pr.prereq) and not courses.include?(pr.dependent)) or
                (courses.include?(pr.dependent) and not courses.include?(pr.prereq)) }
              if vpr.size > 0
                found_with_prereqs = true
                # STDERR.puts vpr.inspect
              end
            end
          end

          if not found_with_prereqs
            group_levels = courses.collect { |c| level_of(c.code).to_i }
            # STDERR.puts group_levels.inspect
            lev = group_levels.inject(0) { |acc,el| if el > acc; el; else; acc; end }
            # STDERR.puts "max level = #{lev}"
            if lev > 1
              target_level = lev - 1
              # STDERR.puts "target level = #{target_level}"
              outer_code = levels[target_level.to_s][lev]
              inner_code = courses.first.code

              # STDERR.puts "DOING HACK: #{outer_code} -> #{inner_code}"
              extra_edges << "#{outer_code} -> #{inner_code} [style=invis];"
            end
          end
          dot.puts "}"
        end
      end
      
      dot.puts extra_edges.join("\n")

      # and course prereqs
      cs.each do |course|
        course.prereqs.each do |pr|
          if cs.include?(pr.prereq) and cs.include?(pr.dependent)
            dot.puts "#{pr.prereq.code} -> #{pr.dependent.code};"
          end
        end
      end

      # finally, highlights
      @highlighted_courses.each do |code|
        dot.puts "#{code} [style=filled, fillcolor=darkseagreen2, color=black, fontcolor=black];"
      end

      dot.puts "}"
      dot.close_write

      dot.read
    end
  end
end