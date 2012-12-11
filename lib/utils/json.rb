require 'rubygems'
require 'json'
require 'json/add/core'
require 'config'
require 'utils/xml'

class Array
  def to_rota_json(level=1, parent=true, from=nil, *k)
    self.collect { |kk| JSON::Serializable::ToJsonProxy.new(kk, level, parent, from) }.to_json(*k)
  end
end

class DateTime
  def to_json(*k)
    return self.iso8601.to_json(*k)
  end
end

module JSON
  module Serializable
    class ToJsonProxy
      def initialize(target, level, parent=false, from=nil)
        @target = target
        @level = level
        @parent = parent
        @from = from
      end

      def to_json(*k)
        @target.to_json(@level, @parent, @from, *k)
      end
    end

    def self.included(klass)
      klass.extend(ClassMethods)
      klass.instance_variable_set(:@json_keys, Array.new)
      klass.instance_variable_set(:@json_attrs, Array.new)
      klass.instance_variable_set(:@json_parents, Array.new)
      klass.instance_variable_set(:@json_children, Array.new)
    end

    # JSON levels:  0 - just the object's key attribute
    #               1 - all of object's attributes and children
    #               2 - all of object + 2 levels of children etc

    def to_json(level=1, parent=true, from=nil, *k)
      return nil if level < 0

      hash = Hash.new
      hash[:_class] = self.class.name.split("::").last

      msgs = self.class.instance_variable_get(:@json_keys).flatten
      msgs << :id if msgs.size == 0
      hash[:_keys] = msgs.collect { |m| m.to_s }
      if level >= 1
        msgs += self.class.instance_variable_get(:@json_attrs).flatten
      end

      msgs = msgs.collect do |m|
        if m.is_a?(Hash)
          m.each do |k,v|
            hash[k] = self.send(v)
            if hash[k].kind_of?(Serializable)
              hash[k] = ToJsonProxy.new(hash[k], 0, false, self)
            end
          end
        else
          hash[m] = self.send(m)
          if hash[m].respond_to?(:collect)
            hash[m] = hash[m].collect do |c|
              if c.kind_of?(Serializable)
                ToJsonProxy.new(c, 0, false, self)
              else
                c
              end
            end
          elsif hash[m].kind_of?(Serializable)
            hash[m] = ToJsonProxy.new(hash[m], 0, false, self)
          end
        end
      end

      if level >= 1
        chl = self.class.instance_variable_get(:@json_children).flatten
        chl.each do |m|
          hash[m] = self.send(m).collect { |c| ToJsonProxy.new(c, level-1, false, self) }
        end
      end

      if parent
        pnts = self.class.instance_variable_get(:@json_parents).flatten
        pnts.each do |m|
          t = self.send(m)
          t = [t] unless t.respond_to?(:collect)
          hash[m] = t.collect { |c| ToJsonProxy.new(c, 0, false, self) }
          hash[m] = hash[m].first if hash[m].size == 1
        end
      elsif from and level >= 1
        pnts = self.class.instance_variable_get(:@json_parents).flatten
        pnts.each do |m|
          t = self.send(m)
          next if t == from or (t.respond_to?(:include?) and t.include?(from))
          t = [t] unless t.respond_to?(:collect)
          hash[m] = t.collect { |c| ToJsonProxy.new(c, level-1, false, self) }
          hash[m] = hash[m].first if hash[m].size == 1
        end
      end

      return JSON.pretty_generate(hash, *k)
    end

    module ClassMethods
      def json(hash)
        hash.each do |k,v|
          if [:key, :keys].include?(k)
            @json_keys << v
          elsif [:attrs].include?(k)
            @json_attrs << v
          elsif [:children].include?(k)
            @json_children << v
          elsif [:parent, :parents].include?(k)
            @json_parents << v
          end
        end
      end

      def json_keys(*k)
        @json_keys << k
      end

      alias :json_key :json_keys

      def json_attrs(*k)
        @json_attrs << k
      end

      def json_children(*k)
        @json_children << k
      end

      def json_parents(*k)
        @json_parents << k
      end

      alias :json_parent :json_parents
    end
  end
end

