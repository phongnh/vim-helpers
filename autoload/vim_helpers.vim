" vim_helpers.vim
" Maintainer: Phong Nguyen
" Version:    0.1.0

let s:save_cpo = &cpoptions
set cpoptions&vim

" Search Helpers
function! s:TrimNewLines(text) abort
    let text = substitute(a:text, '^\n\+', '', 'g')
    let text = substitute(text, '\n\+$', '', 'g')
    return text
endfunction

function! s:ShellEscape(text) abort
    if empty(a:text)
        return ''
    endif

    " Escape some characters
    let escaped_text = escape(a:text, '^$.*+?()[]{}|')
    return shellescape(escaped_text)
endfunction

function! s:GetSearchText() abort
    let selection = @/

    if selection ==# "\n" || empty(selection)
        return ''
    endif

    return substitute(selection, '^\\<\(.\+\)\\>$', '\\b\1\\b', '')
endfunction

function! vim_helpers#SelectedText() range abort
    " Save the current register and clipboard
    let reg_save     = getreg('"')
    let regtype_save = getregtype('"')
    let cb_save      = &clipboard
    set clipboard&

    " Put the current visual selection in the " register
    normal! ""gvy

    let selection = getreg('"')

    " Put the saved registers and clipboards back
    call setreg('"', reg_save, regtype_save)
    let &clipboard = cb_save

    if selection ==# "\n"
        return ''
    else
        return selection
    endif
endfunction

function! vim_helpers#SelectedTextForShell() range abort
    let selection = s:TrimNewLines(vim_helpers#SelectedText())
    return s:ShellEscape(selection)
endfunction

function! vim_helpers#SearchTextForShell() abort
    let search = s:GetSearchText()
    return s:ShellEscape(search)
endfunction

function! vim_helpers#CCwordForGrep() abort
    let cword = '\b' . expand('<cword>') . '\b'
    let cword = substitute(cword, '#', '\\\\#', 'g')
    return shellescape(cword)
endfunction

function! vim_helpers#CwordForGrep() abort
    let cword = expand('<cword>')
    let cword = substitute(cword, '#', '\\\\#', 'g')
    return shellescape(cword)
endfunction

function! vim_helpers#CwordForSubstitute() abort
    let cword = expand('<cword>')

    if empty(cword)
        return ''
    else
        return cword . '/'
    endif
endfunction

function! vim_helpers#SelectedTextForSubstitute() range abort
    let selection = vim_helpers#SelectedText()

    " Escape regex characters
    let escaped_selection = escape(selection, '^$.*\/~[]')

    " Escape the line endings
    let escaped_selection = substitute(escaped_selection, '\n', '\\n', 'g')

    return escaped_selection
endfunction

function! vim_helpers#GetRgKnownFileTypes() abort
    if executable('rg')
        try
            return systemlist("rg --type-list | cut -d ':' -f 1")
        catch
            return []
        endtry
    endif
    return []
endfunction

function! vim_helpers#GetAgKnownFileTypes() abort
    if executable('ag')
        try
            return systemlist("ag --list-file-types | grep '\-\-' | cut -d '-' -f 3")
        catch
            return []
        endtry
    endif
    return []
endfunction

function! s:SetRgKnownFileTypes() abort
    if exists('g:rg_known_filetypes')
        return
    endif
    let g:rg_known_filetypes = vim_helpers#GetRgKnownFileTypes()
endfunction

function! s:SetAgKnownFileTypes() abort
    if exists('g:ag_known_filetypes')
        return
    endif
    let g:ag_known_filetypes = vim_helpers#GetAgKnownFileTypes()
endfunction

function! vim_helpers#ParseGrepFileTypeOption(cmd) abort
    let ext = expand('%:e')

    if a:cmd ==# 'rg'
        let ft = get(g:rg_filetype_mappings, &filetype, &filetype)
        call s:SetRgKnownFileTypes()

        if strlen(ft) && index(g:rg_known_filetypes, ft) >= 0
            return printf("-t %s", ft)
        elseif strlen(ext)
            return printf("-g '*.%s'", ext)
        endif
    elseif a:cmd ==# 'ag'
        let ft = get(g:ag_filetype_mappings, &filetype, &filetype)
        call s:SetAgKnownFileTypes()

        if strlen(ft) && index(g:ag_known_filetypes, ft) >= 0
            return printf("--%s", ft)
        elseif strlen(ext)
            return printf("-G '.%s$'", ext)
        endif
    elseif a:cmd ==# 'grep'
        if strlen(ext)
            return printf("--include='*.%s'", ext)
        endif
    endif

    return ''
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
