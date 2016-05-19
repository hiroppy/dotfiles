set sessionoptions-=options
" cursorline
set cursorline
" status
set laststatus=2
set nu
set ruler
set autoindent
set tabstop=2
set expandtab
set shiftwidth=2
" set softtabstop=2
set showmatch
set matchtime=4
set incsearch
set ignorecase
set hlsearch
set smartcase
set wildmenu
set t_kD=^?
set backspace=indent,eol,start
set encoding=utf8
set fileencoding=utf-8
set title
set wrap
set noswapfile
set nowritebackup
set nobackup
set matchpairs& matchpairs+=<:>
set matchtime=3
set switchbuf=useopen
set showcmd
set clipboard+=unnamed
set guifont=FiraMono-Regular:h14
set linespace=4
set t_Co=256

if expand("%:t") =~ ".*\.go"
  set noexpandtab
  set tabstop=8
  set shiftwidth=8
endif

" syntax enable
set background=dark
colorscheme torte
" colorscheme base16-duotone-darksea
" colorscheme base16-duotone-dark
" colorscheme base16-duotone-darksea
" colorscheme base16-duotone-darkpool
syntax enable

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
" open shell
nmap <silent> vs :<C-u>VimShell<CR>
nmap <silent> vp :<C-u>VimShellPop<CR>
" nerdtree
nnoremap <silent><C-e> :NERDTreeToggle<CR>
" caw.vim
nmap <C-K> <Plug>(caw:i:toggle)
vmap <C-K> <Plug>(caw:i:toggle)

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
inoremap <expr><C-g>     neocomplcache#undo_completion()
inoremap <expr><C-l>     neocomplcache#complete_common_string()

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


NeoBundle 'jpalardy/vim-slime'
NeoBundle 'scrooloose/syntastic'
NeoBundle 'scrooloose/nerdtree'
NeoBundle 'Townk/vim-autoclose'

" tweetvim
NeoBundle 'https://github.com/basyura/bitly.vim.git'
NeoBundle 'https://github.com/basyura/TweetVim.git'
NeoBundle 'https://github.com/basyura/twibill.vim.git'
NeoBundle 'https://github.com/h1mesuke/unite-outline.git'
NeoBundle 'https://github.com/mattn/webapi-vim.git'
NeoBundle 'https://github.com/tyru/open-browser.vim.git'
NeoBundle 'https://github.com/yomi322/neco-tweetvim.git'
NeoBundle 'https://github.com/yomi322/unite-tweetvim.git'
NeoBundle 'https://github.com/leafgarland/typescript-vim.git'

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
\   'filetypes' : ['javascript', 'typescript', 'html'],
\}}
let g:js_indent_typescript = 1

NeoBundle 'leafgarland/typescript-vim'

" color theme
NeoBundle 'JavaScript-syntax'
NeoBundle 'kchmck/vim-coffee-script'
NeoBundle 'carlosvillu/coffeScript-VIM-Snippets'
NeoBundle 'tpope/vim-haml'
NeoBundle 'digitaltoad/vim-jade'
NeoBundle 'pbrisbin/html-template-syntax'
NeoBundle 'joker1007/vim-markdown-quote-syntax'
NeoBundle 'hail2u/vim-css3-syntax'
NeoBundle 'slim-template/vim-slim'
" NeoBundle 'taichouchou2/html5.vim'
NeoBundle 'jQuery'
NeoBundle 'nginx.vim'
NeoBundle 'JSON.vim'
" NeoBundle ‘5t111111/neat-json.vim’

NeoBundle 'tpope/vim-endwise'
NeoBundle 'nathanaelkane/vim-indent-guides'
NeoBundle 'https://github.com/junegunn/vim-easy-align.git'
NeoBundle 'fatih/vim-go'
NeoBundle 'tpope/vim-abolish'
NeoBundle 'editorconfig/editorconfig-vim'

vmap <Enter> <Plug>(EasyAlign)

call neobundle#end()

" Required:
filetype plugin indent on

NeoBundleCheck
