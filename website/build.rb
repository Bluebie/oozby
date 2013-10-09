require 'redcarpet'
require 'nokogiri'
require 'coderay'
require 'erb'
require 'zlib' # for crc32 stuff
require '../lib/oozby'
require 'tempfile'
require 'fileutils'
require 'oily_png'
ImgSize = '976,976'
PreviewsRendered = []
OpenSCADBinary = '~/Documents/OpenSCAD.app/Contents/MacOS/OpenSCAD'
BackgroundColor = 0xc3e892ff

def hasher string
  Zlib.crc32(string.to_s).to_s(36)
end

# execute oozby sample code and render a preview image
def render_preview code, file, code_idx
  url = "assets/autorender-#{file}-#{code_idx}-#{hasher(code)}.png"
  PreviewsRendered.push(url)
  unless File.exists? "./#{url}"
    file = Tempfile.new('oozby-website-builder')
    file.write(code)
    file.close
    scad_path = "#{file.path}.scad"
    img_path = "#{file.path}.png"
    
    if code.lines.first.start_with? "# render "
      extra_settings = code.lines.first.sub("# render ", '').strip
    end
    
    # compile with oozby and render with openscad app
    system('oozby', 'compile', file.path)
    `#{OpenSCADBinary} #{extra_settings} --imgsize=#{ImgSize} --projection=o -o '#{img_path}' '#{scad_path}'`
    scad_code = File.read(scad_path)
    FileUtils.cp img_path, "./#{url}"
    # delete garbage files
    [scad_path, img_path, file.path].each { |f| File.delete(f) }
    
    # postprocess image using chunky_png
    unless File.size("./#{url}") == 0
      image = ChunkyPNG::Image.from_file("./#{url}")
      template_color = image[0,0]
      image.width.times do |x|
        image.height.times do |y|
          image[x,y] = BackgroundColor if image[x,y] == template_color
        end
      end
      image.save("./#{url}", :fast_rgba) # Overwrite file
    end
    
    return url, scad_code
  end
  return url, '/* error rendering */'
end

# parse file as markdown, and add ruby syntax highlighting to code sections
def parse md_file
  carpet = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, space_after_headers: true, strikethrough: true, fenced_code_blocks: true, tables: true, highlight: true)
  html = carpet.render(ERB.new(File.read(md_file)).result)
  doc = Nokogiri.parse("<html><body><div class=content>#{html}</div></body></html>").css('div.content').first
  
  # apply syntax highlighting
  idx = 0
  doc.css('code').each do |code_element|
    code = code_element.text
    scanned = CodeRay.scan(code.sub(/\# render.*/, '').strip, :ruby)
    if code_element.parent.name == 'pre'
      table = code_element.parent.replace(scanned.div(line_numbers: :table, css: :class))
      
      if code.lines.first.strip.start_with? "# render "
        preview_filename, scad_code = render_preview(code, md_file, idx)
        #File.open("./assets/scad-#{md_file}-#{idx}.scad", 'w') { |f| f.write(scad_code) }
        table.after "<p class=\"openscad-render\"><img src=\"#{preview_filename}\" alt=\"3D rendering of above Oozby code\"></p>"
      end
      idx += 1
      #table.
    else
      code_element.replace scanned.span(css: :class)
    end
  end
  
  # make headings in to anchorable ones
  doc.css('h1,h2,h3,h4,h5,h6').each do |heading|
    heading['id'] = hasher(heading.text)
  end
  
  doc.to_html
end

# process a markdown file in to html, applying erb to template, then embedding markdown content from parse method
def process md_file
  # calculate filenames
  html_file = md_file.sub(/\.md$/, '.html')
  template_file = ["./template-#{html_file}", "template.html"].find { |fn| File.file? fn }
  
  # parse template in to objects, then replace content div with 
  template = ERB.new(File.read(template_file))
  doc = Nokogiri.parse(template.result)
  doc.css('div.content')[0].replace(parse(md_file))
  File.open(html_file, 'w') { |f| f.write(doc.to_html) }
end

Dir['*.md'].each do |filename|
  process filename
end

# remove previous rendered code blocks
Dir['assets/autorender-*.png'].each do |filename|
  File.delete(filename) unless PreviewsRendered.include? filename
end
