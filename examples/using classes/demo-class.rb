# Liion represents standard round lithium ion cells, like the common 18650
# offering width and height properties, and a #part method which instansiates
# a 3D model of the battery, including specified tollerance
class LiionBattery
  include Oozby::Geometry # allow module to call oozby methods
  ProtectedRoundLiionOffset = 1020
  
  def initialize code, protected: false, tollerance: 0.5
    @tollerance = tollerance
    @protected = protected
    
    # decode battery code in to diameters
    code = code.to_i + ProtectedRoundLiionOffset if protected
    @width, @height = code.to_s.match(/(\d\d)(\d\d\d)/).captures.map(&:to_f)
    @height = @height / 10.0
    @height += @tollerance
    @width += @tollerance
  end
  
  # create 3D model of battery at current oozby location
  def part
    positive_tab_diameter = (@width / 2.5) .. (@width / 3.0)

    union do
      # main battery section
      cylinder height: @height, diameter: @width

      # positive tab
      translate(z: @height - 0.05) > cylinder(diameter: positive_tab_diameter, height: 1.0)
    end
  end
  
  attr_accessor :width, :height, :protected, :tollerance
end

