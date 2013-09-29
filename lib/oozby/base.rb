require 'pp'

# Oozby class loads up files and evaluates them to a syntax tree, and renders to openscad source code
class Oozby
  attr_accessor :filter_errors, :debug
  
  def initialize
    @code_tree = []
    @filter_errors = false
    @debug = false
  end
  
  # parse oozby code in to a syntax tree
  def parse code, filename: 'eval'
    env = Oozby::Environment.new(ooz: self)
    if File.exists? filename
      current_dir = Dir.pwd
      Dir.chdir File.dirname(filename)
    end
    
    # rescue block to filter out junk oozby library stuff from backtraces
    begin
      compiled = eval("lambda {; #{code}\n }", nil, filename)
      env._execute_oozby(&compiled)
    rescue StandardError, NoMethodError => err
      backtrace = $!.backtrace
      #backtrace = backtrace.select { |item| !item.include? __dir__ } unless backtrace.first.include? __dir__
      
      if @filter_errors # and backtrace.index { |i| i.include? ".oozby:" } < 3
        execute_oozby_idx = backtrace.index { |i| i.include? "in `_execute_oozby'" }
        backtrace = backtrace[0...execute_oozby_idx] if execute_oozby_idx
        backtrace.delete_if do |item|
          filename = item.split(':').first
          filename = File.realpath(filename)
          filename.start_with? __dir__
        end
      end
      
      raise $!, $!.message, backtrace
    end
    @code_tree = env._abstract_tree
    
  ensure
    Dir.chdir current_dir if current_dir
  end
  
  # parse a file containing oozby code in to a syntax tree
  def parse_file filename
    parse File.read(filename), filename: filename
  end
  
  # render the last parsed oozby code in to openscad source code
  def render
    renderer = Oozby::Render.new(ooz: self)
    renderer.render(@code_tree, clean: true).join("\n") + "\n"
  end
  
  def abstract_tree
    @code_tree
  end
end



