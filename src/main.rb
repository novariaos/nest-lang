require "colorize"
require_relative "lexer"
require_relative "parser"
require_relative "semantic"
require_relative "codegen"
require_relative "preprocessor"

keep_asm = false
out = "out"
path = nil

i = 0
while i < ARGV.length
    case ARGV[i]
    when "-S"
        keep_asm = true
    when "-o"
        i += 1
        if ARGV[i] == nil
            print "nest: ".bold
            print "fatal error: ".red
            puts "argument missing for '-o'"
            exit(1)
        end
        out = ARGV[i]
    else
        if path.nil?
            path = ARGV[i]
        elsif ARGV[i] !~ /^-/
            out = ARGV[i]
        end
    end
    i += 1
end

if path == nil
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
if system("nvma #{out}.asm #{out}.bin")
    File.delete("#{out}.asm") unless keep_asm
else
    exit(1)
end