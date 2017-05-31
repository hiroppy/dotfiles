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
set guifont=FiraMono-Regular:h14
set hlsearch
set ignorecase
set incsearch
set linespace=4
set matchpairs& matchpairs+=<:>
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

syntax enable


"----------------------------------------------------------------------------"
" mappings
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
nmap <CR> a<CR><space><ESC>

nnoremap m <C-z>
noremap <Space>h  0
noremap <Space>l  $
nnoremap n nzz
nnoremap ; :

" ESCを二回押すことでハイライトを消す
nmap <silent> <Esc><Esc> :nohlsearch<CR>

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


" NeoBundle
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
if has('vim_starting')
  set nocompatible  " Be iMproved

  " Required:
  set runtimepath+=~/.vim/bundle/neobundle.vim/
endif

" Required:
call neobundle#begin(expand('~/.vim/bundle/'))

" Let NeoBundle manage NeoBundle
" Required:
NeoBundleFetch 'Shougo/neobundle.vim'
" filer
NeoBundle 'Shougo/unite.vim'
" Unite.vimで最近使ったファイルを表示できるようにする
NeoBundle 'Shougo/neomru.vim'

" comment-out
NeoBundle "tyru/caw.vim.git"

" caw.vim
nmap <C-K> <Plug>(caw:i:toggle)
vmap <C-K> <Plug>(caw:i:toggle)
nmap ff :TernDef<CR>
nmap fff :TernRefs<CR>
vmap <Enter> <Plug>(EasyAlign)

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
