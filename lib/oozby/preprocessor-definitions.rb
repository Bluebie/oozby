class Oozby::Preprocessor
  ##############################################################################
  ########## All PUBLIC methods below this line are Preprocessors! #############
  ##############################################################################
  public
  
  default_filters [:xyz, default: 0]
  passthrough :rotate, :a, :v
  passthrough :translate, :v
  passthrough :mirror, :v
  passthrough :resize, :newsize, :auto
  default_filters [:xyz, default: 1]
  passthrough :scale, :v
  
  default_filters # none for these guys
  passthrough :multmatrix, :m
  passthrough :color, :c
  
  default_filters :resolution, :layout_defaults, :expanded_names
  
  # detect requests for rounded cubes and transfer them over
  filter :xyz, depth: true, default: 1 # cube has xy coords
  filter :rename_args, [:r, :cr, :corner_r] => :corner_radius
  filter :validate, size: [Array, Numeric], center: [true, false], corner_radius: Numeric
  def cube size: [1,1,1], center: false, corner_radius: 0
    return rounded_rectangular_prism(size: size, center: center, corner_radius: corner_radius) if corner_radius > 0
    return call
  end
  
  
  # detect requests for rounded cylinders and transfer them over
  filter :rename_args, [:cr, :corner_r] => :corner_radius
  filter :validate, h: Numeric, r1: [Numeric, nil], r2: [Numeric, nil], r: [Numeric, nil], center: [true, false], corner_radius: Numeric
  def cylinder h: 1, r1: nil, r2: nil, r: nil, center: false, corner_radius: 0
    r1, r2 = r, r if r unless r1 || r2
    return rounded_cylinder(h: h, r1: r1, r2: r2, center: center, corner_radius: corner_radius) if corner_radius > 0
    return call
  end
  
  passthrough :sphere, :r
  passthrough :polyhedron, :points, :triangles, :convexity
  # 2d shapes
  
  # detect requests for rounded squares and transfer them over
  filter :xyz, arg: :size, depth: false, default: 1 # square has xy coords
  filter :rename_args, [:r, :cr, :corner_r] => :corner_radius
  filter :validate, size: [Array, Numeric], center: [true, false], corner_radius: Numeric
  def square size: [1,1], center: false, corner_radius: 0
    return rounded_rectangle(size: size, center: center, corner_radius: corner_radius) if corner_radius > 0
    return call
  end
  
  filter :refuse_args, :h
  passthrough :circle, :r
  filter :refuse_args, :h
  passthrough :polygon, :points, :paths
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
  
  # filter to patch in layout defaults like center: true when not specified
  # explicitly in this call
  def layout_defaults
    # copy in defaults if not already specified
    call.named_args.merge!(@env.defaults) { |k,a,b| a }
  end
  
  # filter to rename certain arguments to other things
  # Usage> filter :rename_args, :old_arg => :new_arg, :other => morer
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
      [:width] => :diameter,
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
        sides = call.named_args[:"$fn"]
        raise "Use of inner_radius requires sides/facets/fragments argument to #{call.method}()" unless sides.is_a? Numeric
        raise "sides/facets/fragments argument must be a whole number (Fixnum)" unless sides.is_a? Fixnum
        raise "sides/facets/fragments argument must be at least 3 #{call} to use inner_radius" unless sides >= 3
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
  
  # filter calls to a method, transforming x, y, and optionally z arguments in
  # to a 2 or 3 item array, setting it to the argument named 'arg' or setting
  # it as the first numerically indexed argument if that is unspecified. A
  # default value can be supplied.
  # Usage> filter :xyz, default: 1, arg: :size, depth: false
  def xyz default: 0, arg: false, depth: true
    if [:x, :y, :z].any? { |name| call.named_args.include? name }
      # validate args
      [:x, :y, :z].each do |key|
        if call.named_args.has_key? key
          unless call.named_args[key].is_a? Numeric
            raise "#{key} must be Numeric, value #{call.named_args[key].inspect} is not."
          end
        end
      end
      
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
  
  
  # simple validator to check particular named arguments conform to required types
  # or exactly match a set of values
  # Usage> filter :validate, argument_name: Symbol, other_argument: ["yes", "no"], radius: [Numeric, Range]
  def validate args = {}
    args.keys.each do |args_keys|
      acceptable = if args[args_keys].respond_to? :each then args[args_keys] else [args[args_keys]] end
      key_list = if args_keys.respond_to? :each then args_keys else [args_keys] end
      key_list.each do |key|
        # for this key, check it matches acceptable list, if specified
        if call.named_args.keys.include? key
          value = call.named_args[key]
          if acceptable.none? { |accepts| accepts === value }
            raise "#{@original_method}'s argument #{key} must be #{acceptable.inspect}"
          end
        end
      end
    end
  end
  
  # require certain arguments be specified to a processed method
  # Usage> filter :require_args, :first_arg, :second_arg
  def require_args *list
    list.each do |name|
      raise "#{@original_method} requires argument #{name}" unless call.named_args.keys.include? name
    end
  end
  
  # ban a list of arguments, to highlight mistakes like passing height to circle
  # Usage> filter :refuse_args, :h
  def refuse_args *list
    list.each do |name|
      raise "#{@original_method} doesn't support #{name}" if call.named_args.keys.include? name
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
    corner_diameter = corner_radius * 2
    
    preprocessor = self
    # use rounded rect to create the body shape
    capture do
      facets = preprocessor.call.named_args[:"$fn"] || _fragments_for(radius: radii.min)
      
      translate([0,0, if center then -h / 2.0 else 0 end]) >
      #union do
      rotate_extrude(:"$fn" => facets) do
        hull do
          # table to calculate radii at in between y positions
          table = { 0.0 => r1, h.to_f => r2 }
          # offset taking in to account angle of wall, as the line between each
          # circle after the hull operation will not be from exactly corner_radius
          # height when the side angle is not 90deg
          lookup_offset = corner_radius * sin(atan2(r2-r1, h) / 2.0)
          # bottom right corner
          translate([lookup(corner_radius + lookup_offset, table) - corner_radius, h - corner_radius]) >
          circle(r: corner_radius, :"$fn" => facets)
          # top right corner
          translate([lookup(h - corner_radius + lookup_offset, table) - corner_radius, corner_radius]) >
          circle(r: corner_radius, :"$fn" => facets)
          # center point
          square([radii.min - corner_radius, h])
        end
      end
    end
  end
  
  # handle rounded cubes
  def rounded_rectangular_prism size: [1,1,1], center: false, corner_radius: 0, facets: nil
    size = [size] * 3 if size.is_a? Numeric
    size = [size[0] || 1, size[1] || 1, size[2] || 1]
    raise "Radius is too big. Max #{size.min / 2.0} for this cube" if corner_radius * 2.0 > size.min
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


