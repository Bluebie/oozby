require 'json'

# takes in an oozby abstract tree, and writes out openscad source code
class Oozby::Render
  def initialize ooz: nil
    @oozby = ooz
  end
  
  def escape thing
    JSON.generate(thing, quirks_mode: true)
  end
  
  def render code_tree, clean: true
    output = []
    code_tree.each do |node|
      if node.key? :method
        # function call
        method_name = (node[:modifier].to_s || '') + node[:method].to_s
        
        args = node[:args].map { |a| escape(a) }
        node[:named_args].each do |key, value|
          args.push "#{key} = #{escape(value)}"
        end
        
        call = "#{method_name}(#{args.join(', ')})"
        if node[:children].nil? or node[:children].empty?
          output.push "#{call};"
        elsif node[:children].length == 1
          rendered_kids = render(node[:children])
          output.push "#{call} " + rendered_kids.shift
          output.push *rendered_kids
        else
          output.push "#{call} {"
          output.push   *render(node[:children]).map { |line| if clean then "  #{line}" else line.to_s end }
          output.push "}"
        end
        
      elsif node.key? :comment
        output.push "/* #{node[:comment]} */"
      elsif node.key? :assign
        output.push "#{node[:assign]} = #{escape(node[:value])};"
      elsif node.key? :import
        output.push "#{node[:execute] ? 'include' : 'use'} <#{node[:import]}>;"
      end
    end
    
    output
  end
end

