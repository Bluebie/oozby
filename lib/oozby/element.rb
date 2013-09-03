# Represent an oozby element
class Oozby::Element
  attr_reader :data, :siblings
  
  def initialize hash, parent_array
    @data = hash
    @siblings = parent_array
  end
  
  # include the next thing as a child of this thing
  def > other
    if other.respond_to? :to_oozby_element
      other = [other]
    elsif not other.is_a?(Array) or other.any? { |item| not item.respond_to? :to_oozby_element }
      raise "Can only use > combiner to add Oozby::Element or array of Elements"
    end
    
    # convert all items to real Oozby Elements
    other = other.map { |item| item.to_oozby_element }
    
    # add others as children
    children.push *(other.map { |item| item.data })
    
    # remove children from their previous parents
    other.each do |thing|
      thing.siblings = children
    end
    
    other.first
  end
  
  def index
    @siblings.index(@data)
  end
  
  def siblings= new_parent
    @siblings.delete @data
    @siblings = new_parent
  end
  
  [:children, :modifier, :method, :args, :named_args].each do |hash_accessor_name|
    define_method(hash_accessor_name) { @data[hash_accessor_name] }
    define_method("#{hash_accessor_name}=") { |val| @data[hash_accessor_name] = val }
  end
  
  def method_missing name, *args, &proc
    if @data.respond_to? name
      @data.send(name, *args, &proc)
    else
      super
    end
  end
  
  def to_oozby_element
    self
  end
end