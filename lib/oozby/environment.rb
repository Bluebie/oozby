require 'amatch' # used to find possible intended method names

class Oozby::Environment
  ResolutionDefaults = {
    degrees_per_fragment: 12,
    fragments_per_turn: 30,
    minimum: 2,
    fragments: 0
  }
  
  class << self
    attr_accessor :active
  end
  
  def initialize(ooz: nil)
    @parent = ooz
    @ast = []
    @defaults = {center: false}
    @resolution = ResolutionDefaults.dup
    @modifier = nil
    @one_time_modifier = nil
    @preprocess = true
    @method_preprocessor = Oozby::Preprocessor.new(env: self, ooz: @parent)
    @scanned_scad_files = []
  end
  
  # create a new scope that inherits from this one, and capture syntax tree created
  def _subscope *args, &proc
    # capture instance variables
    capture = {}
    instance_variables.each { |key| capture[key] = self.instance_variable_get(key) }
    
    # reset for ast capture
    @ast = []
    @one_time_modifier = nil
    @defaults = @defaults.dup
    @resolution = @resolution.dup
    proc[*args]
    syntax_tree = @ast
    
    # restore instance variables
    capture.each { |key, value| self.instance_variable_set(key, value) }
    
    return syntax_tree
  end
  
  def inject_abstract_tree code
    code = [code] unless code.is_a? Array
    @ast.push(*code)
  end
  
  # do we know of this method
  def oozby_method_defined? name
    @method_preprocessor.known?(name.to_sym) or !@preprocess or respond_to?(name)
  end
  
  def method_missing method_name, *args, **hash, &proc
    # unless we know of this method in OpenSCAD or the preprocessor, abort!
    unless oozby_method_defined? method_name
      # grab a list of all known methods, suggest a guess to user
      known = @method_preprocessor.known
      known.push(*public_methods(false))
      known.delete_if { |x| x.to_s.start_with? '_' }
      matcher = Amatch::Sellers.new(method_name.to_s)
      suggestion = known.min_by { |item| matcher.match(item.to_s) }
      
      warn "Called unknown method #{method_name}()"
      warn "Perhaps you meant #{suggestion}()?" if suggestion
      
      return super # continue to raise the usual error and all that
    end
    
    oozby_send_method method_name, *args, **hash, &proc
  end
  
  def oozby_send_method method_name, *args, **hash, &proc
    if proc
      children = _subscope(&proc)
    else
      children = []
    end
    
    element = Oozby::Element.new({
      method: method_name,
      args: args, named_args: hash,
      children: children, 
      modifier: @one_time_modifier || @modifier,
      call_address: @ast.length
    })
    
    @ast.push(comment: "oozby: #{element}") if @parent.debug
    element = @method_preprocessor.transform_call(element) if @preprocess
    element.abduct @ast
    @one_time_modifier = nil
    
    return element
  end
  
  #### Trigonometric Functions using degrees instead of radians
  # add local definitions of trig functions
  [:cos, :sin, :tan].each do |math_function|
    define_method math_function do |deg|
      Math.send(math_function, (deg.to_f / 180.0) * Math::PI)
    end
  end
  
  # add inverse trig functions
  [:acos, :asin, :atan, :atan2].each do |math_function|
    define_method math_function do |*args|
      (Math.send(math_function, *args) / Math::PI) * 180.0
    end
  end
  
  def preprocessor state, &proc
    previous = @transform
    @preprocess = state
    instance_eval &proc
    @preprocess = previous
  end
  
  def defaults settings = nil, &proc
    return @defaults if settings == nil
    previous = @defaults
    @defaults = @defaults.merge(settings)
    if proc
      ret = instance_eval &proc
      @defaults = previous
    end
    ret
  end
  
  # implement the openscad lookup function
  # Look up value in table, and linearly interpolate if there's no exact match.
  # The first argument is the value to look up. The second is the lookup table
  # -- a vector of key-value pairs.
  # table can be an array of key/value subarray pairs, or a hash with numeric keys
  def lookup key, table
    table = table.to_a if table.is_a? Hash
    table.sort! { |x,y| x[0] <=> y[0] }
    b = table.bsearch { |x| x[0] >= key } || table.last
    index_b = table.index(b)
    a = if index_b > 0 then table[index_b - 1] else b end
    
    return a[1] if key <= a[0]
    return b[1] if key >= b[0]
    
    key_difference = b[0] - a[0]
    value_proportion = (key - a[0]).to_f / key_difference
    (a[1].to_f * value_proportion) + (b[1].to_f * (1.0 - value_proportion))
  end
  
  # utility for rotating around in a full circle and doing stuff
  def turn iterations = nil, &proc
    if iterations
      raise "Iterations must be Numeric" unless iterations.is_a? Numeric
      (0.0...360.0).step(360.0 / iterations, &proc)
    else
      0.0...360.0 # return a range which can be iterated however
    end
  end
  
  # gets and sets resolution settings
  def resolution **settings, &proc
    warn "Setting fragments_per_turn and degrees_per_fragment together makes no sense!" if settings[:fragments_per_turn] && settings[:degrees_per_fragment]
    settings[:fragments_per_turn] ||= settings.delete(:facets_per_turn)
    settings[:degrees_per_fragment] ||= settings.delete(:degrees_per_facet)
    settings[:fragments] ||= settings.delete(:facets)
    settings.delete_if { |key,value| value == nil }
    previous_settings = @resolution
    @resolution.merge! settings
    @resolution[:degrees_per_fragment] = 360.0 / settings[:fragments_per_turn].to_f if settings[:fragments_per_turn]
    @resolution[:fragments_per_turn] = 360.0 / settings[:degrees_per_fragment].to_f if settings[:degrees_per_fragment]
    
    if proc
      return_data = instance_eval(&proc)
      @resolution = previous_settings
      return_data
    else
      @resolution.dup
    end
  end
  
  def _fragments_for diameter: nil, radius: nil
    radius = diameter.to_f / 2.0 if diameter
    if @resolution[:fragments] != 0
      @resolution[:fragments]
    else
      max = (radius.to_f * Math::PI * 2.0) / @resolution[:minimum].to_f
      if @resolution[:fragments_per_turn] > max
        max
      else
        @resolution[:fragments_per_turn]
      end
    end
  end
  
  # the background modifier
  def ghost &proc
    _apply_modifier('%', &proc)
  end
  
  # the debug modifier
  def highlight &proc
    _apply_modifier('#', &proc)
  end
  
  # the root modifier
  def root &proc
    _apply_modifier('!', &proc)
  end
  
  def require *args
    file = args.first
    if file.end_with? '.scad'
      _require_scad_file(*args)
    elsif File.exists? "#{file}.scad"
      _require_scad_file("#{args.shift}.scad", *args)
    else
      Kernel.require(*args)
    end
  end
  
  def _require_scad_file filename, execute: true
    raise "OpenSCAD file #{filename} not found" unless File.exists? filename
    _scan_methods_from_scad_file filename
    
    # add include statement to resulting openscad code
    @ast.push(execute: !!execute, import: filename)
  end
  
  # run some oozby code contained inside a proc
  def _execute_oozby &code
    previously = self.class.active
    self.class.active = self
    result = instance_exec(&code)
    self.class.active = previously
    return result
  end
  
  def _scan_methods_from_scad_file filename
    raise "OpenSCAD file #{filename} not found" unless File.exists? filename
    data = File.read(filename)
    @scanned_scad_files.push filename
    
    # parse out method definitions to add to our environment
    data.gsub!(/\/\/.+?\n/m, "\n") # filter off single line comments
    data.gsub!(/\/\*.+?\*\//m, '') # filter out multiline comments
    data.scan /module[ \t]([a-zA-Z_9-9]+)/ do |module_name|
      @method_preprocessor.openscad_methods.push module_name.first.to_sym
    end
    
    # find any references to more files and recurse in to those
    data.scan /(use|include)[ \t]\<(.+?)\>/ do |filename|
      unless @scanned_scad_files.include? filename
        _scan_methods_from_scad_file filename
      end
    end
  end
  
  def _apply_modifier new_modifier, &children
    if children
      previously = @modifier
      @modifier = new_modifier
        instance_eval &children
      @modifier = previously
    else
      @one_time_modifier = new_modifier
    end
  end
  
  
  # returns the abstract tree
  def _abstract_tree; @ast; end
  
  # make backtraces clearer
  def inspect; "OozbyFile"; end
end

# module you can include in your classes to be able to make 3d shapes in them
module Oozby::Geometry
  def method_missing *args, &proc
    environ = Oozby::Environment.active
    if environ.oozby_method_defined?(args.first)
      environ.oozby_send_method *args, &proc
    else
      super
    end
  end
end

