Gem::Specification.new do |s|
  s.name = 'oozby'
  s.version = '0.2.2'
  s.summary = "A markup language for OpenSCAD"
  s.author = 'Bluebie'
  s.email = "a@creativepony.com"
  s.homepage = "http://github.com/Bluebie/digiusb.rb"
  s.description = "OpenSCAD - a cad language for creating solid 3d objects, useful for CNC and 3D Printing, is incredibly annoying. It doesn't even support variables! Oozby is a markup builder like Markaby or XML Builder, so you can write OpenSCAD programs in Ruby. It also patches in a bunch of really nice features which make programming objects much more fun. Check out the Readme and examples folder for some demos of what this tool can do!"
  s.files = Dir['lib/**/*.rb'] + ['readme.md', 'license.txt'] + Dir['examples/**/*.rb'] + Dir['bin/**/*.rb']
  s.license = 'LGPL-3'
  s.executables << 'oozby'
  s.required_ruby_version = '>= 2.0.0'
  
  s.rdoc_options << '--main' << 'lib/oozby/base.rb'
  
  s.add_dependency 'listen', '>= 1.3.0' # monitor filesystem for changes - used by cli app to automatically rebuild on changes
  s.add_dependency 'thor', '>= 0.18.1' # cli stuff for command line app
  #s.add_dependency 'colorist', '>= 0.0.2' # parses html style colours. Maybe should add this to 'color' function?
  #s.add_dependency 'colored', '>= 1.2' # colorize terminal output. Maybe use this to make oozby cli program more fabulous?
end