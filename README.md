# 🪹 Nest
A procedural programming language that compiles to NVM bytecode. Nest is designed to be simple, explicit, and practical.

## 📖 Overview

```nest
proc main() {
    var n = 10;
    var i = 0;
    
    while (i < n) {
        if (i % 2 == 0) {
            print("even: ");
        } else {
            print("odd:  ");
        }
        print(str(i) + "\n");
        i = i + 1;
    }
}
```

### ✨ Supported Features

| Feature | Status |
|---------|--------|
| `print()` built-in | ✅ |
| Integers, strings, booleans | ✅ |
| Variables (`var x = 5`) | ✅ |
| Arithmetic (`+ - * / %`) | ✅ |
| Comparisons (`< > <= >= == !=`) | ✅ |
| Logical operators (`&& \|\| !`) | ✅ |
| `if` / `else` | ✅ |
| `while` loops | ✅ |
| Functions (`proc name(args) {}`) | ✅ |
| Recursion | ✅ |
| `return` | ✅ |
| Local variables | ✅ |

### 🧪 Planned

- `for` loops
- `break` / `continue`
- Arrays
- File I/O (`open`, `read`, `write`, `close`)
- Built-in: `len()`, `int()`, `str()`

## 🔨 Building
_See scripts/install.sh_

## 📁 Project Structure

```
nest-lang
├── src/
│   ├── main.rb         # Driver
│   ├── lexer.rb        # Tokenizer
│   ├── parser.rb       # AST builder
│   ├── codegen.rb      # NVM assembly generation
│   └── lib/
│       └── reporter.rb # Error reporting lib
├── samples/            # Example programs
└──tools/
    └── disasm.rb       # NVM binary disassembler
```

## 🧩 Example: Recursion

```nest
proc pyramid(n, max) {
    if (n <= max) {
        var i = 0;
        while (i < n) {
            print("*");
            i = i + 1;
        }
        print("\n");
        pyramid(n + 1, max);
    }
}

proc main() {
    pyramid(1, 6);
}
```

## 🚧 Limitations (by design)
- No classes, inheritance, or OOP
- No generics
- No exceptions

## 📜 License

GPL-3.0 — because sharing is caring.