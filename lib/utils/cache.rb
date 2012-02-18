require 'config'
require 'memcache'
require 'digest/md5'

module Sinatra
  class Cache
    def self.cache(key, &block)
      unless Rota::Config['memcached']
        raise "Configure CONFIG['memcached'] to be a string like 'localhost:11211' "
      end
      begin
        key = Digest::MD5.hexdigest(key)
        @@connection ||= MemCache.new(Rota::Config['memcached']['host'], :namespace => 'Sinatra/')
        result = @@connection.get(key)
        return result if result
        result = yield
        @@connection.set(key, result)
        result
      rescue
        yield
      end
    end
  end
end

