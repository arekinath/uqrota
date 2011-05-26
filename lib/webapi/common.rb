require 'json'

class FindConditions < Hash
  def initialize(src)
    srh = JSON.parse(src)
    srh.each do |k,v|
      parts = k.split(".")
      sym = parts[0].to_sym
      kk = sym
      kk = kk.send(parts[1].to_sym) if parts[1]
      self[kk] = v
    end
  end
end