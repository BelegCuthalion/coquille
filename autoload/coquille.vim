let s:coq_running=0
let s:current_dir=expand("<sfile>:p:h") 

if !exists('coquille_auto_move')
    let g:coquille_auto_move="false"
endif

try
    py import sys, vim
catch /E319:/
    if !exists('s:warned')
        echo "vim doesn't support python. Turn off coquille"
        let s:warned = 1
    endif
    function! coquille#Register()
    endfunction
    finish
endtry


" Load vimbufsync if not already done
call vimbufsync#init()

py if not vim.eval("s:current_dir") in sys.path:
\    sys.path.append(vim.eval("s:current_dir")) 
py import coquille

function! coquille#ShowPanels()
    " open the Goals & Infos panels before going back to the main window
    let l:winnb = winnr()
    rightbelow vnew Goals
        setlocal buftype=nofile
        setlocal filetype=coq-goals
        setlocal noswapfile
        let s:goal_buf = bufnr("%")
    rightbelow new Infos
        setlocal buftype=nofile
        setlocal filetype=coq-infos
        setlocal noswapfile
        let s:info_buf = bufnr("%")
    execute l:winnb . 'winc w'
endfunction

function! coquille#KillSession()
    let s:coq_running = 0

    execute 'bdelete' . s:goal_buf
    execute 'bdelete' . s:info_buf
    py coquille.kill_coqtop()

    setlocal ei=InsertEnter
endfunction

function! coquille#RawQuery(...)
    py coquille.coq_raw_query(*vim.eval("a:000"))
endfunction

function! coquille#FNMapping()
    "" --- Function keys bindings
    "" Works under all tested config.
    map <buffer> <silent> <F2> :CoqUndo<CR>
    map <buffer> <silent> <F3> :CoqNext<CR>
    map <buffer> <silent> <F4> :CoqToCursor<CR>
    map <buffer> <silent> <F5> :call coquille#RawQuery("Check " . VisualSelection() . ".")<CR>
    map <buffer> <silent> <F6> :call coquille#RawQuery("Print " . VisualSelection() . ".")<CR>
    map <buffer> <silent> <F7> :call coquille#RawQuery("Search " . VisualSelection() . ".")<CR>
    map <buffer> <silent> <F12> :CoqKill<CR>

    imap <buffer> <silent> <F2> <C-\><C-o>:CoqUndo<CR>
    imap <buffer> <silent> <F3> <C-\><C-o>:CoqNext<CR>
    imap <buffer> <silent> <F4> <C-\><C-o>:CoqToCursor<CR>
    imap <buffer> <silent> <F5> :call coquille#RawQuery("Check " . VisualSelection() . ".")<CR>
    imap <buffer> <silent> <F6> :call coquille#RawQuery("Print " . VisualSelection() . ".")<CR>
    imap <buffer> <silent> <F7> :call coquille#RawQuery("Search " . VisualSelection() . ".")<CR>
    imap <buffer> <silent> <F12> :CoqKill<CR>
endfunction

function! coquille#CoqideMapping()
    "" ---  CoqIde key bindings
    "" Unreliable: doesn't work with all terminals, doesn't work through tmux,
    ""  etc.
    map <buffer> <silent> <C-A-Up>    :CoqUndo<CR>
    map <buffer> <silent> <C-A-Left>  :CoqToCursor<CR>
    map <buffer> <silent> <C-A-Down>  :CoqNext<CR>
    map <buffer> <silent> <C-A-Right> :CoqToCursor<CR>

    imap <buffer> <silent> <C-A-Up>    <C-\><C-o>:CoqUndo<CR>
    imap <buffer> <silent> <C-A-Left>  <C-\><C-o>:CoqToCursor<CR>
    imap <buffer> <silent> <C-A-Down>  <C-\><C-o>:CoqNext<CR>
    imap <buffer> <silent> <C-A-Right> <C-\><C-o>:CoqToCursor<CR>
endfunction

function! coquille#Launch(...)
    if s:coq_running == 1
        echo "Coq is already running"
    else
        let s:coq_running = 1

        " initialize the plugin (launch coqtop)
        py coquille.launch_coq(*vim.eval("map(copy(a:000),'expand(v:val)')"))

        " make the different commands accessible
        command! -buffer GotoDot py coquille.goto_last_sent_dot()
        command! -buffer CoqNext py coquille.coq_next()
        command! -buffer CoqUndo py coquille.coq_rewind()
        command! -buffer CoqToCursor py coquille.coq_to_cursor()
        command! -buffer CoqKill call coquille#KillSession()

        command! -buffer -nargs=* Coq call coquille#RawQuery(<f-args>)

        call coquille#ShowPanels()

        " Automatically sync the buffer when entering insert mode: this is usefull
        " when we edit the portion of the buffer which has already been sent to coq,
        " we can then rewind to the appropriate point.
        " It's still incomplete though, the plugin won't sync when you undo or
        " delete some part of your buffer. So the highlighting will be wrong, but
        " nothing really problematic will happen, as sync will be called the next
        " time you explicitly call a command (be it 'rewind' or 'interp')
        au InsertEnter <buffer> py coquille.sync()
    endif
endfunction

function! coquille#Register()
    hi default CheckedByCoq ctermbg=17 guibg=LightGreen
    hi default SentToCoq ctermbg=60 guibg=LimeGreen
    hi link CoqError Error

    let b:checked = -1
    let b:sent    = -1
    let b:errors  = -1

    command! -bar -buffer -nargs=* -complete=file CoqLaunch call coquille#Launch(<f-args>)
endfunction

function! VisualSelection()
    if mode()=="v"
        let [line_start, column_start] = getpos("v")[1:2]
        let [line_end, column_end] = getpos(".")[1:2]
    else
        let [line_start, column_start] = getpos("'<")[1:2]
        let [line_end, column_end] = getpos("'>")[1:2]
    end
    if (line2byte(line_start)+column_start) > (line2byte(line_end)+column_end)
        let [line_start, column_start, line_end, column_end] =
        \   [line_end, column_end, line_start, column_start]
    end
    let lines = getline(line_start, line_end)
    if len(lines) == 0
            return ''
    endif
    let lines[-1] = lines[-1][: column_end - 1]
    let lines[0] = lines[0][column_start - 1:]
    return join(lines, "\n")
endfunction
