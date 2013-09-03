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
  def xyz_to_array(info, default: 0, arg: false)
    if [:x, :y, :z].any? { |name| info[:named_args].include? name }
      
      # create coordinate 'vector' (array)
      coords = [
        info[:named_args][:x] || default,
        info[:named_args][:y] || default,
        info[:named_args][:z] || default
      ]
      
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
    
    if info.named_args[:r]
      # render rounded rectangle
      info.replace rounded_cube(**args_parse(info, :size, :center, :r))
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
    
    # let users specify diameter instead of radius - convert it
    {  diameter: :r,                    dia: :r,               d: :r,
      diameter1: :r1, diameter_1: :r1, dia1: :r1, dia_1: :r1, d1: :r1,
      diameter2: :r2, diameter_2: :r2, dia2: :r2, dia_2: :r2, d2: :r2
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
    xyz_to_array(info, default: 1, arg: :size)
    layout_defaults(info)
    
    if info[:named_args][:r]
      # render rounded rectangle
      info.replace rounded_rect(**args_parse(info, :size, :center, :r))
    end
  end
  
  def rounded_rect size: [1,1], center: false, r: 0.0
    diameter = r * 2
    circle_x = (size[0] / 2.0) - r
    circle_y = (size[1] / 2.0) - r
    
    capture do
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
  
  def rounded_cube size: [1,1,1], center: false, r: 0.0
    size = [size[0] || 1, size[1] || 1, size[2] || 1]
    diameter = r.to_f * 2.0
    
    preprocessor = self
    # use rounded rect to create the body shape
    capture do
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
        xr, yr, zr = size.map { |x| (x / 2) - r }
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
          resolution(fragments: (_fragments_for(radius: r).to_f / 4.0).round * 4.0) do
            corner_coordinates.each do |coordinate|
              translate(coordinate) do
                # generate sphere shape
                rotate_extrude do
                  intersection do
                    circle(r: r)
                    translate([r, 0, 0]) { square([r * 2, r * 4], center: true) }
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
end




