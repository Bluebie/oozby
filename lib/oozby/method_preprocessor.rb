class Oozby::MethodPreprocessor
  NoResolution = %i{translate rotate scale mirror resize difference union intersection hull minkowski}
  
  def initialize env: nil, ooz: nil
    @env = env
    @parent = ooz
  end
  
  def transform_call(call_info)
    send("_#{call_info.method}", call_info) if respond_to? "_#{call_info.method}"
    resolution call_info unless NoResolution.include? call_info.method # apply resolution settings from scope
    return call_info
  end
  
  # allow translate to take x, y, z named args instead of array, with defaults to 0
  def xyz_to_array(info, default: 0, arg: false, depth: true)
    if [:x, :y, :z].any? { |name| info[:named_args].include? name }
      
      # create coordinate 'vector' (array)
      if depth
        coords = [
          info[:named_args][:x] || default,
          info[:named_args][:y] || default,
          info[:named_args][:z] || default
        ]
      else
        coords = [
          info[:named_args][:x] || default,
          info[:named_args][:y] || default
        ]
      end
      
      # if argument name is specified, use that, otherwise make it the first argument in the call
      if arg
        info[:named_args][arg] = coords
      else
        info[:args].unshift coords
      end
      
      # delete unneeded bits from call
      [:x, :y, :z].each { |item| info[:named_args].delete item }
    end
  end
  
  # layout defaults like center = whatever
  def layout_defaults(info)
    info[:named_args] = @env.defaults.dup.merge(info[:named_args])
  end
  
  # apply resolution settings to call info
  ResolutionLookupTable = {degrees_per_fragment: :"$fa", minimum: :"$fs", fragments: :"$fn"}
  def resolution(info)
    res = @env.resolution
    res.delete_if { |k,v| Oozby::Environment::ResolutionDefaults[k] == v }
    res.each do |key, value|
      info[:named_args][ResolutionLookupTable[key] || "$#{key}".to_sym] ||= value
    end
  end
  
  def _translate(info); xyz_to_array(info, arg: :v); end
  def _rotate(info); xyz_to_array(info, arg: :a); end
  def _scale(info); xyz_to_array(info, default: 1, arg: :v); end
  def _mirror(info); xyz_to_array(info); end
  def _resize(info); xyz_to_array(info, default: 1, arg: :newsize); end
  def _cube(info)
    xyz_to_array(info, default: 1, arg: :size)
    expanded_names(info)
    layout_defaults(info)
    
    if info.named_args[:r] && info.named_args[:r] > 0.0
      # render rounded rectangle
      info.replace rounded_cube(**args_parse(info, :size, :center))
    end
  end
  
  def expanded_names(info, height_label: :h)
    # let users use 'radius' as longhand for 'r'
    info.named_args[:r]  = info.named_args.delete(:radius)   if info.named_args[:radius]
    info.named_args[:r1] = info.named_args.delete(:radius1)  if info.named_args[:radius1]
    info.named_args[:r1] = info.named_args.delete(:radius_1) if info.named_args[:radius_1]
    info.named_args[:r2] = info.named_args.delete(:radius2)  if info.named_args[:radius2]
    info.named_args[:r2] = info.named_args.delete(:radius_2) if info.named_args[:radius_2]
    
    info.named_args[:"$fn"] = info.named_args.delete(:facets) if info.named_args[:facets]
    info.named_args[:"$fn"] = info.named_args.delete(:fragments) if info.named_args[:fragments]
    info.named_args[:"$fn"] = info.named_args.delete(:sides) if info.named_args[:sides]
    
    info.named_args[:ir] = info.named_args.delete(:inr) if info.named_args[:inr]
    info.named_args[:ir] = info.named_args.delete(:inradius) if info.named_args[:inradius]
    info.named_args[:ir] = info.named_args.delete(:inner_r) if info.named_args[:inner_r]
    info.named_args[:ir] = info.named_args.delete(:inner_radius) if info.named_args[:inner_radius]
    
    # let users specify diameter instead of radius - convert it
    {  diameter: :r,                    dia: :r,               d: :r,
      diameter1: :r1, diameter_1: :r1, dia1: :r1, dia_1: :r1, d1: :r1,
      diameter2: :r2, diameter_2: :r2, dia2: :r2, dia_2: :r2, d2: :r2,
      id: :ir, inner_diameter: :ir, inner_d: :ir,
      id1: :ir1, inner_diameter_1: :ir1, inner_diameter1: :ir1,
      id2: :ir2, inner_diameter_2: :ir2, inner_diameter2: :ir2
    }.each do |d, r|
      if info.named_args.key? d
        data = info.named_args.delete(d)
        if data.is_a? Range
          data = Range.new(data.first / 2.0, data.last / 2.0, data.exclude_end?)
        else
          data = data / 2.0
        end
        info.named_args[r] = data
      end
    end
    
    # process 'inner radius' bits
    { ir: :r, ir1: :r1, ir2: :r2 }.each do |ir, r|
      if info.named_args.key? ir
        sides = info.named_args[:"$fn"].to_i
        raise "Use of inner radius requires sides/facets/fragments argument to #{info.method}()" unless sides
        raise "Sides must be at least 3" unless sides >= 3
        inradius = info.named_args.delete(ir)
        if inradius.is_a? Range
          circumradius = Range.new(inradius.first.to_f / @env.cos(180.0 / sides),
                           inradius.first.to_f / @env.cos(180.0 / sides),
                           inradius.exclude_end?)
        else
          circumradius = inradius.to_f / @env.cos(180.0 / sides)
        end
        info.named_args[r] = circumradius
      end
    end
    
    # allow range for radius
    if info.named_args[:r].is_a? Range
      range = info.named_args.delete(:r)
      info.named_args[:r1] = range.first
      info.named_args[:r2] = range.last
    end
    
    # long version 'height' becomes 'h'
    height_specification = info.named_args.delete(:height) || info.named_args.delete(:h)
    info.named_args[height_label] = height_specification if height_specification
  end
  
  def _linear_extrude(info); layout_defaults(info); expanded_names(info, height_label: :height); end
  def _rotate_extrude(info); layout_defaults(info); expanded_names(info); end
  
  def _circle(info); expanded_names(info); end
  def _sphere(info); expanded_names(info); end
  def _cylinder(info); expanded_names(info); layout_defaults(info); end
  def _square(info)
    expanded_names(info)
    xyz_to_array(info, default: 1, arg: :size, depth: false)
    layout_defaults(info)
    
    if info[:named_args][:r] and info.named_args[:r] > 0.0
      # render rounded rectangle
      info.replace rounded_rect(**args_parse(info, :size, :center).merge(facets: info.named_args["$fn"]))
    end
  end
  
  def rounded_rect size: [1,1], center: false, r: 0.0, facets: nil
    size = [size] * 2 if size.is_a? Numeric
    diameter = r * 2
    circle_x = (size[0] / 2.0) - r
    circle_y = (size[1] / 2.0) - r
    
    capture do
      resolution(fragments: (facets || 0)) do
        translate(if center then [0,0] else [size[0].to_f / 2.0, size[1].to_f / 2.0] end) do
          union do
            square([size[0], size[1] - diameter], center = true)
            square([size[0] - diameter, size[1]], center = true)
            preprocessor true do
              resolution(fragments: (_fragments_for(radius: r).to_f / 4.0).round * 4.0) do
                translate([ circle_x,  circle_y]) { circle(r: r) }
                translate([ circle_x, -circle_y]) { circle(r: r) }
                translate([-circle_x, -circle_y]) { circle(r: r) }
                translate([-circle_x,  circle_y]) { circle(r: r) }
              end
            end
          end
        end
      end
    end
  end
  
  def rounded_cube size: [1,1,1], center: false, r: 0.0, facets: nil
    size = [size] * 3 if size.is_a? Numeric
    size = [size[0] || 1, size[1] || 1, size[2] || 1]
    diameter = r.to_f * 2.0
    
    preprocessor = self
    # use rounded rect to create the body shape
    capture do
      resolution(fragments: (facets || 0)) do
        offset = if center then [0,0,0] else [size[0].to_f / 2.0, size[1].to_f / 2.0, size[2].to_f / 2.0] end
        translate(offset) do
          # extrude the main body parts using rounded_rect as the basis
          linear_extrude(height: size[2] - diameter, center: true) {
            inject_abstract_tree(preprocessor.rounded_rect(size: [size[0], size[1]], center: true, r: r)) }
          rotate([90,0,0]) { linear_extrude(height: size[1] - diameter, center: true) {
            inject_abstract_tree(preprocessor.rounded_rect(size: [size[0], size[2]], center: true, r: r)) }}
          rotate([0,90,0]) { linear_extrude(height: size[0] - diameter, center: true) {
            inject_abstract_tree(preprocessor.rounded_rect(size: [size[2], size[1]], center: true, r: r)) }}
        
          # fill in the corners with spheres
          xr, yr, zr = size.map { |x| (x / 2.0) - r }
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
            resolution(fragments: (_fragments_for(radius: r.to_f).to_f / 4.0).round * 4.0) do
              corner_coordinates.each do |coordinate|
                translate(coordinate) do
                  # generate sphere shape
                  rotate_extrude do
                    intersection do
                      circle(r: r)
                      translate([r, 0, 0]) { square([r * 2.0, r * 4.0], center: true) }
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
  
  # parse arguments like openscad does
  def args_parse(info, *arg_names)
    args = info[:named_args].dup
    info[:args].length.times do |index|
      warn "Overwriting argument #{arg_names[index]}" if args.key? arg_names[index]
      args[arg_names[index]] = info[:args][index]
    end
    
    args
  end
  
  def capture &proc
    (@env._subscope {
      preprocessor(false) {
        instance_eval(&proc)
      }
    }).first    
  end
  
  # meta! construct aliases which preset some values
  def self.oozby_alias from, to, extra_args = {}
    define_method "_#{from}" do |info|
      info.method = to
      info.named_args.merge! extra_args
      send("_#{to}", info) if self.respond_to? "_#{to}"
    end
  end
  
  # some regular shapes - from:
  # http://en.wikipedia.org/wiki/Regular_polygon#Regular_convex_polygons
  {
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
  }.each do |shape_name, sides|
    oozby_alias shape_name, :circle, sides: sides
  end
end




