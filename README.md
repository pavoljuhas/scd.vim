# scd.vim (smart-change-directory)

Add `:Scd` and `:Slcd` commands for changing to any directory with a few
keystrokes.


## Examples

```VimL
" add ~/.vim/ and its subdirectories to the scd directory index
:Scd -ar ~/.vim

" jump to the ~/.vim/ftplugin/ directory
:Scd vi ftpl

" change to a recent directory ending with "im"
:Scd im$

" show selection menu with directories ranked by likelihood
:Scd -v

" same as Scd, but use the :lcd Vim command
:Slcd

" complete scd-defined directory aliases
:Scd <Tab>

" display a brief usage information for :Scd
:Scd --help
```

See [scd_tools/README.md](scd_tools/README.md) for more examples
and configuration details.


## Installation

*scd.vim is for Linux, Mac, or other unix-like operating systems only.*

1.  Make sure that [Z shell](http://www.zsh.org/) is installed or install
    it with `sudo apt-get install zsh`.

2.  If you use [pathogen.vim](https://github.com/tpope/vim-pathogen) to
    manage your Vim add-ons, add scd.vim using

    ```sh
    cd ~/.vim/bundle
    git clone https://github.com/pavoljuhas/scd.vim.git
    ```

    Another option of installing scd.vim is to create a symbolic link
    in the Vim plugin directory

    ```sh
    git clone https://github.com/pavoljuhas/scd.vim.git
    ln -si $PWD/scd.vim/plugin/scd.vim ~/.vim/plugin/
    ```

    If you don't use git download the ZIP archive and
    expand it in the `~/.vim/` directory:

    ```sh
    cd ~/.vim
    unzip ~/Downloads/scd.vim.zip
    ```

3.  For best results activate `scd` also for the system shell
    as described [here](scd_tools/README.md#installation).

### Notes

After each `:cd` command scd.vim appends the new working directory to its
directory index.  This is done by executing system command `scd -a .` when
Vim becomes idle.  This feature can be disabled by adding the following
line to .vimrc:

```VimL
let g:scd_autoindex = 0
```

scd.vim requires the [scd script](scd_tools/bin/scd), which is
found relative to the plugin path.  If this for some reason does not work,
the `scd` script location can be also specified in .vimrc as

```VimL
let g:scd_command = '/path/to/scd'
```

When Vim is set to use zsh for system commands `:set shell=/bin/zsh`, scd
aliases can be expanded in Vim command mode, as in `:e ~foo/file.txt`.
Allow this by adding the following line to `~/.zshenv`
```sh
if [[ -s ~/.scdalias.zsh ]]; then source ~/.scdalias.zsh; fi
```

## Repository remarks

This repository derives from the upstream
[smart-change-directory.git](https://github.com/pavoljuhas/smart-change-directory)
project with files reorganized according to the Vim plugin conventions.
The content of both repositories is otherwise fairly equal, except that
smart-change-directory.git should have the latest sources.
