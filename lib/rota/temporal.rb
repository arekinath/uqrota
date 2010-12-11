require 'rota/model'

module Rota
  
  class TimetableSession
    def clashes_with?(other)
      self.events.each do |evt|
        return true if TimetableEvent.all(:timetable_session => other, 
                          :start => (evt.start-1..evt.finish+1)).size > 0
        return true if TimetableEvent.all(:timetable_session => other, 
                          :finish => (evt.start-1..evt.finish+1)).size > 0
      end
      false
    end
  end
  
  class TimetableGroup
    def clash_count(other)
      count = 0
      self.sessions.each do |x|
        other.sessions.each do |y|
          count += 1 if x.clashes_with?(y)
        end
      end
      count
    end
    
    def clash_frac(other)
      clash_count(other).to_f / self.sessions.size.to_f
    end
  end
  
  class Clash
    attr_reader :objects
    attr_reader :type
    
    def initialize(o1, o2, type, desc)
      @objects = [o1, o2]
      @type = type
      @desc = desc
    end
    
    def description; @desc; end
  end
  
  class ClashSummary
    attr_reader :offerings
    attr_reader :clashes
    
    def initialize(*offerings)
      @clashes = []
      @offerings = offerings
      @o1, @o2 = offerings
      
      @o1.compulsories.each do |g1|
        @o2.compulsories.each do |g2|
          if g1 != g2 and g1.clash_count(g2) > 1
            @clashes << Clash.new(g1, g2, :group,
              "More than 1 compulsory session clashes")
          end
        end
      end
      
      total = 0.0
      count = 0.0
      @o1.selectables.each do |g1|
        @o2.selectables.each do |g2|
          if g1 != g2
            total += g1.clash_frac(g2)
            count += 1.0
          end
        end
      end
      if (total / count) > 0.9
        @clashes << Clash.new(@o1, @o2, :offering,
          "More than 90% of non-compulsory sessions clash")
      end
    end
    
    def clashes?
      @clashes.size > 0
    end
  end
  
  class Offering
    def compulsories
      self.series.select { |s| s.groups.size == 1 }.collect { |s| s.groups }.flatten
    end
    
    def selectables
      self.series.reject { |s| s.groups.size == 1 }.collect { |s| s.groups }.flatten
    end
  end
  
end
