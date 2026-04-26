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
      warning: { color: :yellow, name: "warning", symbol: "⚠" },
      note: { color: :cyan, name: "note", symbol: "ℹ" },
      help: { color: :green, name: "help", symbol: "→" },
      internal: { color: :magenta, name: "internal error", symbol: "⚡" }
    }
    
    class << self
      attr_accessor :source_lines, :filename
      
      def configure(source, filename = "input.nest")
        @source_lines = source.is_a?(String) ? source.lines.map(&:chomp) : source
        @filename = filename
      end
      
      def error(message, line:, column:, length: 1, note: nil, help: nil)
        emit(:error, message, line, column, length, note, help)
      end
      
      def warning(message, line:, column:, length: 1, note: nil, help: nil)
        emit(:warning, message, line, column, length, note)
      end
      
      def note(message, line:, column:, length: 1)
        emit(:note, message, line, column, length)
      end
      
      def internal_error(message, line: nil, column: nil)
        emit(:internal, message, line || 1, column || 1, 1)
      end
      
      def emit_error_group(errors)
        errors.each do |err|
          error(err[:message], 
                line: err[:line], 
                column: err[:column],
                length: err[:length] || 1,
                note: err[:note],
                help: err[:help])
        end
      end
      
      private
      
      def emit(level, message, line, column, length, note = nil, help = nil)
        output = String.new
        color = COLORS[LEVELS[level][:color]]
        name = LEVELS[level][:name]
        symbol = LEVELS[level][:symbol]
        
        # Header
        output << "#{COLORS[:bold]}#{color} #{name}#{COLORS[:reset]}"
        output << "#{COLORS[:dim]}:#{COLORS[:reset]} "
        output << "#{message}\n"
        
        # Pos
        output << "#{COLORS[:dim]} --> #{COLORS[:reset]}"
        output << "#{COLORS[:cyan]}#{@filename}:#{line}:#{column}#{COLORS[:reset]}\n"
        
        # Line with code
        if @source_lines && line <= @source_lines.length
          source_line = @source_lines[line - 1]
          output << "#{COLORS[:dim]}  |#{COLORS[:reset]}\n"
          output << "#{COLORS[:blue]}#{line} #{COLORS[:dim]}|#{COLORS[:reset]} "
          output << "#{source_line}\n"
          
          # Pointer
          output << "#{COLORS[:dim]}  | #{COLORS[:reset]}"
          
          if column > 0 && column <= source_line.length
            output << "#{' ' * (column - 1)}"
            output << "#{color}^#{COLORS[:reset]}"
            output << "#{color}#{'~' * (length - 1)}#{COLORS[:reset]}" if length > 1
          else
            output << "#{color}^#{COLORS[:reset]}"
          end
          
          output << " #{COLORS[:dim]}#{note}#{COLORS[:reset]}" if note
          output << "\n"
        end
        
        # Hint
        output << "#{COLORS[:dim]}  = #{LEVELS[:help][:name]}: #{COLORS[:reset]}#{help}\n" if help
        
        puts output
        output
      end
    end
  end
  
  class SourceLocation
    attr_reader :line, :column, :length
    
    def initialize(line, column, length = 1)
      @line = line
      @column = column
      @length = length
    end
    
    def to_h
      { line: @line, column: @column, length: @length }
    end
  end