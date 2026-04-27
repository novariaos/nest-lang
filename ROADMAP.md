# Nest Roadmap

Current status and planned features. Checked items are implemented and working.

## Phase 0: Minimal Compiler
- [x] `print("string")` parsing and code generation
- [x] Heap string allocation
- [x] `SYS_WRITE` system call
- [x] Escape sequences: `\n`, `\t`, `\\`, `\"`

## Phase 1: Basic Types and Variables
- [x] `int` (32-bit signed)
- [x] `string` (as heap offset)
- [x] `bool` (`true`/`false`)
- [x] Variable declaration: `var x = 10`
- [x] Assignment: `x = 20`
- [x] Arithmetic: `+ - * / %`
- [x] Comparisons: `< > <= >= == !=`
- [x] Logical operators: `&& || !`

## Phase 2: Control Flow
- [x] `if (cond) { ... } else { ... }`
- [x] `while (cond) { ... }`
- [ ] `for` loop
- [ ] `break`, `continue`

## Phase 3: Functions
- [x] Function declaration: `proc name(args) { ... }`
- [x] Function calls
- [x] `return value`
- [x] Recursion
- [x] Local variables

## Phase 4: Memory Management Primitives (COMPILER)
Built-in functions provided directly by compiler:
- [ ] `malloc(size)` → offset (allocate heap memory)
- [ ] `free(offset)` (deallocate heap memory)
- [ ] `memcpy(dest, src, size)` → dest (copy memory block)
- [ ] `strlen(offset)` → length (get string length)
- [ ] `read_byte(offset)` → value (read byte from heap)
- [ ] `write_byte(offset, value)` (write byte to heap)

These primitives enable all string operations and dynamic data structures.

## Phase 5: Standard Library (prelude.nest)
Implemented in Nest using primitives from Phase 4:

- [x] `print(str)`
- [x] `println(str)`
- [ ] `concat(a, b)` → new string
- [ ] `strcmp(a, b)` → -1/0/1
- [ ] `strdup(s)` → copy
- [ ] `substr(s, start, len)` → new string
- [ ] `str(num)` → int to string
- [ ] `int(s)` → string to int
- [ ] `index(s, substr)` → position or -1

## Phase 6: Arrays (Static)
- [ ] Declaration: `var arr[10] = 0`
- [ ] Index access: `arr[0] = 42`
- [ ] Length: `len(arr)`

## Phase 7: Dynamic Arrays (in prelude.nest)
Implemented using malloc/free/memcpy:

- [ ] `array_new()` → handle
- [ ] `array_push(arr, value)`
- [ ] `array_pop(arr)` → value
- [ ] `array_get(arr, index)` → value
- [ ] `array_set(arr, index, value)`
- [ ] `array_len(arr)` → length

## Phase 8: File System 
- [x] `open(path)` → fd
- [x] `read(fd)` → string
- [x] `write(fd, str)` → bytes
- [x] `delete(path)`
- [ ] `readdir(path)` → array of strings
- [ ] `close(fd)`
- [ ] `read_line(fd)` → string (built on `read`)

## Phase 9: Self-hosting
- [ ] Nest compiler written in Nest
- [ ] Compiler runs on NVM

## Target Example (Phase 8)

```nest
proc main() {
    var fd = open("/etc/motd");
    if (fd < 0) {
        println("Cannot open file");
        return 1;
    }
    
    var content = read(fd);
    var lines = split(content, "\n");
    
    for (var i = 0; i < len(lines); i = i + 1) {
        println(str(i) + ": " + lines[i]);
    }
    
    free(content);
    // free(lines) - would need array cleanup
}