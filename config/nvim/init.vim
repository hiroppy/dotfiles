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

set autochdir

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
set clipboard=unnamed
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
set undodir=~/.config/nvim/undo/
set undofile

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
nnoremap <silent> <CR> :<C-u>for i in range(1, v:count1) \| call append(line('.'),   '') \| endfor <CR>

noremap <Space>h  0
noremap <Space>l  $
nnoremap n nzz
noremap ; :
noremap : ;

" ESCを二回押すことでハイライトを消す
nnoremap <silent> <Esc><Esc> :<C-u>nohlsearch<CR>

" Ctrl + hjkl でウィンドウ間を移動
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

nnoremap st :split<CR>
nnoremap sd :vsplit<CR>

tnoremap <silent> jj <C-\><C-n>
" Might as well use 'r' 'v' instead of 'a'
:set mouse=a
:map <ScrollWheelUp> :!<CR>

"----------------------------------------------------------------------------"
" autocmd
"----------------------------------------------------------------------------"
augroup hiroppy
  autocmd!

  " Filetype local settings.
  autocmd FileType go setlocal noexpandtab tabstop=8 shiftwidth=8
  autocmd BufWinEnter *.html nested inoremap <buffer> </ </<C-x><C-o>
augroup END

let g:python_host_prog = system('(type pyenv &>/dev/null && echo -n "$(pyenv root)/versions/$(pyenv global | grep python2)/bin/python") || echo -n $(which python2)')
let g:python3_host_prog = system('(type pyenv &>/dev/null && echo -n "$(pyenv root)/versions/$(pyenv global | grep python3)/bin/python") || echo -n $(which python3)')

"----------------------------------------------------------------------------"
" GUI
"----------------------------------------------------------------------------"
if has('gui_running')
  set guifont=FiraMono-Regular:h14
endif


" vim-operator-flashy
" map y <Plug>(operator-flashy)
" map Y <Plug>(operator-flashy)$
let g:operator#flashy#group = 'Error'

" vim-parenmatch
let g:parenmatch_highlight = 0
hi link ParenMatch MatchParen

" caw.vim
nmap <S-K> <Plug>(caw:hatpos:toggle)
vmap <S-K> <Plug>(caw:hatpos:toggle)
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

" nerdtree
nnoremap <silent><C-e> :NERDTreeToggle<CR>

" vimshell
nmap <silent> vs :<C-u>VimShell<CR>
nmap <silent> vp :<C-u>VimShellPop<CR>

" vim-jsx
let g:jsx_ext_required = 0
let g:jsx_pragma_required = 0

" javascript-libraries-syntax.vim
let g:used_javascript_libs = 'underscore,react, flux'

" typescript
let g:typescript_indent_disable = 1
