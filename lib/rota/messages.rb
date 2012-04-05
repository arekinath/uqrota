
module Rota
  class Message
    @@all = Hash.new
    attr_reader :uuid
    attr_reader :short
    attr_reader :full
    attr_reader :params
    
    def initialize(uuid, short, full, params)
      @uuid = uuid
      @short = short
      @full = full
      @params = params
      @@all[@uuid] = self
    end
    
    def is_valid?(obj)
      @params.each do |p|
        if obj[p].nil?
          return false
        end
      end
      true
    end
    
    def self.find(uuid)
      @@all[uuid]
    end
    
    def self.all
      @@all.values
    end
    
    def to_json(*a)
      {:uuid => @uuid, 
       :name => @short, 
       :description => @full, 
       :parameters => @params.collect { |p| p.to_s }
      }.to_json(*a)
    end
    
    def ==(other)
      self.uuid == other.uuid
    end
  end
end
