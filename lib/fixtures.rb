require 'yaml'
require 'dm-core'

class FixtureSet
  attr_reader :objects
  
  def initialize(fname)
    @data = YAML.load_file(fname)
    @objects = Hash.new
    
    # first pass, define the objects
    @data.each do |o_name, o_entry|
      klass = eval(o_entry['class'])
      obj = klass.new
      @objects[o_name] = obj
    end
    
    # second, set properties
    @data.each do |o_name, o_entry|
      obj = @objects[o_name]
      
      o_entry.to_a.select { |k,v| k != 'class' }.each do |k, v|
        if v =~ /^@[^@]/
          v = @objects[v.slice(1,v.size).strip]
        elsif v =~ /^#[^#]/
          v = v.slice(1,v.size).strip.to_i
        elsif v =~ /^=[^=]/
          v = eval(v.slice(1,v.size).strip)
        end
        v = v.slice(1,v.size) if v.is_a?(String) and v[0] == v[1] and '=#@'.include?(v[0])
        obj.send(k + '=', v)
      end
      
      code = lambda { @objects[o_name] }
      self.class.send(:define_method, o_name, code)
    end
  end
  
  def save
    @objects.each do |name, obj|
      if obj.kind_of?(DataMapper::Resource)
        obj.save
      end
    end
  end
  
  def destroy!
    @objects.each do |name, obj|
      if obj.kind_of?(DataMapper::Resource)
        obj.destroy!
      end
    end
  end
end
