require 'yaml'

module Rota
  LibDir = File.dirname(File.expand_path(__FILE__))
  RootDir = File.dirname(LibDir)
  
  Config = YAML.load_file("#{RootDir}/config.yml")
end

$LOAD_PATH << Rota::LibDir
