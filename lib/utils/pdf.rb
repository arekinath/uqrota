require 'rubygems'
require 'prawn/core'
require 'prawn/layout'

module Utils
  
  class PDFTimetableRenderer
    require 'prawn/measurement_extensions'
    
    Days = %w{Sun Mon Tue Wed Thu Fri Sat}
    BaseHour = 7
    
    def grid
      @pdf.bounding_box [0, @pdf.bounds.height - 20.mm], :width => (@pdf.bounds.width - 20.mm), :height => (@pdf.bounds.height - 30.mm) do
        @pdf.define_grid(:columns => 7.5, :rows => 12.5, :gutter => 0)
        yield
      end
    end
    
    attr_reader :pdf
    
    def initialize(title="New timetable")
      @groups = Array.new
      
      @pdf = Prawn::Document.new(:page_size => 'A4', :page_layout => :landscape)
      @pdf.bounding_box [10.mm, @pdf.bounds.height-5.mm], :width => @pdf.bounds.width, :height => 20.mm do
        @pdf.font_size = 12.mm
        @pdf.text title
      end
      @pdf.font_size = 12.pt
      grid do
       (0..12).each do |y|
          y += 0.4
          b = @pdf.grid(y,0)
          @pdf.bounding_box b.top_left, :width => b.width*0.4, :height => b.height do
            hour = (BaseHour + y-0.4).round
            hour -= 12 if hour > 12
            @pdf.text hour.to_s, :align => :right
          end
        end
        
         (1..7).each do |x|
          x -= 0.5
          
          b = @pdf.grid(0.0,x)
          @pdf.bounding_box b.top_left, :width => b.width, :height => b.height do
            @pdf.text Days[(x-0.5).to_i], :align => :center
          end
          
          @pdf.stroke_color 0,0,0,50
           (1..12).each do |y|
            y -= 0.5
            b = @pdf.grid(y,x)
            @pdf.stroke_rectangle(b.top_left, b.width, b.height)
          end
        end
      end
    end
    
    def <<(group)
      @groups << group
    end
    
    class RenderableSession
      attr_reader :x_offset, :x_scale, :session, :x_invert_scale
      attr_reader :day_number, :grid_start, :grid_height
      attr_reader :top_left, :bottom_right
      
      def initialize(rgroup, session)
        @rgroup = rgroup
        @session = session
        @day_number = Days.index(session.day)
        @grid_start = (session.start / 60.0) - 7.0
        @grid_height = (session.finish - session.start)/60.0
        
        @x_offset = 0.0
        @x_invert_scale = 1.0
        @x_scale = 1.0/@x_invert_scale
        
        recalculate_corners
      end
      
      def x_offset=(nv)
        @x_offset = nv
        recalculate_corners
      end
      
      def x_invert_scale=(nv)
        @x_invert_scale = nv
        self.x_scale=(1.0/nv)
      end
      
      def x_scale=(nv)
        @x_scale = nv
        recalculate_corners
      end
      
      def recalculate_corners
        @top_left = [@day_number+@x_offset, @grid_start]
        @bottom_right = [top_left[0]+@x_scale, top_left[1]+@grid_height]
      end
      
      def at_y?(y)
        @grid_start <= y and (@grid_start+@grid_height) >= y
      end
      
      def clashes_with?(other)
        @day_number == other.day_number and (
         (@grid_start >= other.grid_start and @grid_start <= other.grid_start + other.grid_height) or 
         ((@grid_start+@grid_height) >= other.grid_start and (@grid_start+@grid_height) <= (other.grid_start+other.grid_height))
        )
      end
      
      def include?(point)
        @top_left[0] < point[0] and @bottom_right[0] > point[0] and @top_left[1] < point[1] and @bottom_right[1] > point[1]
      end
      
      def render(r)
        p = r.pdf
        r.grid do
          b = p.grid(@grid_start+0.5,@day_number+0.5+@x_offset)
          p.stroke_color 0,0,0,100
          p.fill_color *@rgroup.group_colour
          p.fill_and_stroke_rounded_rectangle(b.top_left, b.width*@x_scale, b.height*@grid_height, 10)
          
          p.bounding_box b.top_left, :width => b.width*@x_scale, :height => b.height*@grid_height do
            p.bounding_box [p.bounds.left + 2.mm, p.bounds.top-2.mm],
			      :width => p.bounds.width - 4.mm, :height => p.bounds.height - 2.mm do
              p.fill_color *@rgroup.text_colour
              p.font_size = 10.pt
              text = @rgroup.group.fancy_name + "\n" + @session.room
              p.text_box text, :align => :center, :overflow => :truncate
            end
          end
        end
      end
    end
    
    class RenderableGroup
      attr_reader :group_colour, :text_colour, :group, :rsessions
      
      def initialize(group)
        @rsessions = Array.new
        @group = group
        
        @group.sessions.each do |s|
          @rsessions << RenderableSession.new(self, s)
        end
        
        @group_colour = [Kernel.rand*100, Kernel.rand*100, Kernel.rand*100, 0]
        @text_colour = [0,0,0,100]
        avg = @group_colour.inject(0) { |i,j| i+j } / 3.0
        @text_colour = [0,0,0,0] if avg > 50.0
      end
      
      def render(r)
        @rsessions.each { |rs| rs.render(r) }
      end
      
      def each
        @rsessions.each { |rs| yield rs }
      end
    end
    
    class ClashCollection
      def initialize
        @rsessions = Array.new
      end
      
      def render(r)
        @rsessions.each { |rs| rs.render(r) }
      end
      
      def <<(rs)
        clashes = @rsessions.select { |r| r.clashes_with?(rs) }
        
        if clashes.size > 0
          clashes = (clashes + [rs]).sort_by { |r| r.grid_start }
          
          column_alloc = Hash.new
          
          divider = clashes.size
          clashes.each { |r| divider = r.x_invert_scale if r.x_invert_scale > divider }
          
          clashes.each do |r|
            if r.x_invert_scale < divider
              r.x_invert_scale = divider
              divider.times do |i|
                if column_alloc[i].nil?
                  column_alloc[i] = r
                  break
                end
              end
            else
              idx = (r.x_offset/r.x_scale).to_i
              if column_alloc[idx].nil?
                column_alloc[idx] = r
              else
                old = column_alloc[idx]
                divider.times do |i|
                  if column_alloc[i].nil?
                    column_alloc[i] = old
                    break
                  end
                end
                column_alloc[idx] = r
              end
            end
          end
          
          divider.times do |i|
            if column_alloc[i].nil?
             (i..0).each do |j|
                column_alloc[i] = column_alloc[j] if not column_alloc[j].nil?
              end
            end
          end
          
          divider.times do |i|
            unless column_alloc[i+1] == column_alloc[i]
              r = column_alloc[i]
              
              block_count = 0.0
              if i > 0
               (i-1..0).each { |j| block_count+=1.0 if column_alloc[j] == r }
              end
              
              r.x_offset = (i-block_count)*r.x_scale
              r.x_scale = r.x_scale*(block_count+1.0)
            end
          end
          
        end
        @rsessions << rs
      end
    end
    
    
    def render_groups
      cc = ClashCollection.new
      @groups.each do |group|
        r =  RenderableGroup.new(group)
        r.each do |s|
          cc << s
        end
      end
      cc.render(self)
    end
    
    def render
      render_groups
      @pdf.render
    end
  end
  
end
