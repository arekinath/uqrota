require "rubygems"
require "bundler"
Bundler.setup(:unittest)

desc "Run unit tests"
task :test do
  tfs = Dir.glob("tests/*.rb").join(" ")
  puts `bacon #{tfs}`
end
