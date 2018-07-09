PreOutputColors = {
  30 => 'color:black;',
  31 => 'color:red;',
  32 => 'color:green;',
  33 => 'color:yellow;',
  34 => 'color:#88F;',
  35 => 'color:magenta;',
  36 => 'color:cyan;',
  37 => 'color:white;',
  39 => 'color:inherit;',
  40 => 'background-color:black;',
  41 => 'background-color:red;',
  42 => 'background-color:green;',
  43 => 'background-color:yellow;',
  44 => 'background-color:#88F;',
  45 => 'background-color:magenta;',
  46 => 'background-color:cyan;',
  47 => 'background-color:white;',
  49 => 'background-color:transparent;',
}
module PreOutput
  extend self

  def p(*args)
    args.each { |arg| puts_pre(arg.inspect) }
  end

  def puts(*args)
    args.each { |arg| puts_pre(arg) }
  end

  def puts_pre(string)
    string = PreOutput.pre_wrap(string)
    string = PreOutput.replace_ansi_color_codes(string)
    $stdout.print(string)
  end

  def self.pre_wrap(string)
    require 'erb'
    %{<pre style="margin:0;background-color:#333;color:#ddd;overflow-x:auto;">#{ERB::Util.h(string)}</pre>\n}
  end

  def self.replace_ansi_color_codes(string)
    ansi_sequence_regexp = %r{\e\[(?:(\d+)\;)*(\d+)\m}
    open = false

    string = string.gsub(ansi_sequence_regexp) do |match|
      numbers = match.match(ansi_sequence_regexp).to_a.compact.map(&:to_i)
      replace = ''
      if numbers.first == 0 && open
        numbers.shift
        replace << '</span>'
        open = false
      end

      styles = numbers.map do |number|
        PreOutputColors[number] #or "<b>#{number}</b>"
      end.compact

      replace << %Q{<span style="#{styles.join}">}
      open = true
      replace
    end

    string << '</span>' if open

    string
  end
end

if ARGV.any?{|a| a.include? 'TextMateFormatter'}
  RSpec.configuration.include PreOutput
  Object.prepend PreOutput
  # TablePrint::Config.max_width = 10_000
  # TablePrint::Config.io = Object.new.extend(PreOutput)
end

RSpec.describe Opal::SourceMap do
  let(:builder) do
    builder = Opal::Builder.new
    builder.build_str("    jsline1();\n    jsline2();\n    jsline3();", 'js_file.js')
    builder.build_str("  rbline1\n  rbline2\n  rbline3", 'rb_file.rb')
    builder.build_str("    jsline4();\n    jsline5();\n    jsline6();", 'js2_file.js')
    builder.build_str("  rbline4\n  rbline5\n  rbline6", 'rb2_file.rb')
    builder
  end

  let(:compiled) { builder.to_s }
  let(:source_map) { SourceMap::Map.from_json builder.source_map.to_json }
  let(:mappings) { source_map.send(:mappings) }

  it 'points to the correct source line' do
    compiled.lines.each.with_index { |line, index| puts "#{(index+1).to_s.rjust(3)} | #{line.chomp}" }
    puts '-------'
    mappings.each.with_index { |mapping, index| puts "#{index.to_s.rjust(3)} | #{mapping.inspect}" }

    expect_line_mapping(builder, 'jsline1(', original_file: 'js_file.js', original_line: 1, original_col: 0)
    expect_line_mapping(builder, 'jsline2(', original_file: 'js_file.js', original_line: 2, original_col: 0)
    expect_line_mapping(builder, 'jsline3(', original_file: 'js_file.js', original_line: 3, original_col: 0)
    expect_line_mapping(builder, '$rbline1(', original_file: 'rb_file.rb', original_line: 1, original_col: 2)
    expect_line_mapping(builder, '$rbline2(', original_file: 'rb_file.rb', original_line: 2, original_col: 2)
    expect_line_mapping(builder, '$rbline3(', original_file: 'rb_file.rb', original_line: 3, original_col: 2)
    expect_line_mapping(builder, 'jsline4(', original_file: 'js2_file.js', original_line: 4, original_col: 0)
    expect_line_mapping(builder, 'jsline5(', original_file: 'js2_file.js', original_line: 5, original_col: 0)
    expect_line_mapping(builder, 'jsline6(', original_file: 'js2_file.js', original_line: 6, original_col: 0)
    expect_line_mapping(builder, '$rbline4(', original_file: 'rb2_file.rb', original_line: 4, original_col: 2)
    expect_line_mapping(builder, '$rbline5(', original_file: 'rb2_file.rb', original_line: 5, original_col: 2)
    expect_line_mapping(builder, '$rbline6(', original_file: 'rb2_file.rb', original_line: 6, original_col: 2)
  end

  def expect_line_mapping(builder, line_matcher, original_file:, original_line:, original_col:)
    source, index = compiled.each_line.with_index.find { |source, index| source.include? line_matcher }
    line = index+1
    column = source.index(line_matcher)
    generated_position = SourceMap::Offset.new(line, column)
    mapped_position = source_map.bsearch(generated_position)
    p [line_matcher, :generated, generated_position, :original, mapped_position]
    expect([line_matcher, {
      source: mapped_position.source,
      line: mapped_position.original.line,
      column: mapped_position.original.column,
    }]).to eq([line_matcher, {
      source: original_file,
      line: original_line,
      column: original_col,
    }])
  end
end
