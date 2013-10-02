require 'redcarpet'
require 'nokogiri'
require 'coderay'
require 'erb'
require 'zlib' # for crc32 stuff
require '../lib/oozby'

# parse file as markdown, and add ruby syntax highlighting to code sections
def parse md_file
  carpet = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, space_after_headers: true, strikethrough: true, fenced_code_blocks: true, tables: true, highlight: true)
  html = carpet.render(ERB.new(File.read(md_file)).result)
  doc = Nokogiri.parse("<html><body><div class=content>#{html}</div></body></html>").css('div.content').first
  
  # apply syntax highlighting
  doc.css('code').each do |code_element|
    scanned = CodeRay.scan(code_element.text, :ruby)
    new_html_code = if code_element.parent.name == 'pre'
      code_element.parent.replace scanned.div(line_numbers: :table, css: :class)
    else
      code_element.replace scanned.span(css: :class)
    end
  end
  
  # make headings in to anchorable ones
  doc.css('h1,h2,h3,h4,h5,h6').each do |heading|
    heading['id'] = Zlib.crc32(heading.text).to_s(36)
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

# doc = Nokogiri.parse(File.read('template.html'))
# doc.css('div.content')[0].replace(parse('index.md'))
# File.open('index.html', 'w') { |f| f.write(doc.to_html) }

