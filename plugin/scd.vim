" scd.vim -- Vim plugin for Smart Change of Directory
" Date: 2017-01-31
" Maintainer: Pavol Juhas <pavol.juhas@gmail.com>
" URL: https://github.com/pavoljuhas/scd.vim
"
" Requirements:
"
"   * Linux, Mac OS X or other unix-like operating system
"   * Z shell (usually the "zsh" package in Linux)
"
" FIXME - review and update below
"
" Installation:
"
"   (A) Manual
"   Drop this file to the Vim plugin directory or source it from .vimrc.
"   Copy or symlink the bin/scd script to some directory in the PATH or
"   set the g:scd_command variable to its location.
"
"   (B) Installation from Git bundle
"   Navigate to the vim/plugin directory in the bundle and create symbolic
"   link to this file in the Vim plugin directory, e.g.,
"       ln -si $PWD/scd.vim ~/.vim/plugin/
"   The bin/scd script will be then located relative to the absolute path
"   of scd.vim.
"
" Notes:
"
"   This plugin adds visited directories to the scd index after each
"   :cd command in the Vim session.  This is accomplished by executing
"   background command "scd -a ." when Vim becomes idle.  This auto-indexing
"   feature can be disabled by adding the following line to .vimrc:
"
"       let g:scd_autoindex = 0
"
"   For best results activate scd also in the system shell as described at
"   https://github.com/pavoljuhas/scd.vim/blob/master/scd_tools/README.md#installation
"
" Examples:
"
"   :Scd -ar ~/.vim " recursively index ~/.vim/ and its subdirectories
"   :Scd vi ftpl    " jump to the ~/.vim/ftplugin/ directory
"   :Scd doc        " change to the most recently visited doc directory
"   :Scd in$        " jump to recent directory ending in 'in'
"   :Scd            " show selection menu of frequently used directories
"   :Scd -v         " show selection menu with directory ranking
"   :Slcd           " same as Scd, but use the :lcd Vim command
"   :Scd --help     " display usage info for the scd script
"   :Scd <Tab>      " complete scd-defined directory aliases
"
" Configuration: this plugin honors the following global variables:
"
"   g:scd_autoindex     flag for indexing the :cd visited directories [1]
"   g:scd_command       path to the scd z-shell script ["scd"]

if exists("loaded_scd") || &cp
    finish
endif
let loaded_scd = 1

" Parse configuration variables ----------------------------------------------

" Relative location of the scd script within scd.vim repository
let s:rel_cmd = expand('<sfile>:p:h:h') . '/scd_tools/bin/scd'
" Resolve command name for the z-shell scd script: (i) use g:scd_command if
" defined, (ii) use scd included with this plugin, (iii) just fall back to scd.
let s:scd_command = exists('g:scd_command') ? g:scd_command :
        \ (1 == executable(s:rel_cmd)) ? s:rel_cmd : 'scd'
unlet s:rel_cmd

let s:scd_autoindex = exists('g:scd_autoindex') ? g:scd_autoindex : 1
let s:scd_autoindex = s:scd_autoindex && has('patch-7.4.503')

" Define user Scd commands ---------------------------------------------------

command! -complete=custom,s:ScdComplete -nargs=* Scd
            \ call <SID>ScdFun("cd", [<f-args>])
command! -complete=custom,s:ScdComplete -nargs=* Slcd
            \ call <SID>ScdFun("lcd", [<f-args>])

" Implementation -------------------------------------------------------------

" main interface to the z-shell script
function! s:ScdFun(cdcmd, scdargs)
    let qexpr = '(v:val[0] =~ "[%#]" && !empty(expand(v:val))) ? '
                \ . 'shellescape(expand(v:val)) : v:val'
    let qargs = map(copy(a:scdargs), qexpr)
    let cmd = join([s:scd_command, '--list'] + qargs, ' ')
    let output = system(cmd)
    if v:shell_error
        echo output
        return
    endif
    let output = substitute(output, '\_s*$', '', '')
    let lines = split(output, '\n')
    let cnt = len(lines)
    " even lines have directory alias names prefixed with '# '
    let daliases = filter(copy(lines), 'v:key % 2 == 0 && v:val =~ "^# "')
    let daliases = map(daliases, '(v:key + 1) . ")" . strpart(v:val, 1)')
    " odd lines have directory paths
    let dmatching = filter(lines, 'v:key % 2')
    " check if dmatching and daliases are consistent
    if !cnt || len(daliases) != len(dmatching) || cnt != 2 * len(daliases)
        echo output
        return
    endif
    " here dmatching is at least one
    let target = dmatching[0]
    if len(dmatching) > 1
        let idx = inputlist(['Select directory:'] + daliases) - 1
        redraw
        if idx < 0 || idx >= len(dmatching)
            return
        endif
        let target = dmatching[idx]
    endif
    execute a:cdcmd fnameescape(target)
    if s:scd_autoindex
        call s:ScdAddChangedDir()
    endif
    pwd
endfunction

" Indexing and auto-indexing -------------------------------------------------

" Remember startup directory to detect directory change.
let s:last_directory = getcwd()

function! s:ScdAddChangedDir() abort
    " respect g:scd_autoindex if set after loading this plugin
    if exists('g:scd_autoindex') && !g:scd_autoindex
        return
    endif
    let cwd = getcwd()
    if s:last_directory == cwd
        return
    endif
    let s:last_directory = cwd
    let scd_histfile = exists('$SCD_HISTFILE') ?
                \ $SCD_HISTFILE : expand('~/.scdhistory')
    " Ensure history file exists.  If not create it with private permissions.
    if !filereadable(scd_histfile)
        call writefile([], scd_histfile)
        call setfperm(scd_histfile, 'rw-------')
    endif
    " Obtain the last line or empty string for an empty file.
    let tail = ([''] + readfile(scd_histfile, '', -1))[-1]
    let tail_directory = substitute(tail, '^[^;]*;', '', '')
    if tail_directory == cwd
        return
    endif
    let line = ': ' . localtime() . ':0;' . cwd
    call writefile([line], scd_histfile, 'a')
endfunction

" First remove all scd-related autocommands.
augroup ScdAutoCommands
    autocmd!
augroup END
augroup! ScdAutoCommands

" If autoindex is enabled, add autocommand to check for directory change.
if s:scd_autoindex
    augroup ScdAutoCommands
        autocmd CursorHold,CursorHoldI * call s:ScdAddChangedDir()
    augroup END
endif

" Completion -----------------------------------------------------------------

function! s:ScdComplete(A, L, P)
    let suggestions = s:ScdGetCompletions(a:A, a:L, a:P)
    return join(suggestions, "\n")
endfunction

function! s:ScdGetCompletions(A, L, P)
    let context = s:ScdParseCommandLine(a:A, a:L, a:P)
    let opts = context['options']
    let words = context['words']
    if has_key(opts, '--help')
        return []
    endif
    if has_key(opts, '--alias') && empty(opts['--alias'])
        return []
    endif
    if context['ahead'][0] == '-' && context['complete_options']
        return s:ScdCompleteOption(context)
    endif
    if !empty(get(opts, '--alias', ''))
        return empty(words) ? s:ScdCompleteDir(context) : []
    endif
    if has_key(opts, '--unalias')
        return s:ScdCompleteAlias(context)
    endif
    if has_key(opts, '--add') || has_key(opts, '--unindex')
        return s:ScdCompleteDir(context)
    endif
    if empty(words)
        return s:ScdCompleteAlias(context)
    endif
    return []
endfunction

function! s:ScdCompleteAlias(context)
    let ahead = a:context['ahead']
    let atail = a:context['atail']
    let opts = a:context['options']
    let aliases = s:ScdLoadAliases()
    let suggestions = sort(keys(aliases))
    let unalias = has_key(opts, '--unalias')
    if !unalias && (empty(ahead) || ahead[0] == '~')
        call map(suggestions, '"~" . v:val')
    endif
    if unalias && !has_key(aliases, 'OLD')
        call insert(suggestions, 'OLD')
    endif
    if !empty(atail)
        let nt = len(atail)
        call filter(suggestions, 'v:val[-nt:] == atail')
        call map(suggestions, 'v:val[:-nt - 1]')
    endif
    return suggestions
endfunction

function! s:ScdCompleteDir(context)
    " bail out without error in old vim
    if !has('patch-7.4.2011')
        return []
    endif
    let ahead = a:context['ahead']
    if ahead[0] == '~'
        let tildename = substitute(ahead, '[/\\].*', '', '')
        let tildevalue = expand(tildename)
        let rv = getcompletion(tildevalue . ahead[len(tildename):], 'dir')
        let idx = len(tildevalue)
        let rv = map(rv, 'tildename . v:val[idx:]')
    else
        let rv = getcompletion(ahead, 'dir')
    endif
    return rv
endfunction

function! s:ScdCompleteOption(context)
    let common = ['--help']
    " order by likelihood of use
    let mutex_groups = [
                \ ['--all', '--list', '--verbose', '--push'],
                \ ['--add', '--recursive'],
                \ ['--alias'],
                \ ['--unalias'],
                \ ['--unindex', '--recursive'],
                \ ]
    " do not suggest options which have no effect in vim
    let exclude = {'--list': '', '--push': ''}
    let opts = a:context['options']
    for olong in keys(opts)
        let mutex_groups = filter(mutex_groups, '0 <= index(v:val, olong)')
    endfor
    let rv = []
    for group in mutex_groups
        let rv += group
    endfor
    let rv += common
    let rv = filter(rv, '!has_key(opts, v:val)')
    let rv = filter(rv, '!has_key(exclude, v:val)')
    " remove duplicates while keeping the order of values
    let isdup = repeat([0], len(rv))
    let seen = {}
    for idx in range(len(rv))
        let isdup[idx] = has_key(seen, rv[idx])
        let seen[rv[idx]] = 1
    endfor
    let rv = filter(rv, '!isdup[v:key]')
    return rv
endfunction

" Helper function for loading scd aliases

let s:scd_alias = {}
let s:scd_alias_file = $HOME . '/.scdalias.zsh'
let s:scd_alias_mtime = -20

function! s:ScdLoadAliases()
    let ad = {}
    if !filereadable(s:scd_alias_file)
        return ad
    endif
    " shortcut if aliases have been cached
    if getftime(s:scd_alias_file) == s:scd_alias_mtime
        return s:scd_alias
    endif
    " here we need to load and cache the scd aliases
    for line in readfile(s:scd_alias_file)
        if line !~# '^hash -d .*\S='
            continue
        endif
        let eq = stridx(line, '=')
        let ca = substitute(strpart(line, 0, eq), '.*\s', '', '')
        let df = substitute(strpart(line, eq + 1), '\s*$', '', '')
        let df = substitute(df, "^'\\(.*\\)'$", '\1', '')
        let ad[ca] = df
    endfor
    let s:scd_alias = ad
    let s:scd_alias_mtime = getftime(s:scd_alias_file)
    return s:scd_alias
endfunction

function! s:ScdParseCommandLine(A, L, P)
    let pcmd = '\(^\|.*[|]\)[:[:blank:]]*Sl\?\%[cd]\s\+'
    let cmdleft = strpart(a:L, 0, a:P - len(a:A))
    let cmdleft = substitute(cmdleft, pcmd, '', '')
    let mlist = matchlist(strpart(a:L, a:P), '^\(\S*\)\(\s\+.*\)\?$')
    let rv = {'ahead': a:A, 'atail': mlist[1]}
    let cmdright = mlist[2]
    let argsleft = split(cmdleft, '\s\+')
    let argsright = split(cmdright, '\s\+')
    let rv['complete_options'] = (-1 == index(argsleft, '--'))
    let argsall = argsleft + argsright
    let opts = {}
    let words = []
    let popt = '\v^(-[arApvh]+|--add|--unindex|--recursive|--alias([=]\S*)?|'
                \ . '--unalias|--all|--push|--list|--verbose|--help)$'
    let shoptmap = {'a': '--add', 'r': '--recursive', 'A': '--all',
                \   'p': '--push', 'v': '--verbose', 'h': '--help'}
    while !empty(argsall)
        let w = remove(argsall, 0)
        if w == '--'
            let words += argsall
            let argsall = []
            break
        endif
        if w !~ popt
            call add(words, w)
        elseif w[1] != '-'
            for l:c in split(w[1:], '\zs')
                let opts[shoptmap[l:c]] = ''
            endfor
        elseif w =~ '^--alias='
            let opts['--alias'] = substitute(w, '^[^=]*[=]', '', '')
        elseif w == '--alias'
            let opts['--alias'] = empty(argsall) ? '' : remove(argsall, 0)
        else
            let opts[w] = ''
        endif
    endwhile
    let rv['options'] = opts
    let rv['words'] = words
    return rv
endfunction
