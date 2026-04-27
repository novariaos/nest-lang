" ~/.config/nvim/after/syntax/nest.vim
" Syntax highlighting for Nest programming language

if exists("b:current_syntax")
  finish
endif

syn keyword nestKeyword      proc var return
syn keyword nestConditional  if else
syn keyword nestRepeat       while for
syn keyword nestStatement    break continue
syn keyword nestBoolean      true false
syn keyword nestNull         null

syn keyword nestBuiltin      print println print_num open read write delete
syn keyword nestKeyword      len str int

" Операторы - специальные выделения
syn match nestOperator       "="
syn match nestOperator       "=="
syn match nestOperator       "!="
syn match nestOperator       "+"
syn match nestOperator       "-"
syn match nestOperator       "*"
syn match nestOperator       "/"
syn match nestOperator       "%"
syn match nestOperator       "<"
syn match nestOperator       ">"
syn match nestOperator       "<="
syn match nestOperator       ">="
syn match nestOperator       "&&"
syn match nestOperator       "||"
syn match nestOperator       "!"

" Комментарии
syn match nestComment        "//.*$"
syn region nestComment       start="/\*" end="\*/" contains=nestTodo

" TODO внутри комментариев
syn keyword nestTodo contained TODO FIXME XXX NOTE

" Строки
syn region nestString        start=/\v"/ skip=/\v\\./ end=/\v"/ contains=nestEscape
syn match nestEscape         contained "\\[nt\\\"]"

" Числа
syn match nestNumber         "\<\d\+\>"
syn match nestNumber         "\<0x\x\+\>"

" Идентификаторы функций (имя после proc)
syn match nestFunction       "\<proc\s\+\zs\w\+\ze\s*("

" Вызовы функций (имя перед скобкой)
syn match nestFunctionCall   "\<\w\+\ze\s*("

" Типы (если будут в будущем)
syn keyword nestType         int string bool

" Связывание групп с подсветкой
hi def link nestKeyword      Keyword
hi def link nestConditional  Conditional
hi def link nestRepeat       Repeat
hi def link nestStatement    Statement
hi def link nestBoolean      Boolean
hi def link nestNull         Constant
hi def link nestBuiltin      Function
hi def link nestOperator     Operator
hi def link nestComment      Comment
hi def link nestTodo         Todo
hi def link nestString       String
hi def link nestEscape       SpecialChar
hi def link nestNumber       Number
hi def link nestFunction     Function
hi def link nestFunctionCall Function
hi def link nestType         Type

let b:current_syntax = "nest"
