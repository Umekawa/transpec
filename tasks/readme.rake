# coding: utf-8

desc 'Generate README.md'
task :readme do
  puts 'Generating README.md...'
  File.write('README.md', generate_readme)
  puts 'Done.'
end

namespace :readme do
  task :check do
    unless File.read('README.md') == generate_readme
      fail <<-END.gsub(/^\s+\|/, '').chomp
        |README.md and README.md.erb are out of sync!
        |If you need to modify the content of README.md:
        |  * Edit README.md.erb.
        |  * Run `bundle exec rake readme`.
        |  * Commit both files.
      END
    end
  end
end

def generate_readme
  require 'erb'
  require 'transpec'
  require 'transpec/cli'

  readme = File.read('README.md.erb')
  erb = ERB.new(readme, nil, '-')
  erb.result(binding)
end

def convert(source, options = {})
  require 'rspec/mocks/standalone'
  require File.join(Transpec.root, 'spec/support/file_helper')

  cli = Transpec::CLI.new
  cli.project.stub(:rspec_version).and_return(options[:rspec_version]) if options[:rspec_version]

  source = wrap_source(source, options[:wrap_with])
  converted_source = nil

  in_isolated_env do
    FileHelper.create_file('spec/example_spec.rb', source)
    cli.run(options[:cli] || [])
    converted_source = File.read('spec/example_spec.rb')
  end

  unwrap_source(converted_source, options[:wrap_with])
end

def wrap_source(source, wrapper)
  source = "it 'is example' do\n" + source + "end\n" if wrapper == :example

  if [:example, :group].include?(wrapper)
    source = "describe 'example group' do\n" + source + "end\n"
  end

  source
end

def unwrap_source(source, wrapper)
  return source unless wrapper

  unwrap_count = case wrapper
                 when :group then 1
                 when :example then 2
                 end

  lines = source.lines.to_a

  unwrap_count.times do
    lines = lines[1..-2]
  end

  lines.join('')
end

def in_isolated_env
  require 'stringio'
  require 'tmpdir'

  original_stdout = $stdout
  $stdout = StringIO.new

  Dir.mktmpdir do |tmpdir|
    Dir.chdir(tmpdir) do
      yield
    end
  end
ensure
  $stdout = original_stdout
end

def select_sections(content, header_level, *section_names)
  header_pattern = pattern_for_header_level(header_level)
  sections = content.each_line.slice_before(header_pattern)

  sections.select do |section|
    header_line = section.first
    section_names.any? { |name| header_line.include?(name) }
  end
end

def table_of_contents(lines, header_level)
  header_pattern = pattern_for_header_level(header_level)

  titles = lines.map do |line|
    next unless line.match(header_pattern)
    line.sub(/^[#\s]*/, '').chomp
  end.compact

  titles.map do |title|
    anchor = '#' + title.gsub(/[^\w_\- ]/, '').downcase.gsub(' ', '-')
    "* [#{title}](#{anchor})"
  end.join("\n")
end

def pattern_for_header_level(level)
  /^#{'#' * level}[^#]/
end

def validate_syntax_type_table(markdown_table, types_in_code)
  types_in_doc = markdown_table.lines.map do |line|
    first_column = line.split('|').first
    first_column.gsub(/[^\w]/, '').to_sym
  end.sort

  types_in_code.sort!

  unless types_in_doc == types_in_code
    types_missing_description = types_in_code - types_in_doc
    fail "No descriptions for syntax types #{types_missing_description}"
  end
end
