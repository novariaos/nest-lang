require_relative 'lib/reporter'

class NestLexer
  TOKEN_TYPES = {
    KEYWORD_VAR: 'VAR',
    KEYWORD_IF: 'IF',
    KEYWORD_ELSE: 'ELSE',
    KEYWORD_WHILE: 'WHILE',
    KEYWORD_FOR: 'FOR',
    KEYWORD_BREAK: 'BREAK',
    KEYWORD_CONTINUE: 'CONTINUE',
    KEYWORD_PROC: 'PROC',
    KEYWORD_RETURN: 'RETURN',
    KEYWORD_TRUE: 'TRUE',
    KEYWORD_FALSE: 'FALSE',
    KEYWORD_NULL: 'NULL',
    KEYWORD_LEN: 'LEN',
    KEYWORD_STR: 'STR',
    KEYWORD_INT: 'INT',
    
    OPERATOR_ASSIGN: '=',
    OPERATOR_PLUS: '+',
    OPERATOR_MINUS: '-',
    OPERATOR_MULTIPLY: '*',
    OPERATOR_DIVIDE: '/',
    OPERATOR_MOD: '%',
    OPERATOR_EQ: '==',
    OPERATOR_NEQ: '!=',
    OPERATOR_LT: '<',
    OPERATOR_GT: '>',
    OPERATOR_LTE: '<=',
    OPERATOR_GTE: '>=',
    OPERATOR_AND: '&&',
    OPERATOR_OR: '||',
    OPERATOR_NOT: '!',
    
    DELIMITER_LPAREN: '(',
    DELIMITER_RPAREN: ')',
    DELIMITER_LBRACE: '{',
    DELIMITER_RBRACE: '}',
    DELIMITER_LBRACKET: '[',
    DELIMITER_RBRACKET: ']',
    DELIMITER_SEMICOLON: ';',
    DELIMITER_COMMA: ',',
    DELIMITER_COLON: ':',
    
    LITERAL_INTEGER: 'INTEGER',
    LITERAL_STRING: 'STRING',
    
    IDENTIFIER: 'IDENTIFIER',
    
    TOKEN_EOF: 'EOF'
  }
  
  Token = Struct.new(:type, :value, :line, :column, :file) do
    def to_s
      "#{type}(#{value.inspect}) at #{file}:#{line}:#{column}"
    end
    
    def location
      SourceLocation.new(file, line, column)
    end
  end
  
  def initialize(source, filename = "input.nest", source_map_func = nil)
    @source = source
    @filename = filename
    @source_map_func = source_map_func
    @position = 0
    @line = 1
    @column = 1
    @tokens = []
    @errors = []
    @warnings = []
    
    # Configure reporter
    if source_map_func
      Reporter.configure_with_mapper(source, filename, source_map_func)
    else
      Reporter.configure(source, filename)
    end
  end
  
  def tokenize
    @tokens = []
    until eof?
      token = next_token
      @tokens << token
      break if token.type == :TOKEN_EOF
    end
    
    @warnings.each { |w| puts w }
    
    if @errors.any?
      return nil
    end
    
    @tokens
  end
  
  def next_token
    skip_whitespace
    
    if eof?
      return Token.new(:TOKEN_EOF, nil, @line, @column, @filename)
    end
    
    start_line = @line
    start_col = @column
    start_file = get_current_file(start_line)
    
    case current_char
    when '('
      advance
      return Token.new(:DELIMITER_LPAREN, '(', start_line, start_col, start_file)
    when ')'
      advance
      return Token.new(:DELIMITER_RPAREN, ')', start_line, start_col, start_file)
    when '{'
      advance
      return Token.new(:DELIMITER_LBRACE, '{', start_line, start_col, start_file)
    when '}'
      advance
      return Token.new(:DELIMITER_RBRACE, '}', start_line, start_col, start_file)
    when '['
      advance
      return Token.new(:DELIMITER_LBRACKET, '[', start_line, start_col, start_file)
    when ']'
      advance
      return Token.new(:DELIMITER_RBRACKET, ']', start_line, start_col, start_file)
    when ';'
      advance
      return Token.new(:DELIMITER_SEMICOLON, ';', start_line, start_col, start_file)
    when ','
      advance
      return Token.new(:DELIMITER_COMMA, ',', start_line, start_col, start_file)
    when ':'
      advance
      return Token.new(:DELIMITER_COLON, ':', start_line, start_col, start_file)
    
    when '='
      advance
      if current_char == '='
        advance
        return Token.new(:OPERATOR_EQ, '==', start_line, start_col, start_file)
      end
      return Token.new(:OPERATOR_ASSIGN, '=', start_line, start_col, start_file)
    
    when '!'
      advance
      if current_char == '='
        advance
        return Token.new(:OPERATOR_NEQ, '!=', start_line, start_col, start_file)
      end
      return Token.new(:OPERATOR_NOT, '!', start_line, start_col, start_file)
    
    when '<'
      advance
      if current_char == '='
        advance
        return Token.new(:OPERATOR_LTE, '<=', start_line, start_col, start_file)
      end
      return Token.new(:OPERATOR_LT, '<', start_line, start_col, start_file)
    
    when '>'
      advance
      if current_char == '='
        advance
        return Token.new(:OPERATOR_GTE, '>=', start_line, start_col, start_file)
      end
      return Token.new(:OPERATOR_GT, '>', start_line, start_col, start_file)
    
    when '+'
      advance
      return Token.new(:OPERATOR_PLUS, '+', start_line, start_col, start_file)
    
    when '-'
      advance
      return Token.new(:OPERATOR_MINUS, '-', start_line, start_col, start_file)
    
    when '*'
      advance
      return Token.new(:OPERATOR_MULTIPLY, '*', start_line, start_col, start_file)
    
    when '/'
      advance
      if current_char == '/'
        skip_line_comment
        return next_token
      elsif current_char == '*'
        skip_block_comment
        return next_token
      end
      return Token.new(:OPERATOR_DIVIDE, '/', start_line, start_col, start_file)
    
    when '%'
      advance
      return Token.new(:OPERATOR_MOD, '%', start_line, start_col, start_file)
    
    when '&'
      advance
      if current_char == '&'
        advance
        return Token.new(:OPERATOR_AND, '&&', start_line, start_col, start_file)
      end
      error_at_position(
        "unexpected character `&`",
        start_line, start_col, 1,
        "did you mean `&&` for logical AND?",
        "use `&&` for logical AND operator"
      )
    
    when '|'
      advance
      if current_char == '|'
        advance
        return Token.new(:OPERATOR_OR, '||', start_line, start_col, start_file)
      end
      error_at_position(
        "unexpected character `|`",
        start_line, start_col, 1,
        "did you mean `||` for logical OR?",
        "use `||` for logical OR operator"
      )
    
    when '.'
      error_at_position(
        "unexpected dot operator",
        start_line, start_col, 1,
        "method calls are not supported",
        "use function calls instead: `str(i)` not `i.str()`"
      )
    
    when '"'
      return read_string
    
    when '0'..'9'
      return read_number
    
    when 'a'..'z', 'A'..'Z', '_'
      return read_identifier_or_keyword
    
    else
      char = current_char
      error_at_position(
        "unexpected character",
        start_line, start_col, 1,
        "`#{char}` is not valid in this context",
        "valid characters: letters, numbers, operators, and punctuation"
      )
    end
  end
  
  private
  
  def current_char
    @source[@position] || ''
  end
  
  def peek_char
    @source[@position + 1] || ''
  end
  
  def advance
    char = current_char
    @position += 1
    
    if char == "\n"
      @line += 1
      @column = 1
    else
      @column += 1
    end
    
    char
  end
  
  def eof?
    @position >= @source.length
  end
  
  def skip_whitespace
    while !eof? && current_char =~ /\s/
      advance
    end
  end
  
  def skip_line_comment
    while !eof? && current_char != "\n"
      advance
    end
  end
  
  def skip_block_comment
    start_line = @line
    start_col = @column - 1 
    
    advance
    
    while !eof?
      if current_char == '*' && peek_char == '/'
        advance 
        advance
        return
      end
      advance
    end
    
    error_at_position(
      "unterminated block comment",
      start_line, start_col, 2,
      "block comment started here but never closed with '*/'",
      "add '*/' to close the comment"
    )
  end
  
  def get_current_file(line)
    if @source_map_func
      loc = @source_map_func.call(line, 1)
      return loc.file if loc
    end
    @filename
  end
  
  def error_at_position(message, line, column, length = 1, note = nil, help = nil)
    if @source_map_func
      real_loc = @source_map_func.call(line, column)
      if real_loc
        Reporter.error(
          message,
          line: real_loc.line,
          column: real_loc.column,
          length: length,
          note: note,
          help: help,
          file: real_loc.file
        )
      else
        Reporter.error(
          message,
          line: line,
          column: column,
          length: length,
          note: note,
          help: help,
          file: @filename
        )
      end
    else
      Reporter.error(
        message,
        line: line,
        column: column,
        length: length,
        note: note,
        help: help,
        file: @filename
      )
    end
    @errors << message
    # Don't exit immediately, collect all errors
  end
  
  def warning_at_position(message, line, column, length = 1, note = nil, file = nil)
    if @source_map_func
      real_loc = @source_map_func.call(line, column)
      if real_loc
        warning_output = Reporter.warning(
          message,
          line: real_loc.line,
          column: real_loc.column,
          length: length,
          note: note,
          file: real_loc.file
        )
      else
        warning_output = Reporter.warning(
          message,
          line: line,
          column: column,
          length: length,
          note: note,
          file: file || @filename
        )
      end
    else
      warning_output = Reporter.warning(
        message,
        line: line,
        column: column,
        length: length,
        note: note,
        file: file || @filename
      )
    end
    @warnings << warning_output
  end
  
  def read_string
    start_line = @line
    start_col = @column
    start_file = get_current_file(start_line)
    advance # skip opening quote
    value = ""
    
    while !eof? && current_char != '"'
      if current_char == '\\'
        advance # skip backslash
        if eof?
          error_at_position(
            "unterminated string escape",
            start_line, start_col, 1,
            "escape sequence not completed",
            "use \\n, \\t, \\\\, or \\\""
          )
          return Token.new(:LITERAL_STRING, "", start_line, start_col, start_file)
        end
        
        case current_char
        when 'n'
          value << "\n"
        when 't'
          value << "\t"
        when '\\'
          value << "\\"
        when '"'
          value << '"'
        else
          warning_at_position(
            "unknown escape sequence",
            @line, @column, 1,
            "`\\#{current_char}` will be used as-is"
          )
          value << current_char
        end
        advance
      else
        value << current_char
        advance
      end
    end
    
    if eof?
      error_at_position(
        "unterminated string literal",
        start_line, start_col, 1,
        "string started here but never closed",
        "add closing `\"` before end of file"
      )
      return Token.new(:LITERAL_STRING, value, start_line, start_col, start_file)
    end
    
    advance # skip closing quote
    Token.new(:LITERAL_STRING, value, start_line, start_col, start_file)
  end
  
  def read_number
    start_line = @line
    start_col = @column
    start_file = get_current_file(start_line)
    value = ""
    
    while !eof? && current_char =~ /[0-9]/
      value << current_char
      advance
    end
    
    if value.length > 1 && value[0] == '0'
      warning_at_position(
        "leading zero in numeric literal",
        start_line, start_col, value.length,
        "this is allowed but may be confusing"
      )
    end
    
    Token.new(:LITERAL_INTEGER, value.to_i, start_line, start_col, start_file)
  end
  
  def read_identifier_or_keyword
    start_line = @line
    start_col = @column
    start_file = get_current_file(start_line)
    value = ""
    
    while !eof? && current_char =~ /[a-zA-Z0-9_]/
      value << current_char
      advance
    end
    
    # Check for identifiers starting with capital letter (convention warning)
    if value.match?(/^[A-Z]/) && !["true", "false", "null"].include?(value.downcase)
      warning_at_position(
        "identifier with capital letter",
        start_line, start_col, value.length,
        "by convention, identifiers start with lowercase"
      )
    end

    # Check for keywords
    case value
    when "var", "if", "else", "while", "for",
         "break", "continue", "proc", "return", "true",
         "false", "null", "len", "str", "int"
      Token.new(:"KEYWORD_#{value.upcase}", value, start_line, start_col, start_file)
    else
      Token.new(:IDENTIFIER, value, start_line, start_col, start_file)
    end
  end
end