" Indent.
set autoindent
set expandtab
set shiftwidth=2
set tabstop=2

" Encoding.
if has('vim_starting')
    " Changing encoding in Vim at runtime is undefined behavior.
    set encoding=utf-8
    set fileencodings=utf-8,sjis,cp932,euc-jp
    set fileformats=unix,mac,dos
endif

" Appearance.
set cursorline
set laststatus=2
set nu
set ruler
set showcmd
set showmatch
set title
set wrap

" Others.
set backspace=indent,eol,start
set clipboard+=unnamed
set hlsearch
set ignorecase
set incsearch
set linespace=4
set matchpairs+=<:>
set matchtime=3
set nobackup
set noswapfile
set nowritebackup
set sessionoptions-=options
set smartcase
set switchbuf=useopen
set t_Co=256
set t_kD=^?
set wildmenu


"----------------------------------------------------------------------------"
" Mapping
"----------------------------------------------------------------------------"
nnoremap j gj
nnoremap k gk
nnoremap gj j
nnoremap gk k
nnoremap x "_x
"nnoremap d "_d
nnoremap D "_D

inoremap jj <Esc>
inoremap {<Enter> {}<Left><CR><ESC><S-o>
inoremap [<Enter> []<Left><CR><ESC><S-o>
inoremap (<Enter> ()<Left><CR><ESC><S-o>

" Adding blank lines.
nnoremap <silent> <CR> :<C-u>for i in range(1, v:count1) \| call append(line('.'),   '') \| endfor<CR>

nnoremap m <C-z>
noremap <Space>h  0
noremap <Space>l  $
nnoremap n nzz
nnoremap ; :

" ESCを二回押すことでハイライトを消す
nnoremap <silent> <Esc><Esc> :<C-u>nohlsearch<CR>

" TABにて対応ペアにジャンプ
nnoremap &lt;Tab&gt; %
vnoremap &lt;Tab&gt; %

" Ctrl + hjkl でウィンドウ間を移動
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
" nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l


"----------------------------------------------------------------------------"
" autocmd
"----------------------------------------------------------------------------"
augroup hiroppy
    autocmd!

    " Filetype local settings.
    autocmd FileType go setlocal noexpandtab tabstop=8 shiftwidth=8
augroup END


"----------------------------------------------------------------------------"
" GUI
"----------------------------------------------------------------------------"
if has('gui_running')
    set guifont=FiraMono-Regular:h14
endif


"----------------------------------------------------------------------------"
" Plugin
"----------------------------------------------------------------------------"
let s:DEIN_BASE_PATH = '~/.vim/bundle/'
let s:DEIN_PATH      = expand(s:DEIN_BASE_PATH . 'repos/github.com/Shougo/dein.vim')
if !isdirectory(s:DEIN_PATH)
    let answer = confirm('Would you like to download all plugins ?', "&Yes\n&No", 2)
    if (answer == 1) && (executable('git') == 1)
        execute '!git clone --depth=1 https://github.com/Shougo/dein.vim' s:DEIN_PATH
    else
        syntax enable
        colorscheme desert
        finish
    endif
endif

" dein.vim
execute 'set runtimepath+=' . s:DEIN_PATH

if dein#load_state(s:DEIN_BASE_PATH)
    call dein#begin(s:DEIN_BASE_PATH)

    call dein#add('Shougo/dein.vim')
    call dein#add('haya14busa/dein-command.vim')

    call dein#add('Shougo/deoplete.nvim', { 'lazy': 1, 'on_event': 'InsertEnter', 'if': has('nvim') })
    call dein#add('Shougo/neocomplete.vim', { 'lazy': 1, 'on_event': 'InsertEnter', 'if': (has('lua') && !has('nvim')) })

    call dein#add('Shougo/neomru.vim')
    call dein#add('Shougo/unite.vim')
    call dein#add('Shougo/vimshell')
    call dein#add('airblade/vim-gitgutter')
    call dein#add('itchyny/lightline.vim')
    call dein#add('tpope/vim-fugitive')
    call dein#add('tyru/caw.vim')

    call dein#end()
    call dein#save_state()
endif

if dein#check_install()
    call dein#install()
endif

filetype plugin indent on

" deoplete.nvim
if dein#tap('deoplete.nvim') && has('nvim')
    let g:deoplete#enable_at_startup = 1
    let g:deoplete#enable_smart_case = 1
    inoremap <expr><C-g> deoplete#undo_completion()

    " <C-h>, <BS>: close popup and delete backword char.
    inoremap <expr><C-h> deoplete#smart_close_popup()."\<C-h>"
    inoremap <expr><BS>  deoplete#smart_close_popup()."\<C-h>"

    " <CR>: close popup and save indent.
    inoremap <silent> <CR> <C-r>=<SID>my_cr_function()<CR>
    function! s:my_cr_function() abort
        return deoplete#close_popup() . "\<CR>"
    endfunction
endif

" neocomplete.vim
if dein#tap('neocomplete.vim') && !has('nvim')
    let g:neocomplete#enable_at_startup = 1
    let g:neocomplete#enable_smart_case = 1
    let g:neocomplete#min_keyword_length = 3
    let g:neocomplete#lock_buffer_name_pattern = '\*ku\*'

    inoremap <expr><C-g> neocomplete#undo_completion()
    inoremap <expr><C-l> neocomplete#complete_common_string()

    " <CR>: close popup and save indent.
    inoremap <silent> <CR> <C-r>=<SID>my_cr_function()<CR>
    function! s:my_cr_function()
        return neocomplete#smart_close_popup() . "\<CR>"
    endfunction

    " <TAB>: completion.
    inoremap <silent><expr> <TAB>
                \ pumvisible() ? "\<C-n>" :
                \ <SID>check_back_space() ? "\<TAB>" :
                \ neocomplete#start_manual_complete()
    function! s:check_back_space() abort
        let col = col('.') - 1
        return !col || getline('.')[col - 1]  =~ '\s'
    endfunction

    " <C-h>, <BS>: close popup and delete backword char.
    inoremap <expr><C-h> neocomplete#smart_close_popup()."\<C-h>"
    inoremap <expr><BS> neocomplete#smart_close_popup()."\<C-h>"
    inoremap <expr><C-y> "\<C-y>"
    inoremap <expr><C-e> "\<C-e>"
endif

" caw.vim
nmap <C-K> <Plug>(caw:i:toggle)
vmap <C-K> <Plug>(caw:i:toggle)
nmap ff :TernDef<CR>
nmap fff :TernRefs<CR>
vmap <Enter> <Plug>(EasyAlign)

" lightline.vim
let g:lightline = {
    \ 'colorscheme': 'wombat',
    \ 'component': {
    \   'readonly': '%{&readonly?"x":""}',
    \ },
    \ 'separator': { 'left': '', 'right': '' },
    \ 'subseparator': { 'left': '|', 'right': '|' }
    \ }
let g:gitgutter_sign_added = '✚'
let g:gitgutter_sign_modified = '➜'
let g:gitgutter_sign_removed = '✘'

" vimshell
nmap <silent> vs :<C-u>VimShell<CR>
nmap <silent> vp :<C-u>VimShellPop<CR>


finish
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

syntax enable

NeoBundle 'tpope/vim-fugitive'
NeoBundle 'airblade/vim-gitgutter'
NeoBundle 'itchyny/lightline.vim'
let g:lightline = {
      \ 'colorscheme': 'wombat',
      \ 'component': {
      \  'readonly': '%{&readonly?"x":""}',
      \ },
      \ 'separator': { 'left': '', 'right': '' },
      \ 'subseparator': { 'left': '|', 'right': '|' }
      \ }
let g:gitgutter_sign_added = '✚'
let g:gitgutter_sign_modified = '➜'
let g:gitgutter_sign_removed = '✘'

NeoBundle 'Shougo/vimshell'

" open shell
nmap <silent> vs :<C-u>VimShell<CR>
nmap <silent> vp :<C-u>VimShellPop<CR>


""""""""""""""""""""""""""""""""""""""""""" neocomplcache
NeoBundle 'Shougo/neocomplcache'
" Disable AutoComplPop.
let g:acp_enableAtStartup = 0
" Use neocomplcache.
let g:neocomplcache_enable_at_startup = 1
" Use smartcase.
let g:neocomplcache_enable_smart_case = 1
" Set minimum syntax keyword length.
let g:neocomplcache_min_syntax_length = 3
let g:neocomplcache_lock_buffer_name_pattern = '\*ku\*'

" Define dictionary.
let g:neocomplcache_dictionary_filetype_lists = {
    \ 'default' : ''
    \ }

" Plugin key-mappings.
inoremap <expr><C-g> neocomplcache#undo_completion()
inoremap <expr><C-l> neocomplcache#complete_common_string()

" Recommended key-mappings.
" <CR>: close popup and save indent.
inoremap <silent> <CR> <C-r>=<SID>my_cr_function()<CR>
function! s:my_cr_function()
  return neocomplcache#smart_close_popup() . "\<CR>"
endfunction
" <TAB>: completion.
inoremap <expr><TAB>  pumvisible() ? "\<C-n>" : "\<TAB>"
" <C-h>, <BS>: close popup and delete backword char.
inoremap <expr><C-h> neocomplcache#smart_close_popup()."\<C-h>"
inoremap <expr><BS> neocomplcache#smart_close_popup()."\<C-h>"
inoremap <expr><C-y>  neocomplcache#close_popup()
inoremap <expr><C-e>  neocomplcache#cancel_popup()
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

autocmd BufRead,BufNewFile *.js set filetype=javascript

NeoBundle 'jpalardy/vim-slime'
NeoBundle 'scrooloose/syntastic'
NeoBundle 'scrooloose/nerdtree'

" nerdtree
nnoremap <silent><C-e> :NERDTreeToggle<CR>

NeoBundle 'Townk/vim-autoclose'

NeoBundle 'https://github.com/h1mesuke/unite-outline.git'
NeoBundle 'https://github.com/tyru/open-browser.vim.git'
NeoBundle 'https://github.com/heavenshell/vim-jsdoc.git'

NeoBundle 'Shougo/vimproc.vim', {
  \ 'build' : {
  \     'mac' : 'make -f make_mac.mak',
  \    }
  \ }

NeoBundleLazy 'Shougo/vimshell', {
  \ 'depends' : 'Shougo/vimproc',
  \ 'autoload' : {
  \   'commands' : [{ 'name' : 'VimShell', 'complete' : 'customlist,vimshell#complete'},
  \                 'VimShellExecute', 'VimShellInteractive',
  \                 'VimShellTerminal', 'VimShellPop'],
  \   'mappings' : ['<Plug>(vimshell_switch)']
  \ }}

NeoBundleLazy 'jason0x43/vim-js-indent', {
  \ 'autoload' : {
  \   'filetypes' : ['javascript', 'html'],
  \}}

NeoBundleLazy 'heavenshell/vim-jsdoc' , {'autoload': {'filetypes': ['javascript']}}

NeoBundle 'leafgarland/typescript-vim'

" color theme
NeoBundle 'vim-scripts/Lucius'

NeoBundle 'othree/yajs.vim'
NeoBundle 'othree/es.next.syntax.vim'
NeoBundle 'mxw/vim-jsx'
let g:jsx_ext_required = 0
let g:jsx_pragma_required = 0

" NeoBundle 'othree/html5.vim'
augroup MyXML
  autocmd!
  autocmd Filetype html inoremap <buffer> </ </<C-x><C-o>
augroup END

NeoBundle 'tpope/vim-haml'
NeoBundle 'digitaltoad/vim-jade'
NeoBundle 'pbrisbin/html-template-syntax'
NeoBundle 'joker1007/vim-markdown-quote-syntax'
NeoBundle 'hail2u/vim-css3-syntax'
NeoBundle 'slim-template/vim-slim'
NeoBundle 'nginx.vim'
NeoBundle 'JSON.vim'

NeoBundle 'tpope/vim-endwise'
NeoBundle 'nathanaelkane/vim-indent-guides'
NeoBundle 'https://github.com/junegunn/vim-easy-align.git'
NeoBundle 'fatih/vim-go'
NeoBundle 'tpope/vim-abolish'
NeoBundle 'editorconfig/editorconfig-vim'
NeoBundle 'moll/vim-node'

" tern
NeoBundle 'marijnh/tern_for_vim'
" %cd ~/.vim/bundle/tern_for_vim
" %npm install
" command

call neobundle#end()

" Required:
filetype plugin indent on

NeoBundleCheck

" colorscheme torte
colorscheme lucius
" https://github.com/vim-scripts/Lucius
let g:lucius_contrast = 'light'
let g:lucius_contrast_bg = 'high'

set background=dark

hi LineNr ctermfg=darkcyan ctermbg=black
hi CursorLine ctermbg=black cterm=underline
