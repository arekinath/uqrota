require 'treetop'

module Rota
  module MessageQuery
    Parser = Treetop.load(File.join(File.dirname(__FILE__), 'messagequery.treetop'))

    module Expression
      def compile
        "(lambda {|ce| " + first.compile + " " + elements[1].elements.map { |e| e.compile }.join(" ") + "})"
      end
    end

    module ExpressionPart
      def compile
        ophash = {"&&" => "and", "||" => "or"}
        ophash[op.text_value] + " " + second.compile
      end
    end

    module NestedExpression
      def compile
        "(" + ex.compile + ").call(ce)"
      end
    end

    module Condition
      def compile
        "(" + lhs.compile + " " + op.compile + " " + rhs.compile + ")"
      end
    end

    module DotPath
      def self.resolve(object, sym)
        if object.kind_of?(Hash)
          object[sym.to_s]
        else
          attre = (object.respond_to?(:attribute_get) ? object.attribute_get(sym) : nil)
          if attre
            attre
          else
            rels = (object.class.respond_to?(:relationships) ? object.class.relationships : [])
            if rels.select{|r| r.name.to_sym == sym}.size > 0
              object.send(sym)
            else
              wl = (object.class.respond_to?(:query_whitelist) ? object.class.query_whitelist : [])
              if wl.include?(sym)
                object.send(sym)
              else
                throw Exception.new("Access violation on method :#{sym}")
              end
            end
          end
        end
      end
    
      def parts(pts=[])
        nxt = (elements[1].respond_to?(:nxt) ? elements[1].nxt : nil)
        pts = pts + [base.text_value]
        if nxt and nxt.kind_of?(DotPath)
          nxt.parts(pts)
        else
          pts
        end
      end
    
      def compile(top=true, target="")
        nxt = (elements[1].respond_to?(:nxt) ? elements[1].nxt : nil)
        if nxt.kind_of?(DotPath)
          out = "("
          pts = nxt.parts
          st = "ce.targets[:#{base.text_value}]"
          pts.each do |pt|
            st = "MessageQuery::DotPath.resolve(#{st}, :#{pt})"
          end
          out += st
          out += ")"
        else
          out = "(ce.targets[:#{base.text_value}])"
        end
      end
    end
    
  end
end
