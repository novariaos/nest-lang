# src/preprocessor.rb

require 'pathname'

class NestPreprocessor
  SourceLocation = Struct.new(:file, :line, :column)
  
  class PreprocessorError < StandardError
    attr_reader :file, :line
    
    def initialize(message, file = nil, line = nil)
      @file = file
      @line = line
      super(message)
    end
  end
  
  def initialize(nest_root = nil)
    @nest_root = nest_root || ENV['NestRoot'] || File.expand_path('../..', __FILE__)
    @lib_path = File.join(@nest_root, 'lib')
    @chunks = []
    @source_map = {}
    @processed_files = {}
    @current_global_line = 1
    @current_file = nil
    @prelude_included = false
    @main_warnings = []
  end
  
  def preprocess(source, filename = "input.nest")
    reset_state
    @current_file = filename
    
    include_prelude
    add_source_chunk(source, filename, 0)
    process_all_use_directives
    output_main_warnings
    
    final_source = combine_chunks
    
    source_map_func = lambda do |global_line, global_col = 1|
      loc = @source_map[global_line]
      if loc
        SourceLocation.new(loc[:file], loc[:line], loc[:col] || global_col)
      else
        SourceLocation.new(filename, global_line, global_col)
      end
    end
    
    [final_source, source_map_func]
  end
  
  private
  
  def reset_state
    @chunks = []
    @source_map = {}
    @current_global_line = 1
    @processed_files = {}
    @prelude_included = false
    @main_warnings = []
  end
  
  def output_main_warnings
    unique_warnings = @main_warnings.uniq { |w| [w[:file], w[:line]] }
    
    unique_warnings.each do |warning|
      if defined?(Reporter) && Reporter.respond_to?(:warning)
        Reporter.warning(
          "function 'main' found in included file",
          line: warning[:line],
          column: warning[:column],
          length: 4,
          note: "file '#{warning[:file]}' contains a 'main' function",
          help: "main should only be defined in the root program file",
          file: warning[:file]
        )
      else
        warn "Warning: #{warning[:file]}:#{warning[:line]}: function 'main' found in included file"
      end
    end
  end
  
  def check_for_main(content, file_path)
    if @processed_files[file_path] && @processed_files[file_path][:checked]
      return
    end
    
    @processed_files[file_path] ||= {}
    @processed_files[file_path][:checked] = true
    
    content.lines.each_with_index do |line, idx|
      if match = line.match(/^\s*proc\s+main\s*\(/)
        column = match.begin(0) + 1
        @main_warnings << {
          file: file_path,
          line: idx + 1,
          column: column
        }
      end
    end
  end
  
  def include_prelude
    return if @prelude_included
    
    prelude_path = File.join(@lib_path, 'prelude.nest')
    
    if File.exist?(prelude_path)
      @prelude_included = true
      abs_path = File.realpath(prelude_path) rescue prelude_path
      @processed_files[abs_path] = { checked: false, included: true }
      
      content = File.read(prelude_path)
      check_for_main(content, abs_path)
      insert_source_at_position(nil, nil, content, abs_path, 0, at_beginning: true)
    else
      if defined?(Reporter) && Reporter.respond_to?(:warning)
        Reporter.warning(
          "prelude.nest not found",
          line: 1,
          column: 1,
          note: "expected at '#{prelude_path}'",
          help: "ensure NestRoot is set correctly or reinstall the standard library",
          file: @current_file
        )
      else
        warn "Warning: prelude.nest not found at #{prelude_path}"
      end
    end
  end
  
  def add_source_chunk(content, file_path, base_line, virtual: false)
    lines = content.lines.map(&:chomp)
    chunk_start_line = @current_global_line
    
    lines.each_with_index do |line, idx|
      global_line = chunk_start_line + idx
      @source_map[global_line] = {
        file: file_path,
        line: base_line + idx + 1,
        col: 1
      }
    end
    
    @chunks << {
      lines: lines,
      file: file_path,
      start_global: chunk_start_line,
      base_line: base_line,
      virtual: virtual
    }
    
    @current_global_line += lines.size
  end
  
  def insert_source_at_position(chunk, line_idx, content, file_path, base_line, at_beginning: false)
    new_lines = content.lines.map(&:chomp)
    
    unless @processed_files[file_path] && @processed_files[file_path][:checked]
      check_for_main(content, file_path)
    end
    
    if at_beginning
      new_chunk_start = 1
      shift = new_lines.size
      
      new_source_map = {}
      @source_map.each do |global_line, loc|
        new_source_map[global_line + shift] = loc
      end
      @source_map = new_source_map
      
      @chunks.each do |ch|
        ch[:start_global] += shift
      end
      
      @current_global_line += shift
      
      @chunks.unshift({
        lines: new_lines,
        file: file_path,
        start_global: 1,
        base_line: base_line,
        virtual: false
      })
      
      new_lines.each_with_index do |_line, idx|
        global_line = 1 + idx
        @source_map[global_line] = {
          file: file_path,
          line: base_line + idx + 1,
          col: 1
        }
      end
    else
      new_chunk_start = chunk[:start_global] + line_idx + 1
      shift = new_lines.size
      
      new_source_map = {}
      @source_map.each do |global_line, loc|
        if global_line >= new_chunk_start
          new_source_map[global_line + shift] = loc
        else
          new_source_map[global_line] = loc
        end
      end
      @source_map = new_source_map
      
      found = false
      @chunks.each do |ch|
        if found || ch == chunk
          found = true
          next if ch == chunk
          ch[:start_global] += shift
        end
      end
      
      @current_global_line += shift
      
      before_lines = chunk[:lines][0..line_idx]
      after_lines = chunk[:lines][(line_idx + 1)..-1]
      
      new_chunk = {
        lines: new_lines,
        file: file_path,
        start_global: new_chunk_start,
        base_line: base_line,
        virtual: false
      }
      
      new_lines.each_with_index do |_line, idx|
        global_line = new_chunk_start + idx
        @source_map[global_line] = {
          file: file_path,
          line: base_line + idx + 1,
          col: 1
        }
      end
      
      chunk[:lines] = before_lines
      
      index = @chunks.index(chunk)
      @chunks.insert(index + 1, new_chunk)
      
      if after_lines.any?
        after_chunk = {
          lines: after_lines,
          file: chunk[:file],
          start_global: new_chunk_start + new_lines.size,
          base_line: chunk[:base_line] + line_idx + 1,
          virtual: chunk[:virtual]
        }
        
        after_lines.each_with_index do |line, idx|
          global_line = after_chunk[:start_global] + idx
          @source_map[global_line] = {
            file: chunk[:file],
            line: after_chunk[:base_line] + idx + 1,
            col: 1
          }
        end
        
        @chunks.insert(index + 2, after_chunk)
      end
    end
  end
  
  def include_file(path, parent_file = nil, parent_line = nil)
    full_path = File.expand_path(path)
    
    if @processed_files[full_path] && @processed_files[full_path][:included]
      return
    end
    
    unless File.exist?(full_path)
      if defined?(Reporter) && Reporter.respond_to?(:error)
        Reporter.error(
          "cannot find file '#{path}'",
          line: parent_line || 1,
          column: 1,
          note: "searched in: #{File.dirname(full_path)}",
          help: "check that the file exists and the path is correct",
          file: parent_file || @current_file
        )
      else
        raise PreprocessorError.new(
          "cannot find file '#{path}'",
          parent_file || @current_file,
          parent_line || 1
        )
      end
    end
    
    @processed_files[full_path] ||= {}
    @processed_files[full_path][:included] = true
    
    content = File.read(full_path)
    
    unless @processed_files[full_path][:checked]
      check_for_main(content, full_path)
    end
  end
  
  def process_all_use_directives
    changed = true
    iteration = 0
    max_iterations = 100
    
    while changed && iteration < max_iterations
      changed = false
      iteration += 1
      
      @chunks.each do |chunk|
        next if chunk[:virtual]
        next if chunk[:file] == File.join(@lib_path, 'prelude.nest')
        
        chunk[:lines].each_with_index do |line, idx|
          stripped = line.strip
          next if stripped.empty?
          next if stripped.start_with?('//')
          next if stripped.start_with?('/*')
          
          if match = line.match(/^\s*use\s+"([^"]+)"\s*;?\s*$/)
            path = match[1]
            global_line = chunk[:start_global] + idx
            
            puts "[DEBUG] Found use directive: #{path} at global line #{global_line}" if ENV['NEST_DEBUG']
            
            if path.end_with?('.nest')
              base_dir = File.dirname(chunk[:file])
              full_path = File.expand_path(path, base_dir)
            else
              full_path = File.join(@lib_path, "#{path}.nest")
            end
            
            already_included = @processed_files[full_path] && @processed_files[full_path][:included]
            
            unless already_included
              puts "[DEBUG] Including file: #{full_path}" if ENV['NEST_DEBUG']
              
              unless File.exist?(full_path)
                if defined?(Reporter) && Reporter.respond_to?(:error)
                  Reporter.error(
                    "cannot find file '#{path}'",
                    line: idx + 1,
                    column: match.begin(0) + 1,
                    length: match[0].length,
                    note: "searched in: #{File.dirname(full_path)}",
                    help: "check that the file exists and the path is correct",
                    file: chunk[:file]
                  )
                else
                  raise PreprocessorError.new(
                    "cannot find file '#{path}'",
                    chunk[:file],
                    idx + 1
                  )
                end
              end
              
              content = File.read(full_path)
              
              @processed_files[full_path] ||= {}
              @processed_files[full_path][:included] = true
              
              unless @processed_files[full_path][:checked]
                check_for_main(content, full_path)
              end
              
              insert_source_at_position(chunk, idx, content, full_path, 0)
            end
            
            chunk[:lines][idx] = ""
            changed = true
          end
        end
      end
    end
    
    if iteration >= max_iterations
      if defined?(Reporter) && Reporter.respond_to?(:internal_error)
        Reporter.internal_error(
          "preprocessor exceeded maximum iterations (#{max_iterations})",
          file: @current_file
        )
      else
        warn "Error: preprocessor exceeded maximum iterations (#{max_iterations})"
      end
    end
    
    puts "[DEBUG] Processed #{iteration} iteration(s)" if ENV['NEST_DEBUG']
  end
  
  def combine_chunks
    @chunks.map { |chunk| chunk[:lines].join("\n") }.join("\n")
  end
  
  def find_source_location(global_line)
    @source_map[global_line]
  end
end