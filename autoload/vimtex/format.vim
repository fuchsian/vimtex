" vimtex - LaTeX plugin for Vim
"
" Maintainer: Karl Yngve Lervåg
" Email:      karl.yngve@gmail.com
"

function! vimtex#format#init_options() " {{{1
  call vimtex#util#set_default('g:vimtex_format_enabled', 0)
endfunction

" }}}1
function! vimtex#format#init_script() " {{{1
  let s:border_beginning = '\v^\s*%(' . join([
        \ '\\item',
        \ '\\begin',
        \ '\\end',
        \ '%(\\\[|\$\$)\s*$',
        \], '|') . ')'

  let s:border_end = '\v[^\\]\%'
        \ . '|\\%(' . join([
        \   '\\\*?',
        \   'clear%(double)?page',
        \   'linebreak',
        \   'new%(line|page)',
        \   'pagebreak',
        \   '%(begin|end)\{[^}]*\}',
        \  ], '|') . ')\s*$'
        \ . '|^\s*%(\\\]|\$\$)\s*$'
endfunction

" }}}1
function! vimtex#format#init_buffer() " {{{1
  if !g:vimtex_format_enabled | return | endif

  setlocal formatexpr=vimtex#format#formatexpr()
endfunction

" }}}1

function! vimtex#format#formatexpr() " {{{1
  let l:foldenable = &l:foldenable
  setlocal nofoldenable

  let l:top = v:lnum
  let l:bottom = v:lnum + v:count - 1
  let l:lines_old = getline(l:top, l:bottom)
  let l:tries = 5

  " This is a hack to make undo restore the correct position
  if mode() !=# 'i'
    normal! ix
    normal! x
  endif

  " Main formatting algorithm
  while l:tries > 0
    " Format the range of lines
    let l:bottom = s:format(l:top, l:bottom)

    " Ensure proper indentation
    silent! execute printf('normal! %sG=%sG', l:top, l:bottom)

    " Check if any lines have changed
    let l:lines_new = getline(l:top, l:bottom)
    let l:index = s:compare_lines(l:lines_new, l:lines_old)
    let l:top += l:index
    if l:top > l:bottom | break | endif
    let l:lines_old = l:lines_new[l:index:]
    let l:tries -= 1
  endwhile

  " Move cursor to first non-blank of the last formatted line
  if mode() !=# 'i'
    execute 'normal!' l:bottom . 'G^'
  endif

  " Don't change the text if the formatting algorithm failed
  if l:tries == 0
    silent! undo
    call vimtex#echo#warning('Formatting of selected text failed!')
  endif

  let &l:foldenable = l:foldenable
endfunction

" }}}1

function! s:format(top, bottom) " {{{1
  let l:bottom = a:bottom
  let l:mark = a:bottom
  for l:current in range(a:bottom, a:top, -1)
    let l:line = getline(l:current)

    if vimtex#util#in_mathzone(l:current, 1)
          \ && vimtex#util#in_mathzone(l:current, col([l:current, '$']))
      let l:mark = l:current - 1
      continue
    endif

    if l:line =~# s:border_end
      if l:current < l:mark
        let l:bottom += s:format_build_lines(l:current+1, l:mark)
      endif
      let l:mark = l:current
    endif

    if l:line =~# s:border_beginning
      if l:current < l:mark
        let l:bottom += s:format_build_lines(l:current, l:mark)
      endif
      let l:mark = l:current-1
    endif

    if l:line =~# '^\s*$'
      let l:bottom += s:format_build_lines(l:current+1, l:mark)
      let l:mark = l:current-1
    endif
  endfor

  if a:top <= l:mark
    let l:bottom += s:format_build_lines(a:top, l:mark)
  endif

  return l:bottom
endfunction

" }}}1
function! s:format_build_lines(start, end) " {{{1
  "
  " Get the desired text to format as a list of words
  "
  let l:words = split(join(map(getline(a:start, a:end),
        \ 'substitute(v:val, ''^\s*'', '''', '''')'), ' '), ' ')
  if empty(l:words) | return 0 | endif

  "
  " Add the words in properly indented and formatted lines
  "
  let l:lnum = a:start-1
  let l:current = repeat(' ', VimtexIndent(a:start))
  for l:word in l:words
    if len(l:word) + len(l:current) > &tw
      call append(l:lnum, substitute(l:current, '\s$', '', ''))
      let l:lnum += 1
      let l:current = repeat(' ', VimtexIndent(a:start))
    endif
    let l:current .= l:word . ' '
  endfor
  if l:current !~# '^\s*$'
    call append(l:lnum, substitute(l:current, '\s$', '', ''))
    let l:lnum += 1
  endif

  "
  " Remove old text
  "
  silent! execute printf('%s;+%s delete', l:lnum+1, a:end-a:start)

  "
  " Return the difference between number of lines of old and new text
  "
  return l:lnum - a:end
endfunction

" }}}1

function! s:compare_lines(new, old) " {{{1
  let l:min_length = min([len(a:new), len(a:old)])
  for l:i in range(l:min_length)
    if a:new[l:i] !=# a:old[l:i]
      return l:i
    endif
  endfor
  return l:min_length
endfunction

" }}}1

" vim: fdm=marker sw=2
