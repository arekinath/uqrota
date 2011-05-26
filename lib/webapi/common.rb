require 'json'

class FindConditions < Hash
  def initialize(src)
    srh = JSON.parse(src)
    srh.each do |k,v|
      parts = k.split(".")
      sym = parts[0].to_sym
      kk = sym
      parts.slice(1,parts.size).each do |p| 
        kk = kk.send(p.to_sym)
      end
      self[kk] = v
    end
  end
end