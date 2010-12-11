require 'yaml'

module Rota
  LibDir = File.dirname(File.expand_path(__FILE__))
  RootDir = File.dirname(LibDir)
  PublicDir = File.expand_path("public", RootDir)
  ViewsDir = File.expand_path("views", RootDir)
  
  Config = YAML.load_file(File.expand_path("config.yml", RootDir))
end

$LOAD_PATH << Rota::LibDir
