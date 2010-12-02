$LOAD_PATH << "/srv/rota"
require 'librota/model'
include Rota::Model

puts "#{Time.now} -- starting orphan check"

puts "#{Time.now} -- orphans: check series"
ss = Series.all
ss.size.times do |i|
  ser = ss[i]
  if ser.course.nil?
    puts "#{Time.now} -- >> unlinking series #{ser['id']}"
    ser.groups.each do |g|
      g.sessions.each do |s|
        s.events.each do |e|
          e.destroy!
        end
        s.destroy!
      end
      g.destroy!
    end
    ser.destroy!
  end
end

puts "#{Time.now} -- orphans: check groups"
gs = Group.all
gs.size.times do |i|
  g = gs[i]
  if g.series.nil?
    puts "#{Time.now} -- >> unlinking group #{g['id']}"
    g.sessions.each do |s|
      s.events.each do |e|
        e.destroy!
      end
      s.destroy!
    end
    g.destroy!
  end
end

puts "#{Time.now} -- orphans: check sessions"

ss = Session.all
ss.size.times do |i|
  s = ss[i]

  if s.group.nil?
    puts "#{Time.now} -- >> unlinking session #{s['id']}"
    s.events.each do |e|
      e.destroy!
    end
    s.destroy!
  end
end

puts "#{Time.now} -- orphans: check events"
evs = Event.all
evs.size.times do |i|
  ev = evs[i]

  if ev.session.nil?
    puts "#{Time.now} -- >> unlinking event #{ev['id']}"
    ev.destroy!
  end
end

puts "#{Time.now} -- ophans check complete"
