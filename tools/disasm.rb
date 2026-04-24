# @AIused

# NVM Disassembler
# Usage: ./nvm_disasm.rb <binary_file>

class NVMDisassembler
    # Opcode mnemonics mapping
    OPCODES = {
      # Stack operations
      0x00 => 'HALT',
      0x01 => 'NOP',
      0x02 => 'PUSH',
      0x04 => 'POP',
      0x05 => 'DUP',
      0x06 => 'SWAP',
  
      # Arithmetic
      0x10 => 'ADD',
      0x11 => 'SUB',
      0x12 => 'MUL',
      0x13 => 'DIV',
      0x14 => 'MOD',
  
      # Comparisons
      0x20 => 'CMP',
      0x21 => 'EQ',
      0x22 => 'NEQ',
      0x23 => 'GT',
      0x24 => 'LT',
  
      # Flow control
      0x30 => 'JMP',
      0x31 => 'JZ',
      0x32 => 'JNZ',
      0x33 => 'CALL',
      0x34 => 'RET',
      0x35 => 'ENTER',
      0x36 => 'LEAVE',
      0x37 => 'LOAD_ARG',
      0x38 => 'STORE_ARG',
  
      # Memory operations
      0x40 => 'LOAD',
      0x41 => 'STORE',
      0x42 => 'LOAD_REL',
      0x43 => 'STORE_REL',
      0x44 => 'LOAD_ABS',
      0x45 => 'STORE_ABS',
      0x46 => 'LOAD_HEAP',
      0x47 => 'STORE_HEAP',
  
      # System
      0x50 => 'SYSCALL',
      0x51 => 'BREAK',
  
      # Bitwise
      0x60 => 'AND',
      0x61 => 'OR',
      0x62 => 'XOR',
      0x63 => 'NOT',
      0x64 => 'SHL',
      0x65 => 'SHR',
      0x66 => 'SAR',
    }
  
    def initialize(file_path)
      @file_path = file_path
      @bytecode = nil
      @ip = 0
      @labels = {}
    end
  
    def disassemble
      load_bytecode
      check_signature
      first_pass
      second_pass
    end
  
    private
  
    def load_bytecode
      @bytecode = File.binread(@file_path).bytes
      puts "; File: #{@file_path}"
      puts "; Size: #{@bytecode.size} bytes"
      puts
    end
  
    def check_signature
      signature = @bytecode[0..3].map(&:chr).join
      unless signature == 'NVM0'
        warn "Warning: Invalid NVM signature '#{signature}', expected 'NVM0'"
      end
      @ip = 4  # Skip signature
    end
  
    def first_pass
      # First pass: collect jump targets for labels
      temp_ip = 4
      while temp_ip < @bytecode.size
        opcode = @bytecode[temp_ip]
        mnemonic = OPCODES[opcode]
  
        if mnemonic.nil?
          warn "Warning: Unknown opcode 0x#{opcode.to_s(16).upcase} at 0x#{temp_ip.to_s(16)}"
          temp_ip += 1
          next
        end
  
        case mnemonic
        when 'PUSH', 'JMP', 'JZ', 'JNZ', 'CALL'
          if temp_ip + 4 < @bytecode.size
            addr = read_uint32(temp_ip + 1)
            @labels[addr] = true if %w[JMP JZ JNZ CALL].include?(mnemonic)
            temp_ip += 5
          else
            temp_ip += 1
          end
        when 'ENTER', 'LOAD', 'STORE', 'LOAD_REL', 'STORE_REL',
             'LOAD_ARG', 'STORE_ARG', 'SYSCALL'
          temp_ip += 2
        else
          temp_ip += 1
        end
      end
    end
  
    def second_pass
      @ip = 4
      puts "; Disassembly:"
      puts
  
      while @ip < @bytecode.size
        print_address
        opcode = @bytecode[@ip]
        mnemonic = OPCODES[opcode]
  
        if mnemonic.nil?
          puts "  db 0x#{opcode.to_s(16).upcase}  ; Unknown opcode"
          @ip += 1
          next
        end
  
        case mnemonic
        when 'PUSH'
          disassemble_push
        when 'JMP', 'JZ', 'JNZ', 'CALL'
          disassemble_jump(mnemonic)
        when 'ENTER', 'LOAD', 'STORE', 'LOAD_REL', 'STORE_REL',
             'LOAD_ARG', 'STORE_ARG'
          disassemble_byte_arg(mnemonic)
        when 'SYSCALL'
          disassemble_syscall
        else
          puts "  #{mnemonic}"
          @ip += 1
        end
      end
    end
  
    def disassemble_push
      if @ip + 4 < @bytecode.size
        value = read_uint32(@ip + 1)
        puts "  PUSH 0x#{value.to_s(16).upcase} ; #{value}"
        @ip += 5
      else
        puts "  PUSH ; Incomplete instruction"
        @ip += 1
      end
    end
  
    def disassemble_jump(mnemonic)
      if @ip + 4 < @bytecode.size
        addr = read_uint32(@ip + 1)
        label = label_for(addr)
        puts "  #{mnemonic} #{label}"
        @ip += 5
      else
        puts "  #{mnemonic} ; Incomplete instruction"
        @ip += 1
      end
    end
  
    def disassemble_byte_arg(mnemonic)
      if @ip + 1 < @bytecode.size
        arg = @bytecode[@ip + 1]
        puts "  #{mnemonic} #{arg} ; 0x#{arg.to_s(16).upcase}"
        @ip += 2
      else
        puts "  #{mnemonic} ; Incomplete instruction"
        @ip += 1
      end
    end
  
    def disassemble_syscall
      if @ip + 1 < @bytecode.size
        syscall_id = @bytecode[@ip + 1]
        syscall_name = syscall_name(syscall_id)
        puts "  SYSCALL #{syscall_id} ; #{syscall_name}"
        @ip += 2
      else
        puts "  SYSCALL ; Incomplete instruction"
        @ip += 1
      end
    end
  
    def read_uint32(offset)
      return 0 if offset + 3 >= @bytecode.size
      (@bytecode[offset] << 24) |
        (@bytecode[offset + 1] << 16) |
        (@bytecode[offset + 2] << 8) |
        @bytecode[offset + 3]
    end
  
    def label_for(addr)
      if @labels[addr]
        "label_0x#{addr.to_s(16).upcase}"
      else
        "0x#{addr.to_s(16).upcase}"
      end
    end
  
    def print_address
      if @labels[@ip]
        puts "\nlabel_0x#{@ip.to_s(16).upcase}:"
      end
      print "  ; 0x#{@ip.to_s(16).upcase}"
      print " (#{@ip})" if @ip < 0x10
      print ": "
    end
  
    def syscall_name(id)
      syscalls = {
        0 => 'EXIT',
        1 => 'SPAWN',
        2 => 'OPEN',
        3 => 'READ',
        4 => 'WRITE',
        5 => 'DELETE',
        6 => 'MSG_SEND',
        7 => 'MSG_RECEIVE',
        8 => 'PORT_IN_BYTE',
        9 => 'PORT_OUT_BYTE',
        10 => 'PRINT',
      }
      syscalls[id] || "UNKNOWN"
    end
  end
  
  # Main execution
  if __FILE__ == $PROGRAM_NAME
    if ARGV.empty?
      puts "Usage: #{$PROGRAM_NAME} <nvm_binary_file>"
      puts "Example: #{$PROGRAM_NAME} program.nvm"
      exit 1
    end
  
    file_path = ARGV[0]
  
    unless File.exist?(file_path)
      puts "Error: File '#{file_path}' not found"
      exit 1
    end
  
    disassembler = NVMDisassembler.new(file_path)
    disassembler.disassemble
  end