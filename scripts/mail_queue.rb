#!/usr/bin/ruby

require File.expand_path("../../lib/config", __FILE__)
require 'rota/model'
require 'rota/fetcher'
require 'rota/queues_alerts'

Rota.setup_and_finalize

puts "[#{Time.now.strftime('%Y-%m-%d %H:%M')}] Starting mail queue sender..."

puts "  > Sending emails.."
qes = Rota::QueuedEmail.all
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
qsmses = Rota::QueuedSMS.all
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
