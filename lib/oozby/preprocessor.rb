# The Oozby Method Preprocessor handles requests via the transform_call method
# and transforms the Oozby::Element passed in, patching in any extra features
# and trying to alert the user of obvious bugs
class Oozby::Preprocessor
  @@method_filters ||= {}
  @@default_filters ||= []
  @@queued_filters ||= []
  # metaprogramming for hooking up filters before method definitions
  class << self
    # sets a list of default filters which aren't reset after each method def
    def default_filters *list
      @@default_filters = list.map { |x| if x.is_a? Array then x else [x] end }
      @@queued_filters = @@default_filters.dup
    end
    
    # set a filter to be added only to the next method def
    def filter filter_name, *options
      @@queued_filters ||= @@default_filters.dup
      @@queued_filters.delete_if { |x| x[0] == filter_name } # replace default definitions
      @@queued_filters.push([filter_name, *options]) # add new filter definition
    end
    
    # detect a method def, store it's filters and reset for next def
    def method_added method_name
      passthrough method_name
      super
    end
    
    # don't want to define a primary processor method? pass it through manually
    def passthrough method_name
      @@method_filters[method_name] = @@queued_filters
      @@queued_filters = @@default_filters.dup
    end
    
    # get list of filters for a method name
    def filters_for method_name
      @@method_filters[method_name] || []
    end
    
    # alias an name to an openscad method optionally with extra defaults
    # useful for giving things more descriptive names, where those names imply
    # different defaults, like hexagon -> circle(sides: 6)
    def oozby_alias from, to, extra_args = {}
      define_method(from) do
        call.named_args.merge!(extra_args) { |key,l,r| l } # left op wins conflicts
        redirect(to)
      end
    end
  end
  
  # never pass resolution data in to these methods - it's pointless:
  NoResolution = %i(translate rotate scale mirror resize difference union
                    intersection hull minkowski color)
  # list of OpenSCAD standard methods - these can pass through without error:
  DefaultOpenSCADMethods = %i(
    cube sphere cylinder polyhedron
    circle square polygon
    scale resize rotate translate mirror multmatrix color minkowski hull
    linear_extrude rotate_extrude import import_dxf projection
    union difference intersection render
  )
  
  attr_accessor :openscad_methods, :call
  # setup a new method preprocessor
  def initialize env: nil, ooz: nil
    @env = env
    @parent = ooz
    @openscad_methods = DefaultOpenSCADMethods.dup
  end
  
  # accepts an Oozby::Element and transforms it according to the processors' rules
  def transform_call call_info
    raise "call info isn't Oozby::Element #{call_info.inspect}" unless call_info.is_a? Oozby::Element
    @call = call_info
    original_method = @call.method
    
    # apply the other filters
    filters = self.class.filters_for(call_info.method)
    filters.each do |filter_data|
      filter_name, *filter_args = filter_data
      send(filter_name, *filter_args)
    end
    
    methods = primary_processors
    # if a primary processor is defined for this kind of call
    if methods.include? call_info.method.to_sym
      # call the primary processor
      result = public_send(call_info.method, *primary_method_args(call_info.method))
      
      # replace the ast content with the processor's output
      if result.is_a? Hash or result.is_a? Oozby::Element
        # replace called item with this new stuff
        return result
      elsif result != nil # ignore nil - we don't need to do anything for that!
        raise "#{original_method} preprocessor returned invalid result #{result.inspect}"
      end
    end
    
    return call_info
  end
  
  # generates argument list to call a primary method processor
  def primary_method_args(method) # :nodoc:
    # grab the primary processor
    primary = self.class.public_instance_method(method.to_sym)
    params = primary.parameters
    # parse the processor method's signature
    param_names = params.select { |x| x.first == :key }.map { |x| x[1] }
    # filter down args to only those requested
    calling_args = call.named_args.dup
    # convert unnamed call args to named args
    calling_args.merge! args_parse(call, *param_names)
    # delete any args the receiver can't handle
    calling_args.delete_if { |k,v| not param_names.include?(k) }
    if calling_args.empty? then [] else [calling_args] end
  end
  
  # list of primary processor methods
  def primary_processors
    @primary_processors ||= public_methods(false) - @@system_methods
  end
  
  # does this processor know of a method named whatever?
  def known? name
    known.include? name.to_sym
  end
  
  # array of all known method names
  def known
    list = @openscad_methods.dup
    list.push *primary_processors
    list.push *@@method_filters.keys
    list.uniq
  end
  
  # rewrite this method to a different method name and primary processor and whatever else
  def redirect new_method
    call.method = new_method.to_sym
    public_send(new_method, *primary_method_args(call.method)) if self.respond_to? new_method
  end
  
  
  # parse arguments like openscad does
  def args_parse(info, *arg_names)
    args = info.named_args.dup
    info.args.length.times do |index|
      warn "Overwriting argument #{arg_names[index]}" if args.key? arg_names[index]
      args[arg_names[index]] = info.args[index]
    end
    
    args
  end
  
  # capture contents of a block as openscad code, returning AST array
  def capture &proc
    env = @env
    (env._subscope {
      env.preprocessor(false) {
        env._execute_oozby(&proc)
      }
    }).find { |x| x.is_a? Oozby::Element }
  end
  
  # remember list of public methods defined so far - these are system ones
  @@system_methods = public_instance_methods(false)
end


