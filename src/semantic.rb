require_relative 'lib/reporter'

class NestSemanticAnalyzer
  TYPES = {
    int: 'int',
    string: 'string',
    bool: 'bool',
    void: 'void',
    unknown: 'unknown',
  }.freeze

  BINARY_OP_TYPES = {
    '+' => { int_int: :int, string_string: :string },
    '-' => { int_int: :int },
    '*' => { int_int: :int },
    '/' => { int_int: :int },
    '%' => { int_int: :int },
    '<' => { int_int: :bool },
    '>' => { int_int: :bool },
    '<=' => { int_int: :bool },
    '>=' => { int_int: :bool },
    '==' => { int_int: :bool, string_string: :bool, bool_bool: :bool },
    '!=' => { int_int: :bool, string_string: :bool, bool_bool: :bool },
    '&&' => { bool_bool: :bool },
    '||' => { bool_bool: :bool },
  }.freeze

  def initialize(ast)
    @ast = ast
    @has_main = false
    @main_location = nil
    @functions = {}
    @errors = []
    @current_function = nil
    @break_depth = 0
    @continue_depth = 0
    @scopes = [{}]
    @scope_stack = []

    @builtin_functions = {
      'open'   => { parameters: [{ name: 'path', type: :string }], returns: :int },
      'read'   => { parameters: [{ name: 'fd', type: :int }, { name: 'buf', type: :int }], returns: :int },
      'write'  => { parameters: [{ name: 'fd', type: :int }, { name: 'content', type: :string }], returns: :int },
      'delete' => { parameters: [{ name: 'path', type: :string }], returns: :void },
      'sbrk'   => { parameters: [{ name: 'size', type: :int }], returns: :int },
      'len'    => { parameters: [{ name: 'value', type: :string }], returns: :int },
      'str'    => { parameters: [{ name: 'value', type: :int }], returns: :string },
      'int'    => { parameters: [{ name: 'value', type: :string }], returns: :int },
    }
  end

  def analyze
    return nil if @ast.nil?

    analyze_program(@ast)

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

  def current_scope
    @scopes.last
  end

  def push_scope
    @scopes.push({})
  end

  def pop_scope
    @scopes.pop
  end

  def resolve_variable(name)
    @scopes.reverse_each do |scope|
      return scope[name] if scope.key?(name)
    end
    nil
  end

  def declare_variable(name, type, node)
    if current_scope.key?(name)
      Reporter.error(
        "variable '#{name}' already declared in this scope",
        line: node.line,
        column: node.column,
        length: name.length,
        note: "previous declaration in this scope",
        help: "use a different name or reassign with '='"
      )
      @errors << "duplicate variable #{name}"
    end
    current_scope[name] = { type: type, node: node }
  end

  def infer_type(expr)
    return :unknown unless expr

    case expr
    when NestParser::IntegerLiteral
      :int
    when NestParser::StringLiteral
      :string
    when NestParser::BooleanLiteral
      :bool
    when NestParser::NullLiteral
      :unknown
    when NestParser::Identifier
      var = resolve_variable(expr.name)
      return :unknown unless var
      var[:type]
    when NestParser::BinaryExpression
      infer_binary_type(expr)
    when NestParser::UnaryExpression
      infer_unary_type(expr)
    when NestParser::FunctionCall
      infer_call_type(expr)
    when NestParser::LenFunction
      :int
    when NestParser::StrFunction
      :string
    when NestParser::IntFunction
      :int
    when NestParser::ArrayLiteral
      :unknown
    when NestParser::ArrayAccess
      :unknown
    else
      :unknown
    end
  end

  def infer_binary_type(node)
    left_type = infer_type(node.left)
    right_type = infer_type(node.right)

    op_rules = BINARY_OP_TYPES[node.operator]
    return :unknown unless op_rules

    key = :"#{left_type}_#{right_type}"
    op_rules[key] || :unknown
  end

  def infer_unary_type(node)
    case node.operator
    when '-'
      :int
    when '!'
      :bool
    else
      :unknown
    end
  end

  def infer_call_type(node)
    if @builtin_functions[node.name]
      @builtin_functions[node.name][:returns]
    elsif @functions[node.name]
      @functions[node.name][:returns] || :unknown
    else
      :unknown
    end
  end

  def check_type_compatibility(expected, actual, node, context)
    return true if expected == :unknown || actual == :unknown
    return true if expected == actual
    return true if expected == :int && actual == :bool
    return true if expected == :string && actual == :int

    Reporter.error(
      "type mismatch: expected #{TYPES[expected] || expected}, got #{TYPES[actual] || actual}",
      line: node.line,
      column: node.column,
      length: 1,
      note: context,
      help: "ensure the expression has the correct type"
    )
    @errors << "type mismatch"
    false
  end

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
    when NestParser::BinaryExpression, NestParser::UnaryExpression
      analyze_expression(stmt)
    else
    end
  end

  def resolve_type(type_str)
    case type_str
    when 'int' then :int
    when 'string' then :string
    when 'bool' then :bool
    else :unknown
    end
  end

  def analyze_function_declaration(node)
    func_name = node.name

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
      @functions[func_name] = { parameters: node.parameters, node: node, returns: :unknown }
    end

    push_scope
    node.parameters.each do |param|
      type = resolve_type(param.type)
      declare_variable(param.name, type, param)
    end

    old_function = @current_function
    @current_function = func_name
    analyze_block(node.body) if node.body
    @current_function = old_function

    pop_scope
  end

  def analyze_variable_declaration(node)
    type = analyze_expression(node.initializer)
    declare_variable(node.name, type, node)
    node.inferred_type = type
  end

  def analyze_assignment(node)
    var = resolve_variable(node.name)
    unless var
      Reporter.error(
        "undefined variable '#{node.name}'",
        line: node.line,
        column: node.column,
        length: node.name.length,
        note: "variable not declared in this scope",
        help: "declare variable with 'var #{node.name} = ...' before using it"
      )
      @errors << "undefined variable #{node.name}"
      return
    end

    value_type = infer_type(node.value)
    check_type_compatibility(var[:type], value_type, node.value, "assigned to variable '#{node.name}' of type #{TYPES[var[:type]]}")
  end

  def analyze_block(node)
    return unless node && node.statements
    push_scope
    node.statements.each { |stmt| analyze_statement(stmt) }
    pop_scope
  end

  def analyze_if_statement(node)
    cond_type = infer_type(node.condition)
    check_type_compatibility(:bool, cond_type, node.condition, "used as if condition")

    analyze_block(node.then_branch) if node.then_branch
    analyze_block(node.else_branch) if node.else_branch
  end

  def analyze_while_statement(node)
    cond_type = infer_type(node.condition)
    check_type_compatibility(:bool, cond_type, node.condition, "used as while condition")

    @break_depth += 1
    @continue_depth += 1
    analyze_block(node.body) if node.body
    @break_depth -= 1
    @continue_depth -= 1
  end

  def analyze_for_statement(node)
    push_scope
    if node.initializer
      case node.initializer
      when NestParser::VariableDeclaration
        analyze_variable_declaration(node.initializer)
      when NestParser::Assignment
        analyze_assignment(node.initializer)
      end
    end

    if node.condition
      cond_type = infer_type(node.condition)
      check_type_compatibility(:bool, cond_type, node.condition, "used as for condition")
    end

    analyze_expression(node.increment) if node.increment

    @break_depth += 1
    @continue_depth += 1
    analyze_block(node.body) if node.body
    @break_depth -= 1
    @continue_depth -= 1

    pop_scope
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
      value_type = infer_type(node.value)
      func_info = @functions[@current_function]
      if func_info && func_info[:returns] != :unknown && func_info[:returns] != value_type
        check_type_compatibility(func_info[:returns], value_type, node.value, "return type of function '#{@current_function}'")
      elsif func_info
        func_info[:returns] = value_type
      end
    end
  end

  def analyze_function_call(node)
    if @builtin_functions[node.name]
      analyze_builtin_call(node)
      return
    end

    unless @functions[node.name]
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
    params = func_info[:parameters]
    arg_count = node.arguments.size

    if params.size != arg_count
      Reporter.error(
        "function '#{node.name}' expects #{params.size} argument#{params.size == 1 ? '' : 's'}, got #{arg_count}",
        line: node.line,
        column: node.column,
        length: node.name.length,
        note: "parameter count mismatch",
        help: "#{params.size > arg_count ? "add" : "remove"} #{(params.size - arg_count).abs} argument#{params.size - arg_count == 1 ? '' : 's'}"
      )
      @errors << "argument count mismatch for #{node.name}"
    else
      params.each_with_index do |param, idx|
        arg_type = analyze_expression(node.arguments[idx])
        expected_type = resolve_type(param.type)
        check_type_compatibility(expected_type, arg_type, node.arguments[idx], "argument #{idx + 1} of function '#{node.name}'")
      end
    end
  end

  def analyze_builtin_call(node)
    func_info = @builtin_functions[node.name]
    params = func_info[:parameters]
    arg_count = node.arguments.size

    if params.size != arg_count
      Reporter.error(
        "built-in function '#{node.name}' expects #{params.size} argument#{params.size == 1 ? '' : 's'}, got #{arg_count}",
        line: node.line,
        column: node.column,
        length: node.name.length,
        note: "parameter count mismatch",
        help: "#{params.size > arg_count ? "add" : "remove"} #{(params.size - arg_count).abs} argument#{params.size - arg_count == 1 ? '' : 's'}"
      )
      @errors << "argument count mismatch for built-in #{node.name}"
    else
      params.each_with_index do |param, idx|
        arg_type = infer_type(node.arguments[idx])
        check_type_compatibility(param[:type], arg_type, node.arguments[idx], "argument #{idx + 1} of '#{node.name}'")
      end
    end

    node.arguments.each { |arg| analyze_expression(arg) }
  end

  def analyze_expression(expr)
    return :unknown unless expr

    case expr
    when NestParser::BinaryExpression
      analyze_binary_expression(expr)
    when NestParser::UnaryExpression
      analyze_unary_expression(expr)
    when NestParser::FunctionCall
      analyze_function_call(expr)
      infer_call_type(expr)
    when NestParser::ArrayAccess
      analyze_array_access(expr)
    when NestParser::LenFunction
      analyze_len_function(expr)
    when NestParser::StrFunction
      analyze_expression(expr.argument)
      :string
    when NestParser::IntFunction
      analyze_expression(expr.argument)
      :int
    else
      infer_type(expr)
    end
  end

  def analyze_binary_expression(node)
    left_type = analyze_expression(node.left)
    right_type = analyze_expression(node.right)

    op_rules = BINARY_OP_TYPES[node.operator]
    unless op_rules
      Reporter.error(
        "unknown operator '#{node.operator}'",
        line: node.line,
        column: node.column,
        length: node.operator.length,
        note: "operator not supported",
        help: "use a valid operator"
      )
      @errors << "unknown operator"
      return :unknown
    end

    key = :"#{left_type}_#{right_type}"
    result_type = op_rules[key]

    unless result_type
      Reporter.error(
        "operator '#{node.operator}' cannot be applied to #{TYPES[left_type] || left_type} and #{TYPES[right_type] || right_type}",
        line: node.line,
        column: node.column,
        length: node.operator.length,
        note: "invalid operand types",
        help: "convert operands to compatible types"
      )
      @errors << "invalid binary operation"
      return :unknown
    end

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

    result_type
  end

  def analyze_unary_expression(node)
    operand_type = analyze_expression(node.operand)

    case node.operator
    when '-'
      check_type_compatibility(:int, operand_type, node.operand, "operand of unary '-'")
      :int
    when '!'
      check_type_compatibility(:bool, operand_type, node.operand, "operand of unary '!'")
      :bool
    else
      :unknown
    end
  end

  def analyze_array_access(node)
    analyze_expression(node.array)
    analyze_expression(node.index)
    :unknown
  end

  def analyze_len_function(node)
    arg_type = analyze_expression(node.argument)
    check_type_compatibility(:string, arg_type, node.argument, "argument of 'len()'")
    :int
  end

  def is_zero_division_risk?(expr)
    case expr
    when NestParser::IntegerLiteral
      expr.value == 0
    else
      false
    end
  end
end

class NestParser::StringLiteral
  attr_accessor :heap_offset
end

class NestParser::VariableDeclaration
  attr_accessor :inferred_type
end
