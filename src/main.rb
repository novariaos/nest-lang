require "colorize"
require_relative "lexer"
require_relative "parser"
require_relative "codegen"

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


lexer = NestLexer.new(source, path)
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

if @errors != nil
    puts "\n#{Reporter::COLORS[:bold]}#{Reporter::COLORS[:red]}aborting due to #{@errors.size} previous error#{@errors.size == 1 ? '' : 's'}#{Reporter::COLORS[:reset]}\n"
end

codegen = NestCodeGen.new(ast, "#{out}.asm")
codegen.generate

puts "→ nvma #{out}.asm #{out}.bin".blue.bold
system("nvma #{out}.asm #{out}.bin")