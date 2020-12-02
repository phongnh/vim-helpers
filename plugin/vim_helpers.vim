" vim_helpers.vim
" Maintainer: Phong Nguyen
" Version:    0.1.0

if get(g:, 'loaded_vim_helpers', 0)
    finish
endif

let g:vim_helpers_debug = get(g:, 'vim_helpers_debug', 0)

" Log Helpers
function! s:Print(msg) abort
    echohl WarningMsg | echomsg a:msg | echohl None
endfunction

function! s:LogCommand(cmd, ...) abort
    if g:vim_helpers_debug
        let l:tag = get(a:, 1, '')
        if strlen(l:tag)
            let l:tag = '[' . l:tag . '] '
        endif
        call s:Print('Running: ' . l:tag . a:cmd)
    endif
endfunction

" Remove zero-width spaces (<200b>) {{{
command! -bar Remove200b silent! %s/\%u200b//g | update | redraw
command! -bar RemoveZeroWidthSpaces Remove200b
" }}}

" Copy Commands {{{
    if has('clipboard')
        " Copy yanked text to clipboard
        command! CopyYankedText let [@+, @*] = [@", @"]
    endif

    " Copy path to clipboard
    function! s:copy_path_to_clipboard(path) abort
        let @" = a:path
        if has('clipboard')
            let [@*, @+] = [@", @"]
        endif
        echo 'Copied: ' . @"
    endfunction

    function! s:copy_path(path, line) abort
        let path = expand(a:path)
        if a:line
            let path .= ':' . line('.')
        endif
        call s:copy_path_to_clipboard(path)
    endfunction

    command! -bang CopyRelativePath call <SID>copy_path('%', <bang>0)
    command! -bang CopyFullPath     call <SID>copy_path('%:p', <bang>0)
    command! -bang CopyParentPath   call <SID>copy_path(<bang>0 ? '%:p:h' : '%:h', 0)

    if get(g:, 'copypath_mappings', 1)
        nnoremap <silent> yp :CopyRelativePath<CR>
        nnoremap <silent> yP :CopyRelativePath!<CR>
        nnoremap <silent> yu :CopyFullPath<CR>
        nnoremap <silent> yU :CopyFullPath!<CR>
        nnoremap <silent> yd :CopyParentPath<CR>
        nnoremap <silent> yD :CopyParentPath!<CR>
    endif
" }}}

" Highlight commands {{{
    " Highlight current line
    command! HighlightLine call matchadd('Search', '\%' . line('.') . 'l')

    " Highlight the word underneath the cursor
    command! HighlightWord call matchadd('Search', '\<\w*\%' . line('.') . 'l\%' . col('.') . 'c\w*\>')

    " Highlight the words contained in the virtual column
    command! HighlightColumns call matchadd('Search', '\<\w*\%' . virtcol('.') . 'v\w*\>')

    " Clear the permanent highlights
    command! ClearHightlights call clearmatches()

    if get(g:, 'highlight_mappings', 0)
        nnoremap <silent> <Leader>hl :HighlightLine<CR>
        nnoremap <silent> <Leader>hw :HighlightWord<CR>
        nnoremap <silent> <Leader>hv :HighlightColumns<CR>
        nnoremap <silent> <Leader>hc :ClearHightlights<CR>
    endif
" }}}

" Replace typographic characters
" Copied from https://github.com/srstevenson/dotfiles
function! <SID>replace_typographic_characters() abort
    let l:map = {}
    let l:map['–'] = '--'
    let l:map['—'] = '---'
    let l:map['‘'] = "'"
    let l:map['’'] = "'"
    let l:map['“'] = '"'
    let l:map['”'] = '"'
    let l:map['•'] = '*'
    let l:map['…'] = '...'
    execute ':%substitute/'.join(keys(l:map), '\|').'/\=l:map[submatch(0)]/ge'
endfunction

command! -bar ReplaceTypographicCharacters call <SID>replace_typographic_characters()

" Grep Settings
let s:rg_default_filetype_mappings = {
            \ 'bash':            'sh',
            \ 'javascript':      'js',
            \ 'javascript.jsx':  'js',
            \ 'javascriptreact': 'js',
            \ 'jsx':             'js',
            \ 'python':          'py',
            \ }

let g:rg_filetype_mappings = extend(s:rg_default_filetype_mappings, get(g:, 'rg_filetype_mappings', {}))

if executable('rg')
    " https://github.com/BurntSushi/ripgrep
    let &grepprg = 'rg -H --no-heading --hidden --vimgrep --smart-case'

    if get(g:, 'grep_ignore_vcs', 0)
        let &grepprg .= ' --no-ignore-vcs'
    endif
endif
set grepformat=%f:%l:%c:%m,%f:%l:%m

" Grep Helpers
function! s:GrepCmd() abort
    return split(&grepprg, '\s\+')[0]
endfunction

function! s:Grep(cmd, ...) abort
    let cmd = vim_helpers#strip(a:cmd . ' ' . join(a:000, ' '))
    call s:LogCommand(cmd)
    execute cmd
endfunction

function! s:GrepCword(cmd, word_boundary, qargs) abort
    if a:word_boundary
        let cword = vim_helpers#CCwordForGrep()
    else
        let cword = vim_helpers#CwordForGrep()
    endif
    call s:Grep(a:cmd, cword, a:qargs)
endfunction

function! s:GrepCwordInDir(cmd, word_boundary, qargs) abort
    let dir = fnamemodify(empty(a:qargs) ? expand('%') : a:qargs, ':~:.:h')
    let option = vim_helpers#ParseGrepDirOption(s:GrepCmd(), dir)
    call s:GrepCword(a:cmd, a:word_boundary, option)
endfunction

function! s:TGrep(qargs) abort
    call s:Grep('Grep', vim_helpers#ParseGrepFileTypeOption(s:GrepCmd()), a:qargs)
endfunction

function! s:TGrepCword(cmd, word_boundary, qargs) abort
    let cmd = a:cmd . ' ' . vim_helpers#ParseGrepFileTypeOption(s:GrepCmd())
    call s:GrepCword(cmd, a:word_boundary, a:qargs)
endfunction

function! s:FGrep(qargs) abort
    let cmd = s:GrepCmd()
    if cmd ==# 'rg' || cmd ==# 'grep'
        call s:Grep('Grep', '--fixed-strings', a:qargs)
    else
        call s:Grep('Grep', a:qargs)
    endif
endfunction

function! s:FGrepCword(word_boundary, qargs) abort
    let cword = vim_helpers#CwordForGrep()
    call s:FGrep(cword . ' ' . a:qargs)
endfunction

" Grep
command! -bar -nargs=+ -complete=file Grep       silent! grep! <args> | redraw! | cwindow
command!      -nargs=? -complete=file GrepCCword call <SID>GrepCword('Grep', 1, <q-args>)
command!      -nargs=? -complete=file GrepCword  call <SID>GrepCword('Grep', 0, <q-args>)

command!      -nargs=? -complete=file GrepCCwordInDir call <SID>GrepCwordInDir('Grep', 1, <q-args>)
command!      -nargs=? -complete=file GrepCwordInDir  call <SID>GrepCwordInDir('Grep', 0, <q-args>)

" LGrep
command! -bar -nargs=+ -complete=file LGrep       silent! lgrep! <args> | redraw! | lwindow
command!      -nargs=? -complete=file LGrepCCword call <SID>GrepCword('LGrep', 1, <q-args>)
command!      -nargs=? -complete=file LGrepCword  call <SID>GrepCword('LGrep', 0, <q-args>)

command!      -nargs=? -complete=file LGrepCCwordInDir call <SID>GrepCwordInDir('LGrep', 1, <q-args>)
command!      -nargs=? -complete=file LGrepCwordInDir  call <SID>GrepCwordInDir('LGrep', 0, <q-args>)

" BGrep
command! -bar -nargs=1 BGrep       silent! lgrep! <args> % | redraw! | lwindow
command!      -nargs=0 BGrepCCword call <SID>GrepCword('BGrep', 1, '')
command!      -nargs=0 BGrepCword  call <SID>GrepCword('BGrep', 0, '')

" TGrep
command! -nargs=+ -complete=dir TGrep       call <SID>TGrep(<q-args>)
command! -nargs=? -complete=dir TGrepCCword call <SID>TGrepCword('Grep', 1, <q-args>)
command! -nargs=? -complete=dir TGrepCword  call <SID>TGrepCword('Grep', 0, <q-args>)

" FGrep
command! -nargs=+ -complete=dir FGrep       call <SID>FGrep(<q-args>)
command! -nargs=? -complete=dir FGrepCCword call <SID>FGrepCword('Grep', <q-args>)
command! -nargs=? -complete=dir FGrepCword  call <SID>FGrepCword('Grep', <q-args>)


let s:is_windows = has('win64') || has('win32') || has('win32unix') || has('win16')

function! s:SystemRun(cmd, ...) abort
    let cwd = get(a:, 1, '')

    if strlen(cwd)
        let cmd = printf('cd %s && %s', fnameescape(cwd), a:cmd)
    else
        let cmd = a:cmd
    endif

    try
        call s:LogCommand(cmd)
        return system(cmd)
    catch /E684/
    endtry

    return ''
endfunction

" Git helpers
function! s:FindGitRepo() abort
    if exists('b:git_dir') && strlen(b:git_dir)
        return fnamemodify(b:git_dir, ':h')
    endif

    let path = expand('%:p:h')
    if empty(path)
        let path = getcwd()
    endif

    let git_dir = finddir('.git', path . ';')
    if empty(git_dir)
        throw 'Not in git repo!'
    endif

    let b:git_dir = fnamemodify(git_dir, ':p:h')

    return fnamemodify(b:git_dir, ':h')
endfunction

function! s:GitWorkTree() abort
    return fnamemodify(b:git_dir, ':h:p')
endfunction

function! s:ListGitBranches(A, L, P) abort
    try
        let repo_dir = s:FindGitRepo()
        let output = s:SystemRun('git branch -a | cut -c 3-', repo_dir)
        let output = substitute(output, '\s->\s[0-9a-zA-Z_\-]\+/[0-9a-zA-Z_\-]\+', '', 'g')
        let output = substitute(output, 'remotes/', '', 'g')
        return output
    catch
        return ''
    endtry
endfunction

function! s:BuildPath(path) abort
    let l:path = empty(a:path) ? expand('%') : a:path

    if empty(l:path)
        throw 'Path is required!'
    endif

    let l:path = fnamemodify(l:path, ':p')
    let l:path = substitute(l:path, s:GitWorkTree() . '/', '', 'g')
    return l:path
endfunction

let s:git_full_log_cmd = 'git log --name-only --format= --follow -- %s'

if executable('uniq')
    let s:git_full_log_cmd .= ' | uniq'
endif

function! s:GitFullHistoryCommand(path) abort
    return printf('$(' . s:git_full_log_cmd . ')', shellescape(a:path))
endfunction

function! s:ParseRef(line) abort
    let line = vim_helpers#strip(a:line)
    let ref = get(split(line, ' '), 0, '')
    if strlen(ref) && (ref !~# '^0\{7,\}$') && ref =~# '^\^\?[a-z0-9]\{7,\}$'
        if ref[0] == '^'
            return printf('"$(git show --summary --format=format:%%h %s)"', ref)
        else
            return ref
        endif
    endif
    return ''
endfunction

" Gitk
if executable('gitk')
    let s:gitk_cmd = 'gitk %s >/dev/null 2>&1'
    if !s:is_windows
        let s:gitk_cmd .= ' &'
    endif

    function! s:RunGitk(options) abort
        let cmd = vim_helpers#strip(printf(s:gitk_cmd, a:options))
        let cwd = shellescape(s:GitWorkTree())
        call s:LogCommand(cmd)
        execute printf('silent !cd %s && %s', cwd, cmd)
        redraw!
    endfunction

    function! s:Gitk(options) abort
        try
            call s:FindGitRepo()
        catch
            echoerr 'GitkFile: ' . v:exception
            return
        endtry

        call s:RunGitk(a:options)
    endfunction

    function! s:GitkFile(path, bang) abort
        try
            call s:FindGitRepo()
        catch
            echoerr 'GitkFile: ' . v:exception
            return
        endtry

        let path = s:BuildPath(a:path)

        if a:bang
            call s:RunGitk('-- ' . s:GitFullHistoryCommand(path))
        else
            call s:RunGitk('-- ' . shellescape(path))
        endif
    endfunction

    command! -nargs=? -complete=custom,<SID>ListGitBranches Gitk call <SID>Gitk(<q-args>)
    command! -nargs=? -bang -complete=file GitkFile call <SID>GitkFile(<q-args>, <bang>0)

    nnoremap <silent> gK :GitkFile<CR>

    function! s:GitkRef(line) abort
        let ref = s:ParseRef(a:line)
        call s:RunGitk(ref)
    endfunction

    augroup CommandHelpersGitk
        autocmd!
        autocmd FileType fugitiveblame nnoremap <buffer> <silent> gK :call <SID>GitkRef(getline('.'))<CR>
    augroup END
endif

if s:is_windows
    finish
endif

" Tig
if executable('tig')
    let s:tig_cmd = 'tig %s'
    let s:tigrc_user_path = fnamemodify(resolve(expand('<sfile>:p')), ':h:h') . '/config/vim.tigrc'
    let s:tig_mode = get(g:, 'tig_mode', 'tab')

    function! s:UpdateVimSettings() abort
        let s:tig_vim_settings = {
                    \ 'showtabline': &showtabline,
                    \ 'laststatus': &laststatus,
                    \ }
        set showtabline=0
        set laststatus=0
    endfunction

    function! s:RestoreVimSettings() abort
        for [k, v] in items(s:tig_vim_settings)
            execute printf('set %s=%s', k, string(v))
        endfor
    endfunction

    function! s:GetTigVimActionFile() abort
        if !exists('s:tig_vim_action_file')
            let s:tig_vim_action_file = tempname()
        endif
        return s:tig_vim_action_file
    endfunction

    function! s:TigEnvDict(cwd) abort
        return {
                    \ 'TIGRC_USER': s:tigrc_user_path,
                    \ 'TIG_VIM_ACTION_FILE': s:GetTigVimActionFile(),
                    \ 'TIG_VIM_CWD': a:cwd,
                    \ }
    endfunction

    function! s:TigEnvString(cwd) abort
        return printf('TIG_VIM_ACTION_FILE=%s TIGRC_USER=%s TIG_VIM_CWD=%s',
                    \ s:GetTigVimActionFile(),
                    \ s:tigrc_user_path,
                    \ a:cwd
                    \ )
    endfunction

    function! s:OnExitTigCallback(code, cmd) abort
        if a:code != 0
            echoerr printf('%s: failed!', a:cmd)
            return
        endif

        if exists(':Sayonara') == 2
            silent! Sayonara!
        elseif exists(':Bdelete') == 2
            silent! Bdelete
        else
            silent! buffer #
            silent! hide
        endif

        if s:tig_mode ==# 'tab'
            silent! tabclose
            call s:RestoreVimSettings()
        endif

        call s:OpenTigVimAction(a:cmd)
    endfunction

    function! s:OpenTigVimAction(cmd)
        if !filereadable(s:tig_vim_action_file)
            echoerr printf('%s: failed to open vim action file %s!', a:cmd, s:tig_vim_action_file)
            unlet! s:tig_vim_action_file
            return
        endif

        " Restore Goyo mode
        if s:goyo_enabled
            let s:goyo_enabled = 0
            if exists('g:goyo_width') && exists('g:goyo_height')
                execute 'Goyo ' join([g:goyo_width, g:goyo_height], 'x')
            else
                Goyo
            endif
            redraw
        endif

        try
            for action in readfile(s:tig_vim_action_file)
                if action =~# '^Git commit'
                    if exists(':Git') == 2
                        execute 'silent! ' . action
                    endif
                else
                    execute 'silent! ' . action
                endif
            endfor
        finally
        endtry
    endfunction

    function! s:RunTig(options) abort
        if type(a:options) == type([])
            let opts = join(a:options, ' ')
        else
            let opts = a:options
        endif

        let cwd = s:GitWorkTree()
        let cmd = vim_helpers#strip('tig ' . opts)

        " Use echo as fallback command
        call writefile(['echo'], s:GetTigVimActionFile())
        " Goyo integration
        let s:goyo_enabled = exists('#goyo')

        if has('nvim')
            if s:tig_mode ==# 'tab'
                tabnew
                call s:UpdateVimSettings()
            else
                enew
            endif
            setlocal nobuflisted buftype=nofile bufhidden=wipe noswapfile norelativenumber nonumber
            let cmd_with_env = printf('env %s %s', s:TigEnvString(cwd), cmd)
            call s:LogCommand(cmd_with_env, 'nvim')
            call termopen(cmd_with_env, {
                        \ 'name': cmd,
                        \ 'cwd': cwd,
                        \ 'clear_env': v:false,
                        \ 'env': s:TigEnvDict(cwd),
                        \ 'on_exit': {job_id, code, event -> s:OnExitTigCallback(code, cmd_with_env)},
                        \ })
            startinsert
        elseif has('terminal')
            if s:tig_mode ==# 'tab'
                tabnew
                call s:UpdateVimSettings()
            endif
            call s:LogCommand(cmd, 'terminal')
            let term_options = {
                        \ 'term_name': cmd,
                        \ 'cwd': cwd,
                        \ 'env': s:TigEnvDict(cwd),
                        \ 'curwin': v:true,
                        \ 'exit_cb': {channel, code -> s:OnExitTigCallback(code, cmd)},
                        \ }
            if v:version >= 802
                let term_options['norestore'] = v:true
            endif
            silent call term_start(cmd, term_options)
        else
            let cmd_with_env = printf('env %s %s', s:TigEnvString(cwd), cmd)
            call s:LogCommand(cmd_with_env, 'vim')
            execute printf('silent !cd %s && %s', shellescape(cwd), cmd_with_env)
            call s:OpenTigVimAction(cmd_with_env)
            redraw!
        endif
    endfunction

    function! s:Tig(options) abort
        try
            call s:FindGitRepo()
        catch
            echoerr 'Tig: ' . v:exception
            return
        endtry

        call s:RunTig(a:options)
    endfunction

    function! s:TigFile(path, bang) abort
        try
            call s:FindGitRepo()
        catch
            echoerr 'TigFile: ' . v:exception
            return
        endtry

        let l:path = s:BuildPath(a:path)

        if a:bang
            call s:RunTig('-- ' . s:GitFullHistoryCommand(l:path))
        else
            call s:RunTig('-- ' . shellescape(l:path))
        endif
    endfunction

    function! s:TigBlame(path) abort
        try
            call s:FindGitRepo()
        catch
            echoerr 'TigFile: ' . v:exception
            return
        endtry

        let opts = ['blame']

        if empty(a:path)
            let l:path = s:BuildPath('')
            call add(opts, '+' . line('.'))
        endif

        call extend(opts, ['--', shellescape(l:path)])

        call s:RunTig(opts)
    endfunction

    function! s:TigStatus() abort
        try
            call s:FindGitRepo()
        catch
            echoerr 'TigStatus: ' . v:exception
            return
        endtry

        call s:RunTig('status')
    endfunction

    command! -nargs=? -complete=custom,<SID>ListGitBranches Tig call <SID>Tig(<q-args>)
    command! -nargs=? -bang -complete=file TigFile call <SID>TigFile(<q-args>, <bang>0)
    command! -nargs=? -complete=file TigBlame call <SID>TigBlame(<q-args>)
    command! -nargs=? TigStatus call <SID>TigStatus()

    nnoremap <silent> gC :TigStatus<CR>
    nnoremap <silent> gL :TigFile<CR>
    nnoremap <silent> gB :TigBlame<CR>

    function! s:TigShow(line) abort
        let ref = s:ParseRef(a:line)
        call s:RunTig('show ' . ref)
    endfunction

    augroup CommandHelpersTig
        autocmd!
        autocmd FileType fugitiveblame nnoremap <buffer> <silent> gB :call <SID>TigShow(getline('.'))<CR>
    augroup END
endif

" Sudo write
command! -bang SW w<bang> !sudo tee >/dev/null %

" Clear terminal console
command! -bar Cls execute 'silent! !clear' | redraw!

let g:loaded_vim_helpers = 1
