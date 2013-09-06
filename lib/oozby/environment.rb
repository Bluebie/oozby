class Oozby::Environment
  ResolutionDefaults = {
    degrees_per_fragment: 12,
    fragments_per_turn: 30,
    minimum: 2,
    fragments: 0
  }
  
  def initialize(ooz: nil)
    @parent = ooz
    @ast = []
    @defaults = {center: false}
    @resolution = ResolutionDefaults.dup
    @modifier = nil
    @one_time_modifier = nil
    @preprocess = true
    @method_history = []
    @method_preprocessor = Oozby::MethodPreprocessor.new(env: self, ooz: @parent)
  end
  
  # create a new scope that inherits from this one, and capture syntax tree created
  def _subscope &proc
    # capture instance variables
    capture = {}
    instance_variables.each { |key| capture[key] = self.instance_variable_get(key) }
    
    # reset for ast capture
    @ast = []
    @one_time_modifier = nil
    @defaults = @defaults.dup
    @resolution = @resolution.dup
    self.instance_eval &proc
    syntax_tree = @ast
    
    # restore instance variables
    capture.each { |key, value| self.instance_variable_set(key, value) }
    
    return syntax_tree
  end
  
  def inject_abstract_tree code
    code = [code] unless code.is_a? Array
    @ast.push(*code)
  end
  
  def method_missing method_name, *args, **hash, &proc
    if proc
      children = _subscope(&proc)
    else
      children = []
    end
    
    call = {
      method: method_name,
      args: args, named_args: hash,
      children: children, 
      modifier: @one_time_modifier || @modifier,
      call_address: @ast.length
    }
    
    @ast.push call
    element = Oozby::Element.new(call, @ast)
    @method_preprocessor.transform_call(element) if @preprocess
    @one_time_modifier = nil
    @method_history.push method_name # maintain list of recent methods to aid debugging
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
end




