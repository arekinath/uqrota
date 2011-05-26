require 'json'

class FindConditions
  def initialize(klass, src)
    @klass = klass
    
    srh = JSON.parse(src)
    @resultset = do_query_level(srh)
  end
  
  def do_query_level(hash)
    child = nil
    conds = {}
    hash.each do |k,v|
      if k == 'or'
        child = v
      else
        kv_pair(conds, k, v)
      end
    end
    
    if child
      return @klass.all(conds) + do_query_level(child)
    else
      return @klass.all(conds)
    end
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
  
  def to_json
    @resultset.to_a.to_rota_json(0)
  end
  
  def results
    @resultset
  end
end