# src/semantic.rb

require_relative 'lib/reporter'

class NestSemanticAnalyzer
  def initialize(ast)
    @ast = ast
    @has_main = false
    @main_location = nil
    @functions = {}
    @errors = []
    @current_function = nil
    @break_depth = 0
    @continue_depth = 0
    @processed_nodes = 0
    
    # Built-in functions that don't need to be declared
    @builtin_functions = {
      'open'  => { parameters: 1, returns: :int },
      'read'  => { parameters: 2, returns: :string },
      'write' => { parameters: 2, returns: :int },
      'delete'=> { parameters: 1, returns: nil },
      'len'   => { parameters: 1, returns: :int },
      'str'   => { parameters: 1, returns: :string },
      'int'   => { parameters: 1, returns: :int },
      'sbrk' => { parameters: 1, returns: :int},
    }
  end

  def analyze
    return nil if @ast.nil?
    
    puts "[DEBUG] Analyzing AST..." if ENV['NEST_DEBUG']
    analyze_program(@ast)
    
    puts "[DEBUG] Found main? #{@has_main}" if ENV['NEST_DEBUG']
    puts "[DEBUG] Functions found: #{@functions.keys}" if ENV['NEST_DEBUG']
    
    unless @has_main
      error_msg = "missing required function 'main'"
      help_msg = "add 'proc main() { ... }' at the top level"
      
      if @functions.any?
        help_msg = "found functions: #{@functions.keys.join(', ')}. Did you forget to declare 'main'?"
      end
      
      Reporter.error(
        error_msg,
        line: 1,
        column: 1,
        length: 1,
        note: "program entry point not found",
        help: help_msg
      )
      @errors << "missing main function"
    end
    
    if @errors.any?
      puts "\n#{Reporter::COLORS[:bold]}#{Reporter::COLORS[:red]}semantic analysis failed due to #{@errors.size} error#{@errors.size == 1 ? '' : 's'}#{Reporter::COLORS[:reset]}\n"
      return nil
    end
    
    true
  end

  private

  def analyze_program(node)
    case node
    when NestParser::Program
      node.statements.each { |stmt| analyze_statement(stmt) }
    when Array
      node.each { |stmt| analyze_statement(stmt) }
    else
      analyze_statement(node) if node.respond_to?(:is_a?)
    end
  end

  def analyze_statement(stmt)
    return unless stmt
    
    case stmt
    when NestParser::FunctionDeclaration
      analyze_function_declaration(stmt)
    when NestParser::VariableDeclaration
      analyze_variable_declaration(stmt)
    when NestParser::Assignment
      analyze_assignment(stmt)
    when NestParser::BlockStatement
      analyze_block(stmt)
    when NestParser::IfStatement
      analyze_if_statement(stmt)
    when NestParser::WhileStatement
      analyze_while_statement(stmt)
    when NestParser::ForStatement
      analyze_for_statement(stmt)
    when NestParser::BreakStatement
      analyze_break_statement(stmt)
    when NestParser::ContinueStatement
      analyze_continue_statement(stmt)
    when NestParser::ReturnStatement
      analyze_return_statement(stmt)
    when NestParser::FunctionCall
      analyze_function_call(stmt)
    when NestParser::Expression, NestParser::BinaryExpression, NestParser::UnaryExpression
      analyze_expression(stmt)
    else
      # ignore
    end
  end

  def analyze_function_declaration(node)
    func_name = node.name
    
    puts "[DEBUG] Found function: #{func_name}" if ENV['NEST_DEBUG']
    
    if func_name == "main"
      @has_main = true
      @main_location = { line: node.line, column: node.column, file: node.file }
      
      if node.parameters.size > 0
        Reporter.error(
          "function 'main' should not have parameters",
          line: node.line,
          column: node.column,
          length: 4,
          note: "main must have zero parameters",
          help: "remove parameters from main function"
        )
        @errors << "main has parameters"
      end
    end
    
    # Check if function name conflicts with built-in
    if @builtin_functions[func_name]
      Reporter.error(
        "function '#{func_name}' conflicts with built-in function",
        line: node.line,
        column: node.column,
        length: func_name.length,
        note: "cannot override built-in function",
        help: "rename your function to something else"
      )
      @errors << "conflict with built-in function #{func_name}"
    end
    
    if @functions[func_name]
      existing = @functions[func_name][:node]
      Reporter.error(
        "function '#{func_name}' already declared",
        line: node.line,
        column: node.column,
        length: func_name.length,
        note: "previous declaration at #{existing.file}:#{existing.line}",
        help: "rename one of the functions or remove duplication"
      )
      @errors << "duplicate function #{func_name}"
    else
      @functions[func_name] = { parameters: node.parameters, node: node }
    end
    
    old_function = @current_function
    @current_function = func_name
    analyze_block(node.body) if node.body
    @current_function = old_function
  end

  def analyze_variable_declaration(node)
    analyze_expression(node.initializer) if node.initializer
  end

  def analyze_assignment(node)
    analyze_expression(node.value) if node.value
  end

  def analyze_block(node)
    return unless node && node.statements
    node.statements.each { |stmt| analyze_statement(stmt) }
  end

  def analyze_if_statement(node)
    analyze_expression(node.condition) if node.condition
    analyze_block(node.then_branch) if node.then_branch
    analyze_block(node.else_branch) if node.else_branch
  end

  def analyze_while_statement(node)
    analyze_expression(node.condition) if node.condition
    @break_depth += 1
    @continue_depth += 1
    analyze_block(node.body) if node.body
    @break_depth -= 1
    @continue_depth -= 1
  end

  def analyze_for_statement(node)
    if node.initializer
      case node.initializer
      when NestParser::VariableDeclaration
        analyze_variable_declaration(node.initializer)
      when NestParser::Assignment
        analyze_assignment(node.initializer)
      end
    end
    
    analyze_expression(node.condition) if node.condition
    analyze_expression(node.increment) if node.increment
    
    @break_depth += 1
    @continue_depth += 1
    analyze_block(node.body) if node.body
    @break_depth -= 1
    @continue_depth -= 1
  end

  def analyze_break_statement(node)
    if @break_depth == 0
      Reporter.error(
        "break statement outside loop",
        line: node.line,
        column: node.column,
        length: 5,
        note: "break can only be used inside loops",
        help: "move break inside a while or for loop"
      )
      @errors << "break outside loop"
    end
  end

  def analyze_continue_statement(node)
    if @continue_depth == 0
      Reporter.error(
        "continue statement outside loop",
        line: node.line,
        column: node.column,
        length: 8,
        note: "continue can only be used inside loops",
        help: "move continue inside a while or for loop"
      )
      @errors << "continue outside loop"
    end
  end

  def analyze_return_statement(node)
    unless @current_function
      Reporter.error(
        "return statement outside function",
        line: node.line,
        column: node.column,
        length: 6,
        note: "return can only be used inside functions",
        help: "move return inside a function body"
      )
      @errors << "return outside function"
      return
    end
    
    if node.value.nil?
      Reporter.error(
        "empty return statement",
        line: node.line,
        column: node.column,
        length: 6,
        note: "functions must return a value",
        help: "add return value: 'return 0;'"
      )
      @errors << "empty return"
    else
      analyze_expression(node.value)
    end
  end

  def analyze_function_call(node)
    # Check if it's a built-in function first
    if @builtin_functions[node.name]
      analyze_builtin_call(node)
      return
    end
    
    # Not a built-in, check user-defined functions
    unless @functions[node.name]
      # Don't error if it's a forward declaration (will be checked later)
      # But we can warn
      Reporter.warning(
        "function '#{node.name}' might be undefined",
        line: node.line,
        column: node.column,
        length: node.name.length,
        note: "function not declared before use",
        help: "ensure '#{node.name}' is declared somewhere"
      )
      return
    end
    
    func_info = @functions[node.name]
    param_count = func_info[:parameters].size
    arg_count = node.arguments.size
    
    if param_count != arg_count
      Reporter.error(
        "function '#{node.name}' expects #{param_count} argument#{param_count == 1 ? '' : 's'}, got #{arg_count}",
        line: node.line,
        column: node.column,
        length: node.name.length,
        note: "parameter count mismatch",
        help: "#{param_count > arg_count ? "add" : "remove"} #{(param_count - arg_count).abs} argument#{param_count - arg_count == 1 ? '' : 's'}"
      )
      @errors << "argument count mismatch for #{node.name}"
    end
    
    node.arguments.each { |arg| analyze_expression(arg) }
  end

  def analyze_builtin_call(node)
    func_info = @builtin_functions[node.name]
    param_count = func_info[:parameters]
    arg_count = node.arguments.size
    
    if node.name == 'print'
      if arg_count != 1
        Reporter.error(
          "built-in function 'print' expects 1 argument, got #{arg_count}",
          line: node.line,
          column: node.column,
          length: node.name.length,
          note: "parameter count mismatch",
          help: "print expects exactly one argument (string or expression)"
        )
        @errors << "argument count mismatch for built-in print"
      end
    elsif node.name == 'exit'
      if arg_count != 1
        Reporter.error(
          "built-in function 'exit' expects 1 argument, got #{arg_count}",
          line: node.line,
          column: node.column,
          length: node.name.length,
          note: "parameter count mismatch",
          help: "exit expects exit code (integer)"
        )
        @errors << "argument count mismatch for built-in exit"
      end
    else
      if param_count != arg_count
        Reporter.error(
          "built-in function '#{node.name}' expects #{param_count} argument#{param_count == 1 ? '' : 's'}, got #{arg_count}",
          line: node.line,
          column: node.column,
          length: node.name.length,
          note: "parameter count mismatch",
          help: "#{param_count > arg_count ? "add" : "remove"} #{(param_count - arg_count).abs} argument#{param_count - arg_count == 1 ? '' : 's'}"
        )
        @errors << "argument count mismatch for built-in #{node.name}"
      end
    end
    
    # Analyze each argument
    node.arguments.each { |arg| analyze_expression(arg) }
  end

  def analyze_expression(expr)
    return unless expr
    
    case expr
    when NestParser::BinaryExpression
      analyze_binary_expression(expr)
    when NestParser::UnaryExpression
      analyze_unary_expression(expr)
    when NestParser::FunctionCall
      analyze_function_call(expr)
    when NestParser::ArrayAccess
      analyze_array_access(expr)
    when NestParser::LenFunction
      analyze_len_function(expr)
    when NestParser::StrFunction
      analyze_expression(expr.argument) if expr.argument
    when NestParser::IntFunction
      analyze_expression(expr.argument) if expr.argument
    else
      # Literals and identifiers don't need analysis
      expr
    end
  end

  def analyze_binary_expression(node)
    analyze_expression(node.left) if node.left
    analyze_expression(node.right) if node.right
    
    if node.operator == '/' && node.right && is_zero_division_risk?(node.right)
      Reporter.warning(
        "potential division by zero",
        line: node.line,
        column: node.column,
        length: 1,
        note: "right operand is zero",
        help: "ensure divisor is not zero at runtime"
      )
    end
  end

  def analyze_unary_expression(node)
    analyze_expression(node.operand) if node.operand
  end

  def analyze_array_access(node)
    analyze_expression(node.array) if node.array
    analyze_expression(node.index) if node.index
  end

  def analyze_len_function(node)
    analyze_expression(node.argument) if node.argument
  end

  def is_zero_division_risk?(expr)
    case expr
    when NestParser::IntegerLiteral
      expr.value == 0
    else
      false
    end
  end

  def string_literal?(expr)
    case expr
    when NestParser::StringLiteral
      true
    else
      false
    end
  end

  def string_expression?(expr)
    case expr
    when NestParser::StringLiteral
      true
    when NestParser::Identifier
      true
    else
      false
    end
  end

  def builtin_function?(name)
    @builtin_functions.key?(name)
  end

  def builtin_function_info(name)
    @builtin_functions[name]
  end
end