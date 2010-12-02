#!/usr/bin/ruby

$LOAD_PATH << "/srv/rota"
require 'librota/model'

to_expire = Rota::Model::APISession.all.select { |k| k.expired? }
if to_expire.size > 0
  puts "[#{Time.now.strftime('%Y-%m-%d %H:%M')}] Expired #{to_expire.size} idle sessions"
end
to_expire.each { |s| s.destroy! }
