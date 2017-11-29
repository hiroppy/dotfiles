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

nnoremap m <C-z>
noremap <Space>h  0
noremap <Space>l  $
nnoremap n nzz
noremap ; :
noremap : ;

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
  autocmd BufWinEnter *.html nested inoremap <buffer> </ </<C-x><C-o>
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

  " 一回insertにしてその後UpdateRemotePluginsを実行する
  call dein#add('Shougo/deoplete.nvim', { 'lazy': 1, 'on_event': 'InsertEnter', 'if': has('nvim') })
  call dein#add('Shougo/neocomplete.vim', { 'lazy': 1, 'on_event': 'InsertEnter', 'if': (has('lua') && !has('nvim')) })

  call dein#add('Shougo/neomru.vim')
  call dein#add('Shougo/unite.vim')
  call dein#add('h1mesuke/unite-outline')

  call dein#add('Shougo/vimproc.vim', { 'build': 'make' })
  call dein#add('Shougo/vimshell', { 'lazy': 1, 'on_cmd': ['VimShell', 'VimShellExecute', 'VimShellInteractive', 'VimShellTerminal', 'VimShellPop'], 'on_map': ['<Plug>(vimshell_switch)'] } )
  call dein#add('Townk/vim-autoclose')
  call dein#add('airblade/vim-gitgutter')
  call dein#add('editorconfig/editorconfig-vim')
  call dein#add('haya14busa/vim-operator-flashy', { 'lazy': 1, 'on_map': [ [ 'nx', '<Plug>' ] ] })
  call dein#add('itchyny/lightline.vim')
  call dein#add('itchyny/vim-parenmatch')
  call dein#add('jpalardy/vim-slime')
  call dein#add('junegunn/vim-easy-align')
  call dein#add('kana/vim-operator-user')
  call dein#add('nathanaelkane/vim-indent-guides')
  call dein#add('scrooloose/nerdtree')
  call dein#add('scrooloose/syntastic')
  call dein#add('tpope/vim-abolish')
  call dein#add('tpope/vim-endwise')
  call dein#add('tpope/vim-fugitive')
  call dein#add('tyru/caw.vim')
  call dein#add('tyru/open-browser.vim')

  call dein#add('digitaltoad/vim-jade')
  call dein#add('fatih/vim-go')
  call dein#add('hail2u/vim-css3-syntax')
  call dein#add('heavenshell/vim-jsdoc')
  call dein#add('jason0x43/vim-js-indent')
  call dein#add('joker1007/vim-markdown-quote-syntax')
  call dein#add('leafgarland/typescript-vim')
  call dein#add('marijnh/tern_for_vim')
  call dein#add('moll/vim-node')
  call dein#add('mxw/vim-jsx')
  call dein#add('othree/es.next.syntax.vim')
  call dein#add('othree/yajs.vim')
  call dein#add('pbrisbin/html-template-syntax')
  call dein#add('slim-template/vim-slim')
  call dein#add('tpope/vim-haml')
  call dein#add('vim-scripts/JSON.vim')
  call dein#add('vim-scripts/nginx.vim')

  " for php
  call dein#add('evidens/vim-twig')

  " for javascript
  call dein#add('othree/javascript-libraries-syntax.vim')
  call dein#add('leafgarland/typescript-vim')

  " need to run `npm i -g tern`
  " help: pip install neovim --upgrade
  call dein#add('carlitux/deoplete-ternjs')
  call dein#add('vim-scripts/Lucius')

  " javascript
  " call dein#add('flowtype/vim-flow', {'autoload': {'filetypes': 'javascript'}, 'build': {'mac': 'npm install -g flow-bin'}})

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

  " <CR>: close popup and save indent.
  inoremap <silent> <CR> <C-r>=<SID>my_cr_function()<CR>
  function! s:my_cr_function() abort
    return deoplete#close_popup() . "\<CR>"
  endfunction

  " <TAB>: completion.
  inoremap <silent><expr> <TAB>
        \ pumvisible() ? "\<C-n>" :
        \ <SID>check_back_space() ? "\<TAB>" :
        \ deoplete#mappings#manual_complete()
  function! s:check_back_space() abort "{{{
    let col = col('.') - 1
    return !col || getline('.')[col - 1]  =~ '\s'
  endfunction"}}}

  " <C-h>, <BS>: close popup and delete backword char.
  inoremap <expr><C-h> deoplete#smart_close_popup()."\<C-h>"
  inoremap <expr><BS>  deoplete#smart_close_popup()."\<C-h>"
  inoremap <expr><C-y> "\<C-y>"
  inoremap <expr><C-e> "\<C-e>"
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

" vim-operator-flashy
map y <Plug>(operator-flashy)
map Y <Plug>(operator-flashy)$
let g:operator#flashy#group = 'Error'

" vim-parenmatch
let g:parenmatch_highlight = 0
hi link ParenMatch MatchParen

" caw.vim
nmap <C-K> <Plug>(caw:hatpos:toggle)
vmap <C-K> <Plug>(caw:hatpos:toggle)
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

" lucius
let g:lucius_contrast = 'light'
let g:lucius_contrast_bg = 'high'
set background=dark
hi LineNr ctermfg=darkcyan ctermbg=black
hi CursorLine ctermbg=black cterm=underline

syntax enable
colorscheme lucius

" line
highlight LineNr ctermfg=blue ctermbg=NONE

" background
hi Normal guibg=NONE ctermbg=NONE
