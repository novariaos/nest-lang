# Nest Roadmap

Current status and planned features. Checked items are implemented and working.

## Phase 0: Minimal Compiler
- [x] `print("string")` parsing and code generation
- [x] Heap string allocation
- [x] `SYS_WRITE` system call
- [x] Escape sequences: `\n`, `\t`, `\\`, `\"`

## Phase 1: Basic Types and Variables
- [x] `int` (32-bit signed)
- [x] `string`
- [x] `bool` (`true`/`false`)
- [x] Variable declaration: `var x = 10`
- [x] Assignment: `x = 20`
- [x] Arithmetic: `+ - * / %`
- [x] Comparisons: `< > <= >= == !=`
- [x] Logical operators: `&& || !`

## Phase 2: Control Flow
- [x] `if (cond) { ... } else { ... }`
- [x] `while (cond) { ... }`
- [ ] `for (var i = 0; i < n; i = i + 1) { ... }`
- [ ] `break`, `continue`

## Phase 3: Functions
- [x] Declaration: `proc name(args) { ... }`
- [x] Function calls
- [x] `return value`
- [x] Recursion
- [x] Local variables

## Phase 4: Strings
- [ ] Concatenation: `"a" + "b"`
- [ ] Length: `len(s)`
- [ ] Index access: `s[0]`
- [ ] Equality comparison: `==`, `!=`
- [ ] Substring search

## Phase 5: Arrays (Static)
- [ ] Declaration: `var arr[10] = 0`
- [ ] Index access: `arr[0] = 42`
- [ ] Length: `len(arr)`

## Phase 6: File I/O
- [X] `open(path)` → file descriptor
- [X] `read(fd)` → string
- [X] `write(fd, str)` → bytes written
- [X] `delete(path)`
- [ ] `readdir(path)` → array of strings

## Phase 7: Built-in Functions
- [x] `print(str)`
- [ ] `len(arr_or_str)`
- [ ] `int(str)` → integer
- [ ] `str(int)` → string

## Phase 8: Dynamic Arrays (Optional)
- [ ] `var arr = []`
- [ ] `arr.push(x)`
- [ ] `arr.pop()` → value
- [ ] Automatic resizing

## Phase 9: Self-hosting
- [ ] Nest compiler written in Nest
- [ ] Compiler runs on NVM

## Non-goals

These features are intentionally out of scope:

- Classes, inheritance, OOP
- Generics
- Exceptions
- Modules or packages
- Garbage collection
- Multithreading (maybe later)

## Target Example (Phase 7)

```nest
proc main() {
    var fd = open("/etc/motd", "r")
    if (fd < 0) {
        print("Cannot open file\n")
        return 1
    }
    
    var lines = []
    while (true) {
        var line = read_line(fd)
        if (line == null) break
        lines.push(line)
    }
    close(fd)
    
    for (var i = 0; i < len(lines); i = i + 1) {
        print(str(i) + ": " + lines[i])
    }
    
    return 0
}