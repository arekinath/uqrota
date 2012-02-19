require 'json'

class FindConditions
  def initialize(klass, src)
    @klass = klass
    
    srh = JSON.parse(src)
    @resultset = do_query_level(srh)
  end
  
  def do_query_level(hash)
    or_child = nil
    and_child = nil
    and_first = true
    conds = {}
    hash.each do |k,v|
      if k == 'or'
        or_child = v
      elsif k == 'and' or k == 'andor'
        and_child = v
      elsif k == 'orand'
        and_child = v
        and_first = false
      else
        kv_pair(conds, k, v)
      end
    end
    
    results = @klass.all(conds)
    if and_child and and_first
      results = results & do_query_level(and_child)
    end
    if or_child
      results = results + do_query_level(or_child)
    end
    if and_child and not and_first
      results = results & do_query_level(and_child)
    end
    
    return results
  end
  
  def kv_pair(hash, k, v)
    parts = k.split(".")
    sym = parts[0].to_sym
    kk = sym
    parts.slice(1,parts.size).each do |p| 
      kk = kk.send(p.to_sym)
    end
    hash[kk] = v
  end
 
  def to_a
    @resultset.to_a
  end

  def to_json
    @resultset.to_a.to_rota_json(0)
  end
  
  def results
    @resultset
  end
end
