let g:fstree_indent_size = 2
let g:fstree_char_dirclos = '▸'
let g:fstree_char_diropen = '▾'

function! s:open()
    new | only
    setlocal nobuflisted buftype=nofile bufhidden=wipe noswapfile ft=fstree

    let bufnr = bufnr('%')
    let cwd = getcwd()

    call luaeval(printf('require("fstree").open(%d, "%s")', bufnr, cwd))
endfunction

function! s:locate()
endfunction

command TreeOpen :call s:open()
command TreeLocate :call s:locate()