" vim-git-log.vim - Browse your git log changes
" Maintainer:  Eric Johnson <http://kablamo.org>
" Version:     0.01
"
" TODO: 
"  - smoother diff action
"  - exit if Fugitive is not found

let g:RibbonBufname = 'Ribbon'
let g:GitLogBufname = 'GitLog'
let g:RibbonHeight  = 10
let g:GitLogGitCmd  = 'git log --pretty=format:''\%s\%n\%an (\%cr) \%p:\%h'' --name-only --no-merges --topo-order '
let g:GitLogShowCmd = 'git show '
let g:GitLogShowLines = 300

let s:bufnr = 0
let s:cmd = 0
let s:lines = 0

let s:match_ids = []

highlight GitLogTitle term=bold cterm=bold ctermfg=166 gui=bold guifg=Magenta
highlight GitLogFiles term=bold cterm=bold ctermfg=37 gui=bold guifg=Green
highlight GitLogAuthor term=NONE cterm=NONE gui=NONE

function! s:GitLog(ribbon, ...)
    " create new buffer
    let l:bufname = g:GitLogBufname
    if a:ribbon == 1
        let l:bufname = g:RibbonBufname
    endif
    let l:cmd = 'edit ' . l:bufname
    execute l:cmd

    autocmd! BufEnter,BufHidden <buffer>
    autocmd BufEnter  <buffer> call <SID>AddMatchHighlight()
    autocmd BufWinLeave <buffer> call <SID>RemoveMatchHighlight()

    " setup new buffer
    call vimgitlog#setupNewBuf()
    noremap <buffer> <silent> q    :call vimgitlog#quit()<cr>
    noremap <buffer> <silent> D    :call vimgitlog#diff()<cr>
    noremap <buffer> <silent> <cr> :call vimgitlog#showdiffstat()<cr>
    noremap <buffer> <silent> f    :call vimgitlog#nextFile()<cr>
    noremap <buffer> <silent> F    :call vimgitlog#prevFile()<cr>
    noremap <buffer> <silent> M    :call vimgitlog#loadMoreCmd('-')<cr>

    " load git log output into the new buffer
    let l:cmd = g:GitLogGitCmd
    if a:ribbon == 1
        let l:cmd = l:cmd . '--reverse _ribbon..origin/master'
    endif
    for c in a:000
        let l:cmd = l:cmd . ' ' . c . ' '
    endfor
    call vimgitlog#loadMoreCmd(l:cmd)
    call <SID>AddMatchHighlight()

    let s:bufnr = bufnr(g:RibbonBufname)
endfunction

function! vimgitlog#loadMoreCmd(cmd)
    if a:cmd != '-'
        let s:lines = g:GitLogShowLines
        let s:cmd   = a:cmd
    else
        let s:lines = s:lines + g:GitLogShowLines
        normal G
    endif
    let l:fullCmd = 'silent read ! ' . s:cmd . ' | head -' . s:lines . ' | tail -' . g:GitLogShowLines
    execute l:fullCmd
    if a:cmd != '-'
        normal 1G
    else
        let l:l = s:lines - g:GitLogShowLines
        exe "normal " . l:l . "G"
    endif
endfunction

function! vimgitlog#quit()
    if bufloaded('diffstat')
        wincmd l
        bdelete
    endif
    bdelete
endfunction

function! vimgitlog#loadCmdIntoBuffer(cmd)
    let l:fullCmd = 'silent 0read ! ' . a:cmd
    execute l:fullCmd
    normal 1G
endfunction

function! vimgitlog#setupNewBuf()
    setlocal buftype=nofile
    setlocal noswapfile
    setlocal nowrap
    setlocal ft=gitlog
    "set bufhidden=hide
    "setlocal nobuflisted
    "setlocal nolist
    setlocal noinsertmode
    setlocal nonumber
    setlocal cursorline
    setlocal nospell
    setlocal matchpairs=""
    if exists('+concealcursor')
      setlocal concealcursor=nc conceallevel=2
    endif
endfunction

function! vimgitlog#showdiffstat()
    let l:oldLineNr = line(".")

    if strlen(getline(l:oldLineNr)) == 0
        return
    endif

    execute 'normal G'
    let l:maxLineNr = line(".")
    execute 'normal ' . l:oldLineNr . 'G'

    let l:lineNr = 0

    " the title line
    if l:oldLineNr > 0 && strlen(getline(l:oldLineNr-1)) == 0
        if l:oldLineNr < l:maxLineNr
            let l:lineNr = l:oldLineNr + 1
        else
            return;
        endif
    else
        execute "normal $"
        let l:lineNr    = search(') \(\w\+:\w\+\)$', 'b')
    endif

    let l:line      = getline(l:lineNr)
    let l:revisions = substitute(l:line, '.*) \(\w\+:\w\+\)$', '\=submatch(1)', "")
    let l:rev       = split(l:revisions, ':')
    execute 'normal ' . l:oldLineNr . 'G'

    if bufloaded('diffstat')
        wincmd l
    else
        vsplit diffstat
        wincmd r
        call vimgitlog#setupNewBuf()
    endif

    noremap <buffer> <silent> q    :bdelete<cr>

    " clear buffer
    normal 1GdG

    " load diffstat into buffer
    let l:cmd = 'git show ' . l:rev[1]
    call vimgitlog#loadCmdIntoBuffer(l:cmd)

    execute 'setlocal filetype=diff'

    wincmd h
endfunction

function! vimgitlog#nextFile()
    let l:oldLineNr = line(".")
    let l:lineNr    = search(') \(\w\+:\w\+\)$')
    let l:line      = getline(l:lineNr)
    let l:revisions = substitute(l:line, '.*) \(\w\+:\w\+\)$', '\=submatch(1)', "")
    let l:rev       = split(l:revisions, ':')
    execute 'normal ' . l:lineNr . 'Gjj'
endfunction

function! vimgitlog#prevFile()
    let l:oldLineNr = line(".")
    let l:lineNr    = search(') \(\w\+:\w\+\)$', 'b')
    let l:lineNr    = search(') \(\w\+:\w\+\)$', 'b')
    let l:line      = getline(l:lineNr)
    let l:revisions = substitute(l:line, '.*) \(\w\+:\w\+\)$', '\=submatch(1)', "")
    let l:rev       = split(l:revisions, ':')
    execute 'normal ' . l:lineNr . 'Gjj'
endfunction

function! vimgitlog#diff()

    " get filename to diff
    let l:filename = getline(".")

    if strlen(l:filename) == 0
        return
    endif

    let l:fileextension = fnamemodify(l:filename, ":e")

    " return if file does not exist
    let l:cwd = getcwd()
    Gcd
    "let l:repo = getcwd()
    "if !filereadable(l:repo . '/' . l:filename)
        "execute 'cd ' . l:cwd
        "return
    "endif

    " parse git output in Ribbon buffer to get revisions
    let l:oldLineNr = line(".")
    let l:oldpos = getpos(".")
    silent! execute 'normal $'

    let l:lineNr    = search(') \(\w\+:\w\+\)$', 'b')

    "echo "old=" . l:oldLineNr . ", search:" . l:lineNr

    if l:oldLineNr - l:lineNr < 1 || (l:oldLineNr > 1 && strlen(getline(l:oldLineNr - 1)) == 0)
        execute 'normal ' . l:oldLineNr . 'G'
        call setpos('.', l:oldpos)
        execute 'cd ' . l:cwd
        return
    endif

    let l:line      = getline(l:lineNr)
    let l:revisions = substitute(l:line, '.*) \(\w\+:\w\+\)$', '\=submatch(1)', "")
    let l:rev       = split(l:revisions, ':')
    execute 'normal ' . l:oldLineNr . 'G'
    call setpos('.', l:oldpos)

    " show rev0:file
    execute 'Git! show ' . l:rev[0] . ':' . l:filename
    let l:bufnr0 = bufnr("")

    " show rev1:file
    execute 'rightbelow vsplit | Git! show ' . l:rev[1] . ':' . l:filename
    let l:bufnr1 = bufnr("")
    let l:cmd='nnoremap <buffer> <silent> q :' . l:bufnr0 . 'bunload<cr>:' . l:bufnr1 . 'bunload<cr>'

    " show diff
    diffthis
    wincmd p
    execute l:cmd
    if strlen(l:fileextension) > 0
        execute 'setlocal filetype=' . l:fileextension
    endif
    diffthis
    wincmd p
    execute l:cmd
    if strlen(l:fileextension) > 0
        execute 'setlocal filetype=' . l:fileextension
    endif

    " return user to original wd
    execute 'cd ' . l:cwd
endfunction

function! s:RibbonSave()
    silent !git tag --force _ribbon origin/master
    redraw!
endfunction

function! s:AddMatchHighlight()
    "echo "AddMatchHighlight"
    call <SID>RemoveMatchHighlight()

    let s:match_ids = []
    "call add(s:match_ids, matchadd("GitLogFiles", "^.*\\w\\+.*$", -100))
    call add(s:match_ids, matchadd("GitLogFiles", "^[^():]*$", -100))
    ""call add(s:match_ids, matchadd("GitLogAuthor", "^\\ addw\\+.*\\s(.*)\\s\\w\\+:\\w\\+$", -99))
    call add(s:match_ids, matchadd("GitLogTitle", "^\\n.*\\w\\+.*$", -99))
endfunction

function! s:RemoveMatchHighlight()
    "echomsg "RemoveMatchHighlight"
    for id in s:match_ids
        call matchdelete(id)
    endfor
    let s:match_ids = []
endfunction

command! -nargs=* GitLog     :call s:GitLog(0, <f-args>)
command!          Ribbon     :call s:GitLog(1)
command!          RibbonSave :call s:RibbonSave()


