require 'librota/model'

module Rota
  module Model
    
    class Session
      def clashes_with?(other)
	self.events.each do |evt|
	  return true if Event.all(:session => other, :start => (evt.start-1..evt.finish+1)).size > 0
	  return true if Event.all(:session => other, :finish => (evt.start-1..evt.finish+1)).size > 0
	end
	false
      end
    end
    
    class Group
      def clash_count(other)
	count = 0
	self.sessions.each do |x|
	  other.sessions.each do |y|
	    count += 1 if x.clashes_with?(y)
	  end
	end
	count
      end
    end
    
  end
end
