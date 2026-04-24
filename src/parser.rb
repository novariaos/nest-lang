require_relative 'lib/reporter'

class NestParser
  class ParseError < StandardError
    attr_reader :token, :message, :line, :column
    
    def initialize(token, message)
      @token = token
      @message = message
      if token && token.respond_to?(:line) && token.respond_to?(:column)
        @line = token.line
        @column = token.column
        super(message)
      else
        @line = 1
        @column = 1
        super(message)
      end
    end
  end
  
  # AST Node classes
  class Node
    attr_reader :line, :column
    
    def initialize(line, column)
      @line = line
      @column = column
    end
  end
  
  class Program < Node
    attr_reader :statements
    
    def initialize(statements, line, column)
      super(line, column)
      @statements = statements
    end
  end
  
  class BlockStatement < Node
    attr_reader :statements
    
    def initialize(statements, line, column)
      super(line, column)
      @statements = statements
    end
  end
  
  class VariableDeclaration < Node
    attr_reader :name, :initializer
    
    def initialize(name, initializer, line, column)
      super(line, column)
      @name = name
      @initializer = initializer
    end
  end
  
  class Assignment < Node
    attr_reader :name, :value
    
    def initialize(name, value, line, column)
      super(line, column)
      @name = name
      @value = value
    end
  end
  
  class IfStatement < Node
    attr_reader :condition, :then_branch, :else_branch
    
    def initialize(condition, then_branch, else_branch, line, column)
      super(line, column)
      @condition = condition
      @then_branch = then_branch
      @else_branch = else_branch
    end
  end
  
  class WhileStatement < Node
    attr_reader :condition, :body
    
    def initialize(condition, body, line, column)
      super(line, column)
      @condition = condition
      @body = body
    end
  end
  
  class ForStatement < Node
    attr_reader :initializer, :condition, :increment, :body
    
    def initialize(initializer, condition, increment, body, line, column)
      super(line, column)
      @initializer = initializer
      @condition = condition
      @increment = increment
      @body = body
    end
  end
  
  class BreakStatement < Node
    def initialize(line, column)
      super(line, column)
    end
  end
  
  class ContinueStatement < Node
    def initialize(line, column)
      super(line, column)
    end
  end
  
  class ReturnStatement < Node
    attr_reader :value
    
    def initialize(value, line, column)
      super(line, column)
      @value = value
    end
  end
  
  class FunctionDeclaration < Node
    attr_reader :name, :parameters, :body
    
    def initialize(name, parameters, body, line, column)
      super(line, column)
      @name = name
      @parameters = parameters
      @body = body
    end
  end
  
  class FunctionCall < Node
    attr_reader :name, :arguments
    
    def initialize(name, arguments, line, column)
      super(line, column)
      @name = name
      @arguments = arguments
    end
  end
  
  class BinaryExpression < Node
    attr_reader :left, :operator, :right
    
    def initialize(left, operator, right, line, column)
      super(line, column)
      @left = left
      @operator = operator
      @right = right
    end
  end
  
  class UnaryExpression < Node
    attr_reader :operator, :operand
    
    def initialize(operator, operand, line, column)
      super(line, column)
      @operator = operator
      @operand = operand
    end
  end
  
  class IntegerLiteral < Node
    attr_reader :value
    
    def initialize(value, line, column)
      super(line, column)
      @value = value
    end
  end
  
  class StringLiteral < Node
    attr_reader :value
    
    def initialize(value, line, column)
      super(line, column)
      @value = value
    end
  end
  
  class BooleanLiteral < Node
    attr_reader :value
    
    def initialize(value, line, column)
      super(line, column)
      @value = value
    end
  end
  
  class NullLiteral < Node
    def initialize(line, column)
      super(line, column)
    end
  end
  
  class Identifier < Node
    attr_reader :name
    
    def initialize(name, line, column)
      super(line, column)
      @name = name
    end
  end
  
  class ArrayLiteral < Node
    attr_reader :elements
    
    def initialize(elements, line, column)
      super(line, column)
      @elements = elements
    end
  end
  
  class ArrayAccess < Node
    attr_reader :array, :index
    
    def initialize(array, index, line, column)
      super(line, column)
      @array = array
      @index = index
    end
  end
  
  class LenFunction < Node
    attr_reader :argument
    
    def initialize(argument, line, column)
      super(line, column)
      @argument = argument
    end
  end
  
  class StrFunction < Node
    attr_reader :argument
    
    def initialize(argument, line, column)
      super(line, column)
      @argument = argument
    end
  end
  
  class IntFunction < Node
    attr_reader :argument
    
    def initialize(argument, line, column)
      super(line, column)
      @argument = argument
    end
  end
  
  class PrintStatement < Node
    attr_reader :value
    
    def initialize(value, line, column)
      super(line, column)
      @value = value
    end
  end
  
  def initialize(tokens, source = nil, filename = "input.nest")
    @tokens = tokens
    @position = 0
    @source = source
    @filename = filename
    @errors = []
    @has_errors = false
    
    if @source
      Reporter.configure(@source, @filename)
    end
  end
  
  def parse
    statements = parse_program
    
    if @has_errors || @errors.any?
      puts "\n#{Reporter::COLORS[:bold]}#{Reporter::COLORS[:red]}aborting due to #{@errors.size} previous error#{@errors.size == 1 ? '' : 's'}#{Reporter::COLORS[:reset]}\n"
      return nil
    end
    
    Program.new(statements, 1, 1)
  rescue ParseError => e
    nil
  end
  
  private
  
  def current_token
    @tokens[@position] if @position < @tokens.length
  end
  
  def peek_token
    @tokens[@position + 1] if @position + 1 < @tokens.length
  end
  
  def advance
    @position += 1
    current_token
  end
  
  def eof?
    @position >= @tokens.length || (current_token && current_token.type == :TOKEN_EOF)
  end
  
  def expect(type, value = nil)
    token = current_token
    
    if eof? || token.nil?
      @has_errors = true
      expected = value ? "'#{value}'" : type.to_s.downcase.gsub('_', ' ')
      Reporter.error(
        "unexpected end of file",
        line: 1,
        column: 1,
        length: 1,
        note: "expected #{expected}",
        help: case value
        when ';'
          "add ';' at the end of the statement"
        when ')'
          "close the parentheses with ')'"
        when '}'
          "close the block with '}'"
        when '{'
          "open a block with '{'"
        when ','
          "separate items with ','"
        else
          "check if the code is complete"
        end
      )
      raise ParseError.new(token, "unexpected end of file")
    end
    
    if value
      if token.type != type || token.value != value
        @has_errors = true
        help_message = case value
        when '='
          "use '=' for assignment"
        when '=='
          "use '==' for equality comparison"
        when '!='
          "use '!=' for inequality comparison"
        when ';'
          "add ';' at the end of the statement"
        when ')'
          "close the parentheses"
        when '}'
          "close the block"
        when '{'
          "open a block"
        when ','
          "separate items with commas"
        else
          "expected '#{value}' but found #{token.value.inspect}"
        end
        
        Reporter.error(
          "expected '#{value}'",
          line: token.line,
          column: token.column,
          length: token.value.to_s.length,
          note: "found #{token.value.inspect}",
          help: help_message
        )
        raise ParseError.new(token, "expected '#{value}'")
      end
    else
      if token.type != type
        @has_errors = true
        Reporter.error(
          "expected #{type.to_s.downcase.gsub('_', ' ')}",
          line: token.line,
          column: token.column,
          length: token.value.to_s.length,
          note: "found #{token.value.inspect}",
          help: "use the correct syntax for this construct"
        )
        raise ParseError.new(token, "expected #{type}")
      end
    end
    
    advance
    token
  end
  
  def match?(type, value = nil)
    return false if eof?
    token = current_token
    return false if token.nil?
    
    if value
      token.type == type && token.value == value
    else
      token.type == type
    end
  end
  
  def parse_program
    statements = []
    
    until eof?
      stmt = parse_statement
      statements << stmt if stmt
    end
    
    statements
  end
  
  def parse_statement
    if match?(:KEYWORD_PRINT)
      parse_print_statement
    elsif match?(:KEYWORD_VAR)
      parse_variable_declaration
    elsif match?(:KEYWORD_IF)
      parse_if_statement
    elsif match?(:KEYWORD_WHILE)
      parse_while_statement
    elsif match?(:KEYWORD_FOR)
      parse_for_statement
    elsif match?(:KEYWORD_BREAK)
      parse_break_statement
    elsif match?(:KEYWORD_CONTINUE)
      parse_continue_statement
    elsif match?(:KEYWORD_RETURN)
      parse_return_statement
    elsif match?(:KEYWORD_PROC)
      parse_function_declaration
    elsif match?(:IDENTIFIER)
      parse_identifier_statement
    elsif match?(:DELIMITER_SEMICOLON)
      advance
      nil
    else
      token = current_token
      if token.nil?
        @has_errors = true
        Reporter.error(
          "unexpected end of file",
          line: 1,
          column: 1,
          length: 1,
          note: "expected a statement",
          help: "add a valid statement before end of file"
        )
        raise ParseError.new(nil, "unexpected end of file")
      else
        @has_errors = true
        Reporter.error(
          "unexpected token",
          line: token.line,
          column: token.column,
          length: token.value.to_s.length,
          note: "cannot start a statement with #{token.value.inspect}",
          help: "check the syntax at this position"
        )
        raise ParseError.new(token, "unexpected token")
      end
    end
  end
  
  def parse_print_statement
    token = expect(:KEYWORD_PRINT)
    expect(:DELIMITER_LPAREN, '(')
    value = parse_expression
    expect(:DELIMITER_RPAREN, ')')
    expect(:DELIMITER_SEMICOLON, ';')
    
    PrintStatement.new(value, token.line, token.column)
  end
  
  def parse_variable_declaration
    var_token = expect(:KEYWORD_VAR)
    name_token = expect(:IDENTIFIER)
    expect(:OPERATOR_ASSIGN, '=')
    initializer = parse_expression
    expect(:DELIMITER_SEMICOLON, ';')
    
    VariableDeclaration.new(
      name_token.value,
      initializer,
      var_token.line,
      var_token.column
    )
  end
  
  def parse_if_statement
    if_token = expect(:KEYWORD_IF)
    expect(:DELIMITER_LPAREN, '(')
    condition = parse_expression
    expect(:DELIMITER_RPAREN, ')')
    then_branch = parse_block
    
    else_branch = nil
    if match?(:KEYWORD_ELSE)
      advance
      else_branch = parse_block
    end
    
    IfStatement.new(condition, then_branch, else_branch, if_token.line, if_token.column)
  end
  
  def parse_while_statement
    while_token = expect(:KEYWORD_WHILE)
    expect(:DELIMITER_LPAREN, '(')
    condition = parse_expression
    expect(:DELIMITER_RPAREN, ')')
    body = parse_block
    
    WhileStatement.new(condition, body, while_token.line, while_token.column)
  end
  
  def parse_for_statement
    for_token = expect(:KEYWORD_FOR)
    expect(:DELIMITER_LPAREN, '(')
    
    initializer = nil
    if match?(:KEYWORD_VAR)
      initializer = parse_variable_declaration
    elsif match?(:IDENTIFIER)
      name = expect(:IDENTIFIER)
      expect(:OPERATOR_ASSIGN, '=')
      value = parse_expression
      initializer = Assignment.new(name.value, value, name.line, name.column)
      expect(:DELIMITER_SEMICOLON, ';')
    else
      expect(:DELIMITER_SEMICOLON, ';')
    end
    
    condition = nil
    unless match?(:DELIMITER_SEMICOLON)
      condition = parse_expression
    end
    expect(:DELIMITER_SEMICOLON, ';')
    
    increment = nil
    unless match?(:DELIMITER_RPAREN)
      increment = parse_expression
    end
    expect(:DELIMITER_RPAREN, ')')
    
    body = parse_block
    
    ForStatement.new(initializer, condition, increment, body, for_token.line, for_token.column)
  end
  
  def parse_break_statement
    token = expect(:KEYWORD_BREAK)
    expect(:DELIMITER_SEMICOLON, ';')
    BreakStatement.new(token.line, token.column)
  end
  
  def parse_continue_statement
    token = expect(:KEYWORD_CONTINUE)
    expect(:DELIMITER_SEMICOLON, ';')
    ContinueStatement.new(token.line, token.column)
  end
  
  def parse_return_statement
    token = expect(:KEYWORD_RETURN)
    value = nil
    unless match?(:DELIMITER_SEMICOLON)
      value = parse_expression
    end
    expect(:DELIMITER_SEMICOLON, ';')
    ReturnStatement.new(value, token.line, token.column)
  end
  
  def parse_function_declaration
    proc_token = expect(:KEYWORD_PROC)
    name_token = expect(:IDENTIFIER)
    expect(:DELIMITER_LPAREN, '(')
    
    parameters = []
    unless match?(:DELIMITER_RPAREN)
      loop do
        param = expect(:IDENTIFIER)
        parameters << param.value
        break unless match?(:DELIMITER_COMMA)
        advance
      end
    end
    
    expect(:DELIMITER_RPAREN, ')')
    body = parse_block
    
    FunctionDeclaration.new(name_token.value, parameters, body, proc_token.line, proc_token.column)
  end
  
  def parse_identifier_statement
    if peek_token&.type == :OPERATOR_ASSIGN
      parse_assignment
    else
      expr = parse_expression
      expect(:DELIMITER_SEMICOLON, ';')
      expr
    end
  end
  
  def parse_assignment
    name_token = expect(:IDENTIFIER)
    expect(:OPERATOR_ASSIGN, '=')
    value = parse_expression
    expect(:DELIMITER_SEMICOLON, ';')
    
    Assignment.new(name_token.value, value, name_token.line, name_token.column)
  end
  
  def parse_block
    expect(:DELIMITER_LBRACE, '{')
    
    statements = []
    until match?(:DELIMITER_RBRACE) || eof?
      stmt = parse_statement
      statements << stmt if stmt
    end
    
    expect(:DELIMITER_RBRACE, '}')
    line = statements.first&.line || 1
    column = statements.first&.column || 1
    BlockStatement.new(statements, line, column)
  end
  
  def parse_expression(precedence = 0)
    parse_binary_expression(precedence)
  end
  
  def parse_binary_expression(min_precedence)
    left = parse_unary_expression
    
    while true
      return left if eof?
      token = current_token
      return left if token.nil?
      
      precedence = get_precedence(token.type)
      break if precedence < min_precedence
      
      advance
      right = parse_binary_expression(precedence + 1)
      left = BinaryExpression.new(left, token.value, right, token.line, token.column)
    end
    
    left
  end
  
  def get_precedence(token_type)
    case token_type
    when :OPERATOR_OR
      1
    when :OPERATOR_AND
      2
    when :OPERATOR_EQ, :OPERATOR_NEQ
      3
    when :OPERATOR_LT, :OPERATOR_GT, :OPERATOR_LTE, :OPERATOR_GTE
      4
    when :OPERATOR_PLUS, :OPERATOR_MINUS
      5
    when :OPERATOR_MULTIPLY, :OPERATOR_DIVIDE, :OPERATOR_MOD
      6
    else
      -1
    end
  end
  
  def parse_unary_expression
    if match?(:OPERATOR_NOT) || match?(:OPERATOR_MINUS)
      token = current_token
      advance
      operand = parse_unary_expression
      UnaryExpression.new(token.value, operand, token.line, token.column)
    else
      parse_primary_expression
    end
  end
  
  def parse_primary_expression
    token = current_token
    if token.nil?
      @has_errors = true
      Reporter.error(
        "unexpected end of file in expression",
        line: 1,
        column: 1,
        length: 1,
        note: "expression is incomplete",
        help: "complete the expression with a value or sub-expression"
      )
      raise ParseError.new(nil, "unexpected end of file")
    end
    
    case token.type
    when :LITERAL_INTEGER
      advance
      IntegerLiteral.new(token.value, token.line, token.column)
    
    when :LITERAL_STRING
      advance
      StringLiteral.new(token.value, token.line, token.column)
    
    when :KEYWORD_TRUE
      advance
      BooleanLiteral.new(true, token.line, token.column)
    
    when :KEYWORD_FALSE
      advance
      BooleanLiteral.new(false, token.line, token.column)
    
    when :KEYWORD_NULL
      advance
      NullLiteral.new(token.line, token.column)
    
    when :DELIMITER_LPAREN
      advance
      expr = parse_expression
      expect(:DELIMITER_RPAREN, ')')
      expr
    
    when :DELIMITER_LBRACKET
      parse_array_literal
    
    when :IDENTIFIER
      parse_identifier_or_call
    
    when :KEYWORD_LEN
      parse_len_function
    
    when :KEYWORD_STR
      parse_str_function
    
    when :KEYWORD_INT
      parse_int_function
    
    else
      @has_errors = true
      Reporter.error(
        "unexpected token in expression",
        line: token.line,
        column: token.column,
        length: token.value.to_s.length,
        note: "cannot use #{token.value.inspect} here",
        help: "expressions must start with literals, identifiers, or '('"
      )
      raise ParseError.new(token, "unexpected token in expression")
    end
  end
  
  def parse_array_literal
    start_token = expect(:DELIMITER_LBRACKET)
    elements = []
    
    unless match?(:DELIMITER_RBRACKET)
      loop do
        elements << parse_expression
        break unless match?(:DELIMITER_COMMA)
        advance
      end
    end
    
    expect(:DELIMITER_RBRACKET, ']')
    ArrayLiteral.new(elements, start_token.line, start_token.column)
  end
  
  def parse_identifier_or_call
    name_token = expect(:IDENTIFIER)
    
    if match?(:DELIMITER_LPAREN)
      parse_function_call(name_token)
    elsif match?(:DELIMITER_LBRACKET)
      parse_array_access(name_token)
    else
      Identifier.new(name_token.value, name_token.line, name_token.column)
    end
  end
  
  def parse_function_call(name_token)
    expect(:DELIMITER_LPAREN, '(')
    arguments = []
    
    unless match?(:DELIMITER_RPAREN)
      loop do
        arguments << parse_expression
        break unless match?(:DELIMITER_COMMA)
        advance
      end
    end
    
    expect(:DELIMITER_RPAREN, ')')
    FunctionCall.new(name_token.value, arguments, name_token.line, name_token.column)
  end
  
  def parse_array_access(name_token)
    expect(:DELIMITER_LBRACKET, '[')
    index = parse_expression
    expect(:DELIMITER_RBRACKET, ']')
    
    ArrayAccess.new(
      Identifier.new(name_token.value, name_token.line, name_token.column),
      index,
      name_token.line,
      name_token.column
    )
  end
  
  def parse_len_function
    token = expect(:KEYWORD_LEN)
    expect(:DELIMITER_LPAREN, '(')
    argument = parse_expression
    expect(:DELIMITER_RPAREN, ')')
    
    LenFunction.new(argument, token.line, token.column)
  end
  
  def parse_str_function
    token = expect(:KEYWORD_STR)
    expect(:DELIMITER_LPAREN, '(')
    argument = parse_expression
    expect(:DELIMITER_RPAREN, ')')
    
    StrFunction.new(argument, token.line, token.column)
  end
  
  def parse_int_function
    token = expect(:KEYWORD_INT)
    expect(:DELIMITER_LPAREN, '(')
    argument = parse_expression
    expect(:DELIMITER_RPAREN, ')')
    
    IntFunction.new(argument, token.line, token.column)
  end
end

class ASTPrinter
  def initialize(indent = 2)
    @indent = indent
  end
  
  def print(node, level = 0)
    indent = " " * (level * @indent)
    
    case node
    when NestParser::Program
      puts "#{indent}Program:"
      node.statements.each { |stmt| print(stmt, level + 1) }
    
    when NestParser::BlockStatement
      puts "#{indent}Block:"
      node.statements.each { |stmt| print(stmt, level + 1) }
    
    when NestParser::VariableDeclaration
      puts "#{indent}VariableDeclaration: #{node.name} ="
      print(node.initializer, level + 1)
    
    when NestParser::Assignment
      puts "#{indent}Assignment: #{node.name} ="
      print(node.value, level + 1)
    
    when NestParser::IfStatement
      puts "#{indent}If:"
      puts "#{indent}  Condition:"
      print(node.condition, level + 2)
      puts "#{indent}  Then:"
      print(node.then_branch, level + 2)
      if node.else_branch
        puts "#{indent}  Else:"
        print(node.else_branch, level + 2)
      end
    
    when NestParser::WhileStatement
      puts "#{indent}While:"
      puts "#{indent}  Condition:"
      print(node.condition, level + 2)
      puts "#{indent}  Body:"
      print(node.body, level + 2)
    
    when NestParser::ForStatement
      puts "#{indent}For:"
      puts "#{indent}  Initializer:"
      print(node.initializer, level + 2) if node.initializer
      puts "#{indent}  Condition:"
      print(node.condition, level + 2) if node.condition
      puts "#{indent}  Increment:"
      print(node.increment, level + 2) if node.increment
      puts "#{indent}  Body:"
      print(node.body, level + 2)
    
    when NestParser::BreakStatement
      puts "#{indent}Break"
    
    when NestParser::ContinueStatement
      puts "#{indent}Continue"
    
    when NestParser::ReturnStatement
      puts "#{indent}Return:"
      print(node.value, level + 1) if node.value
    
    when NestParser::FunctionDeclaration
      puts "#{indent}Function: #{node.name}(#{node.parameters.join(', ')})"
      print(node.body, level + 1)
    
    when NestParser::FunctionCall
      puts "#{indent}Call: #{node.name}"
      puts "#{indent}  Arguments:"
      node.arguments.each { |arg| print(arg, level + 2) }
    
    when NestParser::PrintStatement
      puts "#{indent}Print:"
      print(node.value, level + 1)
    
    when NestParser::BinaryExpression
      puts "#{indent}Binary: #{node.operator}"
      puts "#{indent}  Left:"
      print(node.left, level + 2)
      puts "#{indent}  Right:"
      print(node.right, level + 2)
    
    when NestParser::UnaryExpression
      puts "#{indent}Unary: #{node.operator}"
      print(node.operand, level + 1)
    
    when NestParser::IntegerLiteral
      puts "#{indent}Integer: #{node.value}"
    
    when NestParser::StringLiteral
      puts "#{indent}String: #{node.value.inspect}"
    
    when NestParser::BooleanLiteral
      puts "#{indent}Boolean: #{node.value}"
    
    when NestParser::NullLiteral
      puts "#{indent}Null"
    
    when NestParser::Identifier
      puts "#{indent}Identifier: #{node.name}"
    
    when NestParser::ArrayLiteral
      puts "#{indent}Array:"
      node.elements.each { |elem| print(elem, level + 1) }
    
    when NestParser::ArrayAccess
      puts "#{indent}ArrayAccess:"
      puts "#{indent}  Array:"
      print(node.array, level + 2)
      puts "#{indent}  Index:"
      print(node.index, level + 2)
    
    when NestParser::LenFunction
      puts "#{indent}Len:"
      print(node.argument, level + 1)
    
    when NestParser::StrFunction
      puts "#{indent}Str:"
      print(node.argument, level + 1)
    
    when NestParser::IntFunction
      puts "#{indent}Int:"
      print(node.argument, level + 1)
    end
  end
end