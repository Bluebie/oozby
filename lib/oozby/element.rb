# Represent an oozby element
class Oozby::Element
  attr_reader :data, :siblings
  
  def initialize hash
    @data = hash
    @siblings = nil #parent_array
  end
  
  # include the next thing as a child of this thing
  def > other
    raise "Can only combine an Oozby::Element to another Oozby::Element" unless other.respond_to? :to_oozby_element
    other.to_oozby_element.abduct self.children
    other
  end
  
  # add this element to the end of supplied array
  def abduct into
    @siblings.delete self if @siblings # remove from current location
    @siblings = into # our new location is here
    into.push self # append ourselves to the new parent
  end
  
  def index
    @siblings.index(self)
  end
  
  # def siblings= new_parent
  #   @siblings.delete self
  #   @siblings = new_parent
  # end
  
  # replace this element with any number of other elements and hashes
  # def replace *others
  #   raise "Can't replace Oozby::Element with things that aren't hash-like" unless others.all? { |x| x.respond_to? :to_h }
  #   puts "Replacing: #{self} with [#{others.join('; ')}]"
  #   idx = self.index
  #   others.each { |x| x.siblings = @siblings if x.respond_to? :siblings= }
  #   @siblings[idx..idx] = others
  # end
  
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
  
  def to_s
    x = args.map { |x| x.inspect }
    named_args.each { |name, value| x.push "#{name}: #{value.inspect}"}
    "#{method}(#{x.join(', ')})"
  end
  
  def to_h
    @data
  end
  
  def to_oozby_element
    self
  end
end