require 'pp'

# Oozby class loads up files and evaluates them to a syntax tree, and renders to openscad source code
class Oozby
  def initialize
    @code_tree = []
  end
  
  # parse oozby code in to a syntax tree
  def parse code, filename: 'eval'
    env = Oozby::Environment.new(ooz: self)
    
    # rescue block to filter out junk oozby library stuff from backtraces
    begin
      compiled = eval("lambda {; #{code}; }", nil, filename)
      env.instance_exec(&compiled)
    rescue
      warn "Recent Calls: " + env.instance_variable_get(:@method_history).last(10).reverse.inspect
      backtrace = $!.backtrace
      backtrace = backtrace.select { |item| !item.include? __dir__ } unless backtrace.first.include? __dir__
      raise $!, $!.message, backtrace
    end
    @code_tree = env._abstract_tree
  end
  
  # parse a file containing oozby code in to a syntax tree
  def parse_file filename
    parse File.read(filename), filename: filename
  end
  
  # render the last parsed oozby code in to openscad source code
  def render
    renderer = Oozby::Render.new(ooz: self)
    renderer.render(@code_tree, clean: true).join("\n")
  end
  
  def abstract_tree
    @code_tree
  end
end



