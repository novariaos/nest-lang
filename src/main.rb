require "colorize"
require_relative "lexer"
require_relative "parser"
require_relative "semantic"
require_relative "codegen"
require_relative "preprocessor"

path = ARGV[0]
out = ARGV[1]

if ARGV[0] == nil
    print "nest: ".bold 
    print "fatal error: ".red
    puts "no input files"
    exit(1)
end

begin
    source = File.read(path)
rescue Errno::ENOENT
    print "nest: ".bold
    print "fatal error: ".red
    puts "file '#{path}' not found"
    exit(1)
end

if ARGV[1] == nil
    out = "out"
end

# Run preprocessor
preprocessor = NestPreprocessor.new
begin
    processed_source, source_map_func = preprocessor.preprocess(source, path)
rescue PreprocessorError => e
    print "nest: ".bold
    print "error: ".red
    puts " #{e.message}"
    exit(1)
end

# Lex with source mapping
lexer = NestLexer.new(processed_source, path, source_map_func)
tokens = lexer.tokenize

if tokens.nil?
    puts
    print "nest: ".bold
    print "error: ".red
    puts "lexical analysis failed"
    exit(1)
end

parser = NestParser.new(tokens)
ast = parser.parse

if ast.nil?
    print "nest: ".bold
    print "error: ".red
    puts "syntax analysis failed"
    exit(1)
end

semantic = NestSemanticAnalyzer.new(ast)
unless semantic.analyze
    exit(1)
end

codegen = NestCodeGen.new(ast, "#{out}.asm")
codegen.generate

puts "→ nvma #{out}.asm #{out}.bin".blue.bold
system("nvma #{out}.asm #{out}.bin")