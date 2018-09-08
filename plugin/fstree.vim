if exists('g:fstree_loaded')
    finish
endif

let g:fstree_loaded = 1

let g:fstree_indent_size = 2
let g:fstree_char_dirclos = '▸'
let g:fstree_char_diropen = '▾'

let g:fstree_exclude = [
    \ '^%.$',
    \ '^%..$'
    \]

function! s:ensure()
    if exists('g:fstree_controller')
        return
    else
        lua require("fstree").init()
    endif
endfunction

function! s:open()
    " TODO: move this to lua
    new | only
    setlocal nobuflisted buftype=nofile bufhidden=wipe noswapfile ft=fstree

    call s:ensure()
    lua require("fstree").open()
endfunction

function! s:next()
    call s:ensure()
    lua require("fstree").next()
endfunction

function! s:back()
    call s:ensure()
    lua require("fstree").back()
endfunction

function! s:expand()
    call s:ensure()
    lua require("fstree").expand()
endfunction

function! s:collapse()
    call s:ensure()
    " lua require("fstree").expand()
    echo 'collapse'
endfunction

command TreeOpen :call s:open()
command TreeNext :call s:next()
command TreeBack :call s:back()
command TreeExpand :call s:expand()
command TreeCollapse :call s:collapse()
command TreeLocate :call s:locate()

augroup spam
  au!
  au FileType fstree nnoremap <buffer> <cr> :TreeNext<cr>
  au FileType fstree nnoremap <buffer> <bs> :TreeBack<cr>
  au FileType fstree nnoremap <buffer> h :TreeCollapse<cr>
  au FileType fstree nnoremap <buffer> l :TreeExpand<cr>
augroup END