module Reporter
  COLORS = {
    red: "\e[31m",
    green: "\e[32m",
    yellow: "\e[33m",
    blue: "\e[34m",
    magenta: "\e[35m",
    cyan: "\e[36m",
    bold: "\e[1m",
    dim: "\e[2m",
    reset: "\e[0m"
  }
  
  LEVELS = {
    error: { color: :red, name: "error", symbol: nil },
    warning: { color: :yellow, name: "warning", symbol: nil },
    note: { color: :cyan, name: "note", symbol: nil },
    help: { color: :green, name: "help", symbol: "→" },
    internal: { color: :magenta, name: "internal error", symbol: nil }
  }
  
  class << self
    attr_accessor :source_lines, :filename, :source_mapper, :source_cache
    
    def configure(source, filename = "input.nest")
      @source_lines = source.is_a?(String) ? source.lines.map(&:chomp) : source
      @filename = filename
      @source_mapper = nil
      @source_cache = {}
    end
    
    def configure_with_mapper(source, filename, mapper)
      @source_lines = source.is_a?(String) ? source.lines.map(&:chomp) : source
      @filename = filename
      @source_mapper = mapper
      @source_cache = {}
    end
    
    def get_source_line(file, line)
      return nil unless file && line
      return nil unless @source_cache
      
      @source_cache[file] ||= {}
      
      if @source_cache[file][:lines]
        return @source_cache[file][:lines][line - 1] if line <= @source_cache[file][:lines].size
      end
      
      begin
        if File.exist?(file)
          lines = File.read(file).lines.map(&:chomp)
          @source_cache[file] = { lines: lines, mtime: File.mtime(file) }
          return lines[line - 1] if line <= lines.size
        end
      rescue => e
      end
      
      nil
    end
    
    def error(message, line:, column:, length: 1, note: nil, help: nil, file: nil)
      emit(:error, message, line, column, length, note, help, file)
    end
    
    def warning(message, line:, column:, length: 1, note: nil, help: nil, file: nil)
      emit(:warning, message, line, column, length, note, help, file)
    end
    
    def note(message, line:, column:, length: 1, file: nil)
      emit(:note, message, line, column, length, nil, nil, file)
    end
    
    def internal_error(message, line: nil, column: nil, file: nil)
      emit(:internal, message, line || 1, column || 1, 1, nil, nil, file)
    end
    
    def emit_error_group(errors)
      errors.each do |err|
        error(err[:message], 
              line: err[:line], 
              column: err[:column],
              length: err[:length] || 1,
              note: err[:note],
              help: err[:help],
              file: err[:file])
      end
    end
    
    def clear_cache
      @source_cache = {}
    end
    
    private
    
    def emit(level, message, line, column, length, note, help, file = nil)
      output = String.new
      color = COLORS[LEVELS[level][:color]]
      name = LEVELS[level][:name]
      symbol = LEVELS[level][:symbol]
      
      actual_file = file || @filename
      actual_line = line
      actual_column = column
      
      if @source_mapper && !file
        real_loc = @source_mapper.call(line, column)
        if real_loc
          actual_file = real_loc.file
          actual_line = real_loc.line
          actual_column = real_loc.column
        end
      end
      
      output << "#{COLORS[:bold]}#{color}#{symbol ? " #{symbol}" : ""} #{name}#{COLORS[:reset]}#{COLORS[:dim]}:#{COLORS[:reset]} #{message}\n"
      
      output << "#{COLORS[:dim]}-->#{COLORS[:reset]} #{COLORS[:cyan]}#{actual_file}:#{actual_line}:#{actual_column}#{COLORS[:reset]}\n"
      
      source_line = get_source_line(actual_file, actual_line)
      
      if source_line
        output << "#{COLORS[:blue]}#{actual_line} #{COLORS[:dim]}|#{COLORS[:reset]} #{source_line}\n"
        
        if actual_column > 0 && actual_column <= source_line.length
          output << "  #{COLORS[:dim]}|#{COLORS[:reset]} #{' ' * (actual_column - 1)}#{color}^#{COLORS[:reset]}"
          output << "#{color}#{'~' * (length - 1)}#{COLORS[:reset]}" if length > 1
        else
          output << "  #{COLORS[:dim]}|#{COLORS[:reset]} #{color}^#{COLORS[:reset]}"
        end
        
        output << " #{COLORS[:dim]}#{note}#{COLORS[:reset]}" if note
        output << "\n"
      elsif note
        output << "  #{COLORS[:dim]}|#{COLORS[:reset]} #{note}\n"
      end
      
      if help
        output << "  #{COLORS[:dim]}= #{LEVELS[:help][:name]}: #{COLORS[:reset]}#{help}\n"
      end
      
      $stderr.print output
      output
    end
  end
end

class SourceLocation
  attr_reader :file, :line, :column
  
  def initialize(file, line, column)
    @file = file
    @line = line
    @column = column
  end
  
  def to_s
    "#{@file}:#{@line}:#{@column}"
  end
  
  def inspect
    "<SourceLocation #{to_s}>"
  end
end