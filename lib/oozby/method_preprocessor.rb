# The Oozby Method Preprocessor handles requests via the transform_call method
# and transforms the Oozby::Element passed in, patching in any extra features
# and trying to alert the user of obvious bugs
class Oozby::MethodPreprocessor
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









class Oozby::MethodPreprocessor
  ##############################################################################
  ########## All PUBLIC methods below this line are Preprocessors! #############
  ##############################################################################
  public
  
  default_filters [:xyz, default: 0]
  passthrough :rotate
  passthrough :translate
  passthrough :mirror
  default_filters [:xyz, default: 1]
  passthrough :scale
  passthrough :resize  
  
  default_filters # none for these guys
  passthrough :multmatrix
  passthrough :color
  
  default_filters :resolution, :layout_defaults, :expanded_names
  
  # detect requests for rounded cubes and transfer them over
  filter :xyz, depth: true # cube has xy coords
  filter :rename_args, [:r, :cr, :corner_r] => :corner_radius
  def cube size: [1,1,1], center: false, corner_radius: 0
    return rounded_rectangular_prism(size: size, center: center, corner_radius: corner_radius) if corner_radius > 0
    return call
  end
  
  
  # detect requests for rounded cylinders and transfer them over
  filter :rename_args, [:cr, :corner_r] => :corner_radius
  def cylinder h: 1, r1: nil, r2: nil, r: nil, center: false, corner_radius: 0
    r1, r2 = r, r if r unless r1 || r2
    return rounded_cylinder(h: h, r1: r1, r2: r2, center: center, corner_radius: corner_radius) if corner_radius > 0
    return call
  end
  
  passthrough :sphere
  #passthrough :cylinder
  passthrough :polyhedron
  # 2d shapes
  
  # detect requests for rounded squares and transfer them over
  filter :xyz, arg: :size, depth: false # square has xy coords
  filter :rename_args, [:r, :cr, :corner_r] => :corner_radius
  def square size: [1,1], center: false, corner_radius: 0
    return rounded_rectangle(size: size, center: center, corner_radius: corner_radius) if corner_radius > 0
    return call
  end
  
  passthrough :circle
  passthrough :polygon
  # extrude 2d shapes to 3d shapes
  filter :expanded_names, height_label: :height
  passthrough :linear_extrude
  passthrough :rotate_extrude
  
  default_filters # none
  passthrough :minkowski
  passthrough :hull
  passthrough :import
  passthrough :projection
  
  passthrough :union
  passthrough :difference
  passthrough :intersection
  passthrough :render
  
  ### Various ngons and prisms:
  # http://en.wikipedia.org/wiki/Regular_polygon#Regular_convex_polygons
  polygon_names = {
    triangle: 3,
    equilateral_triangle: 3,
    pentagon: 5,
    hexagon: 6,
    heptagon: 7,
    octagon: 8,
    nonagon: 9,
    enneagon: 9,
    decagon: 10,
    hendecagon: 11,
    undecagon: 11,
    dodecagon: 12,
    tridecagon: 13,
    tetradecagon: 14,
    pentadecagon: 15,
    hexadecagon: 16,
    heptadecagon: 17,
    octadecagon: 18,
    enneadecagon: 19,
    icosagon: 20,
    triacontagon: 30,
    tetracontagon: 40,
    pentacontagon: 50,
    hexacontagon: 60,
    heptacontagon: 70,
    octacontagon: 80,
    enneacontagon: 90,
    hectogon: 100
  }
  polygon_names.each do |shape_name, sides|
    oozby_alias shape_name, :circle, sides: sides
  end
  
  # make a polygon with an arbitrary number of sides
  oozby_alias :ngon, :circle, sides: 3
  # make a prism with an arbitrary number of sides
  oozby_alias :prism, :cylinder, sides: 3
  
  # triangles are an edge case
  oozby_alias :triangular_prism, :cylinder, sides: 3
  
  # for all the rest, transform the prism names automatically
  polygon_names.each do |poly_name, sides|
    name = poly_name.to_s
    if name.end_with? 'gon'
      name += 'al_prism'
      oozby_alias name, :cylinder, sides: sides
    end
  end
  
  
  
  ##############################################################################
  ######################### Begin Filters section! #############################
  ##############################################################################
  private
  # apply resolution settings to element
  ResolutionNames = { degrees_per_fragment: "$fa", minimum: "$fs", fragments: "$fn" }
  def resolution
    res = @env.resolution
    res.delete_if { |k,v| Oozby::Environment::ResolutionDefaults[k] == v }
    res.each do |key, value|
      call.named_args[(ResolutionNames[key] || "$#{key}").to_sym] ||= value
    end
  end
  
  # layout defaults like {center: true}
  def layout_defaults
    # copy in defaults if not already specified
    call.named_args.merge!(@env.defaults) { |k,a,b| a }
  end
  
  # filter to rename certain arguments to other things
  def rename_args pairs
    pairs.each do |from_keys, to_key|
      from_keys = [from_keys] unless from_keys.is_a? Array
      if from_keys.any? { |key| call.named_args[key.to_sym] }
        value = from_keys.map { |key| call.named_args.delete(key) }.compact.first
        call.named_args[to_key.to_sym] = value if value != nil
      end
    end
  end
  
  # general processing of arguments:
  #  -o> Friendly names - use radius instead of r if you like
  #  -o> Ranges - can specify radius: 5...10 instead of r1: 5, r2: 10
  #  -o> Make h/height consistent (either works everywhere)
  #  -o> Support inner radius, when number of sides is specified
  #  -o> Specify diameter and have it halved automatically
  def expanded_names height_label: :h
    # let users use 'radius' as longhand for 'r', and some other stuff
    rename_args(
      [:radius] => :r,
      [:radius1, :radius_1] => :r1,
      [:radius2, :radius_2] => :r2,
      [:facets, :fragments, :sides] => :"$fn",
      [:inr, :inradius, :in_radius, :inner_r, :inner_radius] => :ir,
      [:height, :h] => height_label
    )
    
    # let users specify diameter instead of radius - convert it
    {  diameter: :r,                    dia: :r,               d: :r,
      diameter1: :r1, diameter_1: :r1, dia1: :r1, dia_1: :r1, d1: :r1,
      diameter2: :r2, diameter_2: :r2, dia2: :r2, dia_2: :r2, d2: :r2,
      id: :ir, inner_diameter: :ir, inner_d: :ir,
      id1: :ir1, inner_diameter_1: :ir1, inner_diameter1: :ir1,
      id2: :ir2, inner_diameter_2: :ir2, inner_diameter2: :ir2
    }.each do |d, r|
      if call.named_args.key? d
        data = call.named_args.delete(d)
        if data.is_a? Range
          data = Range.new(data.first / 2.0, data.last / 2.0, data.exclude_end?)
        elsif data.respond_to? :to_f
          data = data.to_f / 2.0
        else
          raise "#{data.inspect} must be Numeric or a Range"
        end
        call.named_args[r] = data
      end
    end
    
    # process 'inner radius' bits
    { ir: :r, ir1: :r1, ir2: :r2 }.each do |ir, r|
      if call.named_args.key? ir
        sides = call.named_args[:"$fn"].to_i
        raise "Use of inner radius requires sides/facets/fragments argument to #{info.method}()" unless sides
        raise "Sides must be at least 3" unless sides >= 3
        inradius = call.named_args.delete(ir)
        if inradius.is_a? Range
          circumradius = Range.new(inradius.first.to_f / @env.cos(180.0 / sides),
                           inradius.first.to_f / @env.cos(180.0 / sides),
                           inradius.exclude_end?)
        elsif inradius.respond_to? :to_f
          circumradius = inradius.to_f / @env.cos(180.0 / sides)
        else
          raise "#{inradius.inspect} must be Numeric or a Range"
        end
        call.named_args[r] = circumradius
      end
    end
    
    # convert range radius to r1 and r2 pair
    if call.named_args[:r].is_a? Range
      range = call.named_args.delete(:r)
      call.named_args[:r1] = range.first
      call.named_args[:r2] = range.last
    end
  end
  
  def xyz default: 0, arg: false, depth: true
    if [:x, :y, :z].any? { |name| call.named_args.include? name }
      coords = [call.named_args.delete(:x), call.named_args.delete(:y)]
      coords.push call.named_args.delete(:z) if depth
      coords.map! { |x| x or default } # apply default value to missing data
      
      # if argument name is specified, use that, otherwise make it the first argument in the call
      if arg
        call.named_args[arg] = coords
      else
        call.args.unshift coords
      end
    end
  end
  
  
  def rounded_rectangle size: [1,1], center: false, corner_radius: 0.0, facets: nil
    size = [size] * 2 if size.is_a? Numeric
    size = [size[0] || 1, size[1] || 1]
    raise "Corner radius is too big. Max #{size.min / 2.0} for this square" if corner_radius * 2.0 > size.min
    corner_diameter = corner_radius * 2.0
    circle_x = (size[0] / 2.0) - corner_radius
    circle_y = (size[1] / 2.0) - corner_radius
    
    capture do
      resolution(fragments: (facets || 0)) do
        translate(if center then [0,0] else [size[0] / 2.0, size[1] / 2.0] end) do
          union do
            square([size[0], size[1] - corner_diameter], center = true)
            square([size[0] - corner_diameter, size[1]], center = true)
            preprocessor true do
              resolution(fragments: (_fragments_for(radius: corner_radius).to_f / 4.0).round * 4.0) do
                translate([ circle_x,  circle_y]) { circle(r: corner_radius) }
                translate([ circle_x, -circle_y]) { circle(r: corner_radius) }
                translate([-circle_x, -circle_y]) { circle(r: corner_radius) }
                translate([-circle_x,  circle_y]) { circle(r: corner_radius) }
              end
            end
          end
        end
      end
    end
  end
  
  # create a rounded cylinder shape
  def rounded_cylinder h: 1, r1: 1, r2: 1, center: false, corner_radius: 0
    radii = [r1, r2]
    raise "corner_radius is too big. Max is #{radii.min} for this cylinder" if corner_radius > radii.min
    corner_diameter = corner_radius * 2.0
    
    preprocessor = self
    # use rounded rect to create the body shape
    capture do
      facets = preprocessor.call.named_args[:"$fn"] || _fragments_for(radius: radii.min)
      
      translate([0,0, if center then -h / 2.0 else 0 end]) >
      rotate_extrude(:"$fn" => facets) do
        # cut our a section to rotate extrude in to cylinder
        intersection do
          # square cut out
          square([r1 * 2, h * 2])
          # minkowski combine 2d tapering cylinder cut shape, with a circle
          minkowski do
            # cylinder shape, inset by corner_radius amount
            polygon([
              [0,corner_radius],
              [r1 - corner_radius, corner_radius],
              [r2 - corner_radius, h - corner_radius],
              [0, h - corner_radius]
            ])
            # circle to fill in
            circle(r: corner_radius, :"$fn" => facets)
          end
        end
      end
    end
  end
  
  # handle rounded cubes
  def rounded_rectangular_prism size: [1,1,1], center: false, corner_radius: 0, facets: nil
    size = [size] * 3 if size.is_a? Numeric
    size = [size[0] || 1, size[1] || 1, size[2] || 1]
    raise "Radius is too big. Max #{size.min / 2.0} for this square" if corner_radius * 2.0 > size.min
    corner_diameter = corner_radius.to_f * 2.0

    preprocessor = self
    # use rounded rect to create the body shape
    capture do
      resolution(fragments: (facets || 0)) do
        union do
          offset = if center then [0,0,0] else [size[0].to_f / 2.0, size[1].to_f / 2.0, size[2].to_f / 2.0] end
          translate(offset) do
            # extrude the main body parts using rounded_rectangle as the basis
            linear_extrude(height: size[2] - corner_diameter, center: true) {
              inject_abstract_tree(preprocessor.send(:rounded_rectangle, size: [size[0], size[1]], center: true, corner_radius: corner_radius)) }
            rotate([90,0,0]) { linear_extrude(height: size[1] - corner_diameter, center: true) {
              inject_abstract_tree(preprocessor.send(:rounded_rectangle, size: [size[0], size[2]], center: true, corner_radius: corner_radius)) }}
            rotate([0,90,0]) { linear_extrude(height: size[0] - corner_diameter, center: true) {
              inject_abstract_tree(preprocessor.send(:rounded_rectangle, size: [size[2], size[1]], center: true, corner_radius: corner_radius)) }}

            # fill in the corners with spheres
            xr, yr, zr = size.map { |x| (x / 2.0) - corner_radius }
            corner_coordinates = [
              [ xr, yr, zr],
              [ xr, yr,-zr],
              [ xr,-yr, zr],
              [ xr,-yr,-zr],
              [-xr, yr, zr],
              [-xr, yr,-zr],
              [-xr,-yr, zr],
              [-xr,-yr,-zr]
            ]
            preprocessor true do
              resolution(fragments: (_fragments_for(radius: corner_radius.to_f).to_f / 4.0).round * 4.0) do
                corner_coordinates.each do |coordinate|
                  translate(coordinate) do
                    # generate sphere shape
                    rotate_extrude do
                      intersection do
                        circle(r: corner_radius)
                        translate([corner_radius, 0, 0]) { square([corner_radius * 2.0, corner_radius * 4.0], center: true) }
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end




