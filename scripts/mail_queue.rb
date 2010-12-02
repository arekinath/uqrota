#!/usr/bin/ruby

$LOAD_PATH << File.expand_path("../../lib", __FILE__)
require 'config'
require 'rota/model'
require 'rota/fetcher'
require 'rota/queues_alerts'

puts "[#{Time.now.strftime('%Y-%m-%d %H:%M')}] Starting mail queue sender..."

puts "  > Sending emails.."
qes = Rota::Model::QueuedEmail.all
qes.size.times do |i|
  qem = qes[i]
  puts "[%2i/%2i] to #{qem.recipient}.." % [i, qes.size]
  begin
    qem.send
  rescue Interrupt => err
    puts " !! interrupt! ... !! "
    raise err
  rescue Exception => err
    puts " !! exception: #{err.inspect}: #{err.backtrace.join("\n\t\t")}"
  end
end

puts "  > Sending sms..."
qsmses = Rota::Model::QueuedSMS.all
qsmses.size.times do |i|
  qsms = qsmses[i]
  puts "[%2i/%2i] to #{qsms.recipient}..." % [i, qsmses.size]
  begin
    qsms.send
  rescue Interrupt => err
    puts " !! interrupt! ... !! "
    raise err
  rescue Exception => err
    puts " !! exception: #{err.inspect}: #{err.backtrace.join("\n\t\t")}"
  end
end

puts "[#{Time.now.strftime('%Y-%m-%d %H:%M')}] Mail queue done"
