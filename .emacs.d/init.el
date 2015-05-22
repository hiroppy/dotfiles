;;load-path
(setq load-path(cons"~/" load-path))
(setq load-path(cons"~/.emacs.d/" load-path))
(setq load-path(cons"~/.emacs.d/auto-install/" load-path))
;; (setq load-path(cons"~/folding_emacs/" load-path))
(setq load-path(cons"~/\php-mode/" load-path))
;; 日本語環境の設定
(set-language-environment "Japanese")
; UTF-8とする
(prefer-coding-system 'utf-8)
;;メッセージなし
(setq inhibit-startup-message t)
;;透明化
(add-to-list 'default-frame-alist '(alpha . 85))
;; cripboard
;; (cond (window-system
;; (setq x-select-enable-clipboard t)
;; ))
(setq x-select-enable-clipboard t)
;;カーソルの点減を止める
(blink-cursor-mode 0)
; タイトルバーにファイル名表示
(setq frame-title-format (format "%%f - Emacs@%s" (system-name)))
;; 日付と時刻を表示する 
(setq display-time-string-forms
      '((format "%s/%s/%s(%s) %s:%s"
                year month day
                dayname
                24-hours minutes)
        load
        (if mail " Mail" "")))
;; 時間を表示
(display-time) 
;; 時刻表示の左隣に日付を追加。
(setq display-time-kawakami-form t)
;; 24 時間制
(setq display-time-24hr-format t)
;;; 全角/半角キーで日本語入力できるようにする
;(global-set-key [zenkaku-hankaku] 'toggle-input-method)
;;背景色
(setq default-frame-alist
      (append
       '((foreground-color . "grey")
         (background-color . "black")
         (top . 0)
         (left . 0)
         (width . 149)  ;; 56
         (height . 37)) ;; 45
       default-frame-alist))
;; カーソルの色を設定します。 
(add-to-list 'default-frame-alist '(cursor-color . "SlateBlue2"))
;; マウスポインタの色を設定します。
(add-to-list 'default-frame-alist '(mouse-color . "SlateBlue2"))

;; font
(if(eq window-system 'ns)(progn
(create-fontset-from-ascii-font "Inconsolata-18:weight=normal:slant=normal" nil "myfavoritefontset")
(set-fontset-font "fontset-myfavoritefontset"
		  'japanese-jisx0208
		  (font-spec :family "TakaoExGothic" :size 15)
		  nil
		  'append)
(add-to-list 'default-frame-alist '(font . "fontset-myfavoritefontset"))
(setq face-font-rescale-alist
	'(("^-apple-hiragino.*" . 1.2)
	  (".*osaka-bold.*" . 1.2)
	  (".*osaka-medium.*" . 1.2)
	  (".*courier-bold-.*-mac-roman" . 1.0)
	  (".*monaco cy-bold-.*-mac-cyrillic" . 0.9)
	  (".*monaco-bold-.*-mac-roman" . 0.9)
	  ("-cdac$" . 1.3)
	  (".*Inconsolata.*" . 1.0)))))

;; font 変更
;; (set-face-attribute 'default nil
;;                     :family "anna"
;;                     :height 140)
;; (set-fontset-font "fontset-default"
;;                   'japanese-jisx0213-1
;;                   '("TakaoExGothic" . "unicode-bmp"))
;; (set-fontset-font "fontset-default"
;;                   'japanese-jisx0213-2
;;                   '("TakaoExGothic" . "unicode-bmp"))
;; (set-fontset-font "fontset-default"
;;                   'japanese-jisx0213-a
;;                   '("TakaoExGothic" . "unicode-bmp"))
;; (set-fontset-font "fontset-default"
;;                   'japanese-jisx0208
;;                   '("TakaoExGothic" . "jisx0208-sjis"))
;; (set-fontset-font "fontset-default"
;;                   'katakana-jisx0201
;;                   '("TakaoExGothic" . "jisx0201-katakana"))

;;; *.~ とかのバックアップファイルを作らない
(setq make-backup-files nil)
;;; .#* とかのバックアップファイルを作らない
(setq auto-save-default nil)
;; ツールバーを非表示
(tool-bar-mode -1)
;; メニューバーを非表示
(menu-bar-mode -1)
;;リージョンを上書き
(delete-selection-mode t)
;; "yes or no"を"y or n"
(fset 'yes-or-no-p 'y-or-n-p)
;;改行時インデント
(global-set-key "\C-m" 'newline-and-indent)
(global-set-key "\C-j" 'newline)
;; キーバインドを変更する
;; HELP k (C-c h k)
;; C-o
(defvar ctl-o-map (make-keymap)) 
(fset 'ctl-o-prefix ctl-o-map)
(define-key global-map "\C-o"  'ctl-o-prefix)
;; C-q
(defvar ctl-q-map (make-keymap))
(fset 'ctl-q-prefix ctl-q-map)
(define-key global-map "\C-q"  'ctl-q-prefix)
(define-key global-map "\C-q\C-q"    'scroll-down)
;; 例えば C-q C-i C-l で ^L の入力が可能
(define-key global-map "\C-q\C-i"    'quoted-insert)
;; C-k
(setq kill-whole-line t)
(defvar ctl-k-map (make-keymap))
(fset 'ctl-k-prefix ctl-k-map)
(define-key global-map "\C-k"  'ctl-k-prefix)
;; 行全体を削除
(define-key global-map "\C-k\C-k"    'kill-whole-line)

;; カーソル位置より後(右)を削除
(define-key global-map "\C-k\C-e"    'kill-line)

;; カーソル位置より前(左)を削除
(define-key global-map "\C-k\C-a"    (lambda ()(interactive)(kill-line 0)))

;; 複数のwindowをつくらない
(setq ns-pop-up-frames nil)

;; scroll-down-command
(define-key global-map "\C-x\C-x" 'scroll-down-command)

;; C-w
(defvar ctl-w-map (make-keymap)
  "keymap for kill or copy region")
(fset 'ctl-w-prefix ctl-w-map)
(define-key global-map "\C-w"  'ctl-w-prefix)

;; リージョンをコピー
(define-key global-map "\C-w\C-w"    'clipboard-kill-region)

;; リージョンを削除
(define-key global-map "\C-w\C-k"    'kill-region)

;; リージョンをコメント/アンコメント
(define-key global-map "\C-w\C-c" 'comment-or-uncomment-region)

;; リージョンをインデント
(define-key global-map "\C-w\C-i" 'indent-region)
;;ピープ音,フラッシュ
(setq ring-bell-function 'ignore)
;; 10 回ごとに加速
(defvar scroll-speedup-count 10)
;; 10 回下カーソルを入力すると，次からは 1+1 で 2 行ずつの移動になる
(defvar scroll-speedup-rate 1)
;; 800ms 経過したら通常のスクロールに戻す
(defvar scroll-speedup-time 800)

;; 以下，内部変数
(defvar scroll-step-default 1)
(defvar scroll-step-count 1)
(defvar scroll-speedup-zero (current-time))

(defun scroll-speedup-setspeed ()
  (let* ((now (current-time))
         (min (- (car now)
                 (car scroll-speedup-zero)))
         (sec (- (car (cdr now))
                 (car (cdr scroll-speedup-zero))))
         (msec
          (/ (- (car (cdr (cdr now)))
                (car
                 (cdr (cdr scroll-speedup-zero))))
             1000))
         (lag
          (+ (* 60000 min)
             (* 1000 sec) msec)))
    (if (> lag scroll-speedup-time)
        (progn
          (setq scroll-step-default 1)
          (setq scroll-step-count 1))
      (setq scroll-step-count
            (+ 1 scroll-step-count)))
    (setq scroll-speedup-zero (current-time))))

(defun scroll-speedup-next-line (arg)
  (if (= (% scroll-step-count
            scroll-speedup-count) 0)
      (setq scroll-step-default
            (+ scroll-speedup-rate
               scroll-step-default)))
  (if (string= arg 'next)
      (line-move scroll-step-default)
    (line-move (* -1 scroll-step-default))))

(defadvice next-line
  (around next-line-speedup activate)
  (if (and (string= last-command 'next-line)
           (interactive-p))
      (progn
        (scroll-speedup-setspeed)
        (condition-case err
            (scroll-speedup-next-line 'next)
          (error
           (if (and
                next-line-add-newlines
                (save-excursion
                  (end-of-line) (eobp)))
               (let ((abbrev-mode nil))
                 (end-of-line)
                 (insert "\n"))
             (line-move 1)))))
    (setq scroll-step-default 1)
    (setq scroll-step-count 1)
    ad-do-it))

(defadvice previous-line
  (around previous-line-speedup activate)
  (if (and
       (string= last-command 'previous-line)
       (interactive-p))
      (progn
        (scroll-speedup-setspeed)
        (scroll-speedup-next-line 'previous))
    (setq scroll-step-default 1)
    (setq scroll-step-count 1)
    ad-do-it))
;;; ホイールマウス
(mouse-wheel-mode t)
(setq mouse-wheel-follow-mouse t)
;;; 対応する括弧を光らせる。
(show-paren-mode 1)
;;カッコ対応
(show-paren-mode 1)
(setq show-paren-style 'mixed)
(set-face-background 'show-paren-match-face "gray10")
(set-face-foreground 'show-paren-match-face "green")
;;テンプレート 
(require 'autoinsert)
(setq auto-insert-directory "~/.template/")
(setq auto-insert-alist
      (append  '( ("\\.c$" . "template.c")
                  ("\\.cpp$" . "template.cpp")
                  ("\\.js$" . "template.js")
                  ("\\.html$" . "template.html")
                  ("\\.css$" . "template.css")
                  ("\\.rb$" . "template.rb")
                  ("\\.php$"."template.php")
                  ("\\.java$"."template.java")                 
                  ) auto-insert-alist))
(add-hook 'find-file-not-found-hooks 'auto-insert)
;;; カーソルの位置が何文字目かを表示する
(column-number-mode t)
;;scrollbar なし
(set-scroll-bar-mode nil)

(setq default-tab-width 2)
(setq indent-tabs-mode nil)

;; ;(setq-default c-basic-offset 4     ;;基本インデント量2
;; ;              tab-width 4          ;;タブ幅2
;; ;              indent-tabs-mode nil)  ;;タブでするかスペースでするか

;; C++ style
(defun add-c++-mode-conf ()
  (c-set-style "ellemtel")     ;;インデントスタイルをellemtaelにする
  (show-paren-mode t))        ;;カッコを強調表示する
(add-hook 'c++-mode-hook 'add-c++-mode-conf)

(defun add-c-mode-common-conf ()
  ;; 自動改行(auto-newline) と 欲張り削除機能(hungry delete)を有効にする
  (c-toggle-auto-hungry-state 1)           
  (setq c-auto-newline t)                     ;;全自動インデント
  (define-key c-mode-base-map "\C-m" 'newline-and-indent)
  (setq indent-tabs-mode nil)                 ;;インデントスペースでする
  (c-set-style "stroustrup")                  ;;スタイルはストラウストラップ
  (flyspell-prog-mode)                        ;;flyspell-prog-mode(自動ispell機能)
  )
;; lisp
;; (require 'auto-install)
;; (setq auto-install-directory "~/.emacs.d/auto-install/")
;; (auto-install-update-emacswiki-package-name t)
;; (auto-install-compatibility-setup)             ; 互換性確保

(autoload 'css-mode "css-mode")
(setq auto-mode-alist      
     (cons '("\\.css\\'" . css-mode) auto-mode-alist))


;;auto-complete 
(add-to-list 'load-path "~/.emacs.d/elisp/")
(require 'auto-complete-config)
(require 'auto-complete)
(add-to-list 'ac-dictionary-directories "~/.emacs.d/elisp/ac-dict")
(ac-config-default)

;;flymake
(require 'flymake)

(defun flymake-cc-init ()
  (let* ((temp-file   (flymake-init-create-temp-buffer-copy
                       'flymake-create-temp-inplace))
         (local-file  (file-relative-name
                       temp-file
                       (file-name-directory buffer-file-name))))
    (list "g++" (list "-Wall" "-Wextra" "-fsyntax-only" local-file))))

(push '("\\.cpp$" flymake-cc-init) flymake-allowed-file-name-masks)
(add-hook 'c++-mode-hook
          '(lambda ()
             (flymake-mode t)))
(custom-set-faces
'(flymake-errline ((((class color)) (:background "Gray25"))))
'(flymake-warnline ((((class color)) (:background "Gray5")))))
;; flymake
(when (require 'flymake nil t)
;; (global-set-key "\C-cd" 'flymake-display-err-menu-for-current-line)
  ;; PHP
  (when (not (fboundp 'flymake-php-init))
    (defun flymake-php-init ()
      (let* ((temp-file (flymake-init-create-temp-buffer-copy
                         'flymake-create-temp-inplace))
             (local-file (file-relative-name
                          temp-file
                          (file-name-directory buffer-file-name))))
        (list "php" (list "-f" local-file "-l"))))
    (setq flymake-allowed-file-name-masks
          (append
           flymake-allowed-file-name-masks
           '(("\.php[345]?$" flymake-php-init))))
    (setq flymake-err-line-patterns
          (cons
           '("\(\(?:Parse error\|Fatal error\|Warning\): .*\) in \(.*\) on line \([0-9]+\)" 2 3 nil 1)
           flymake-err-line-patterns)))
  ;; JavaScript
  ;; (when (not (fboundp 'flymake-javascript-init))
  ;;   (defun flymake-javascript-init ()
  ;;     (let* ((temp-file (flymake-init-create-temp-buffer-copy
  ;;                        'flymake-create-temp-inplace))
  ;;            (local-file (file-relative-name
  ;;                         temp-file
  ;;                         (file-name-directory buffer-file-name))))
  ;;       (list "/usr/local/bin/jsl" (list "-process" local-file))))
  ;;   (setq flymake-allowed-file-name-masks
  ;;         (append
  ;;          flymake-allowed-file-name-masks
  ;;          '(("\.json$" flymake-javascript-init)
  ;;            ("\.js$" flymake-javascript-init))))
  ;;   (setq flymake-err-line-patterns
  ;;         (cons
  ;;          '("\(.+\)(\([0-9]+\)): \(?:lint \)?\(\(?:Warning\|SyntaxError\):.+\)" 1 2 nil 3)

  ;;         flymake-err-line-patterns)))
  ;; Ruby
  (when (not (fboundp 'flymake-ruby-init))
    (defun flymake-ruby-init ()
      (let* ((temp-file (flymake-init-create-temp-buffer-copy
                         'flymake-create-temp-inplace))
             (local-file (file-relative-name
                          temp-file
                          (file-name-directory buffer-file-name))))
        '("ruby" '("-c" local-file)))))
  (add-hook 'php-mode-hook
            '(lambda () (flymake-mode t)))
  (add-hook 'js-mode-hook
            (lambda () (flymake-mode t)))
  (add-hook 'ruby-mode-hook
            (lambda () (flymake-mode t))))

;; ;折りたたみ
;; (add-hook 'c-mode-common-hook 'hs-minor-mode)
;; (eval-after-load "hideshow"
;;  '(define-key c-mode-base
;;     -map "\C-c:" 'hs-toggle-hiding))

;; ;;括弧補完
;; (global-set-key (kbd "(") 'skeleton-pair-insert-maybe)
;; (global-set-key (kbd "[") 'skeleton-pair-insert-maybe)
;;(global-set-key (kbd "\"") 'skeleton-pair-insert-maybe)
(setq skeleton-pair 1)

;;画面分割
(defun window-resizer ()
  "Control window size and position."
  (interactive)
  (let ((window-obj (selected-window))
        (current-width (window-width))
        (current-height (window-height))
        (dx (if (= (nth 0 (window-edges)) 0) 1
              -1))
        (dy (if (= (nth 1 (window-edges)) 0) 1
              -1))
        c)
    (catch 'end-flag
      (while t
        (message "size[%dx%d]"
                 (window-width) (window-height))
        (setq c (read-char))
        (cond ((= c ?l)
               (enlarge-window-horizontally dx))
              ((= c ?h)
               (shrink-window-horizontally dx))
              ((= c ?j)
               (enlarge-window dy))
              ((= c ?k)
               (shrink-window dy))
              ;; otherwise
              (t
               (message "Quit")
               (throw 'end-flag t)))))))

;; C-q をプリフィックスキー化
(define-key global-map "\C-q" (make-sparse-keymap))

;; quoted-insert は C-q C-q へ割り当て
(global-set-key "\C-q\C-q" 'quoted-insert)

;; window-resizer は C-q C-r (resize) で
(global-set-key "\C-q\C-r" 'window-resizer)

;; C-x o
(global-set-key "\C-ql" 'windmove-right)
(global-set-key "\C-qh" 'windmove-left)
(global-set-key "\C-qj" 'windmove-down)
(global-set-key "\C-qk" 'windmove-up)

;;find-file-other-window
(global-set-key "\C-o" 'find-file-other-window)

;;ヘッダの補完補助
;; (add-hook 'c-mode-common-hook
;;           '(lambda ()
;;              ;; センテンスの終了である ';' を入力したら、自動改行+インデント
;;              (c-toggle-auto-hungry-state 1)
;;              ;; RET キーで自動改行+インデント
;;              (define-key c-mode-base-map "\C-m" 'newline-and-indent)
;;              ))

;;; 現在行を目立たせる
;; (defface hlline-face
;;   '((((class color)
;;       (background dark))
;;      (:background "dark slate gray"))
;;     (((class color)
;;       (background light))
;;      (:background "ForestGreen"))
;;     (t
;;      ()))
;;   "*Face used by hl-line.")
;;(setq hl-line-face 'hlline-face)
;;(setq hl-line-face 'underline) ; 下線
;;(global-hl-line-mode)

;; カーソルの場所を保存する
(require 'saveplace)
(setq-default save-place t)

;; バッファの最後でnewlineで新規行を追加するのを禁止する
(setq next-line-add-newlines nil)

(load-library "php-mode")
(require 'php-mode)

;; spell check
(setq-default flyspell-mode t)
(setq ispell-dictionary "american")

;;; 現在の関数名をモードラインに表示
(which-function-mode 1)

;;デバック用出力
(defun my-insert-printf-debug ()
  (interactive)
  (insert-string "std::cout << \"debug \" <<\"line \" <<__LINE__ <<\" func \" <<  __func__ <<  std::endl;")
  (indent-according-to-mode)
)

(add-hook 'c++-mode-hook
  (function (lambda ()
              (define-key c++-mode-map (kbd "C-c d") 'my-insert-printf-debug)
)))

;; Cモード共通フック
;; (add-hook 'csharp-mode-hook
;;           '(lambda()
;;              (setq comment-column 40)
;;              (setq c-basic-offset 4)
;;              (font-lock-add-magic-number)
;;              ;; オフセットの調整
;;              (c-set-offset 'substatement-open 0)
;;              (c-set-offset 'case-label '+)
;;              (c-set-offset 'arglist-intro '+)
;;              (c-set-offset 'arglist-close 0)
;;              )
;;           )

;; C coding style
(add-hook 'c-mode-hook
          '(lambda ()
      (hs-minor-mode 1)))

;;C++ coding style
(add-hook 'c++-mode-hook
          '(lambda ()
      (hs-minor-mode 1)))
;; Scheme coding style
(add-hook 'scheme-mode-hook
          '(lambda ()
      (hs-minor-mode 1)))
;; Elisp coding style
(add-hook 'emacs-lisp-mode-hook
          '(lambda ()
      (hs-minor-mode 1)))
;; Lisp coding style
(add-hook 'lisp-mode-hook
          '(lambda ()
      (hs-minor-mode 1)))
;; Python coding style
(add-hook 'python-mode-hook
          '(lambda ()
      (hs-minor-mode 1)))

(define-key
  global-map
  (kbd "C-c 3") 'hs-toggle-hiding)

;;ace-jump-mode
(require 'ace-jump-mode)
(global-set-key (kbd "C-c SPC") 'ace-jump-mode)

;;emacs -nw

(if window-system () (progn
(set-face-foreground 'font-lock-comment-face "lightred")
(set-face-foreground 'font-lock-string-face  "brown")
(set-face-foreground 'font-lock-keyword-face "lightcyan")
(set-face-foreground 'font-lock-function-name-face "lightblue")
(set-face-bold-p 'font-lock-function-name-face t)
(set-face-foreground 'font-lock-variable-name-face "yellow")
(set-face-foreground 'font-lock-type-face "lightgreen")
(set-face-foreground 'font-lock-builtin-face "lightgray")
(set-face-foreground 'font-lock-constant-face "cyan")
(set-face-foreground 'font-lock-warning-face "cyan")
(set-face-bold-p 'font-lock-warning-face nil)
))
;;; emacs -nw で起動した時にメニューバーを消す
(if window-system (menu-bar-mode 1) (menu-bar-mode -1))


;;画面移動をshift-方向キー
;;(setq windmove-wrap-around t)
;;(windmove-default-keybindings)

;;eshell
;;(global-set-key [f1] 'eshell)

(defun eshell/clear ()
  "Clear the current buffer, leaving one prompt at the top."
  (interactive)
  (let ((inhibit-read-only t))
    (erase-buffer)))

;; 補完時に大文字小文字を区別しない
(setq eshell-cmpl-ignore-case t)

(defun eshell-cd-default-directory ()
  (interactive)
  (let ((dir default-directory))
    (eshell)
    (cd dir)
    (eshell-interactive-print (concat "cd " dir "\n"))
    (eshell-emit-prompt)))
(global-set-key [f1] 'eshell-cd-default-directory)

;;履歴サイズ
(setq eshell-history-size 10000)
(setq eshell-last-dir-ring-size 1000)

;;suspend
(defadvice comint-interrupt-subjob (around ad-comint-interrupt-subjob activate)
     (process-send-string nil "\C-c"))
(defadvice comint-stop-subjob (around ad-comint-interrupt-subjob activate)
     (process-send-string nil "\C-z"))


;;画面間の移動 c-tab
(define-key global-map[C-tab] 'other-window)
(define-key global-map [S-C-tab] (lambda () (interactive) (other-window -1)))

;;汎用機の SPF (mule みたいなやつ) には
;;画面を 2 分割したときの 上下を入れ替える swap screen
(defun swap-screen()
  "Swap two screen,leaving cursor at current window."
  (interactive)
  (let ((thiswin (selected-window))
        (nextbuf (window-buffer (next-window))))
    (set-window-buffer (next-window) (window-buffer))
    (set-window-buffer thiswin nextbuf)))
(defun swap-screen-with-cursor()
  "Swap two screen,with cursor in same buffer."
  (interactive)
  (let ((thiswin (selected-window))
        (thisbuf (window-buffer)))
    (other-window 1)
    (set-window-buffer thiswin (window-buffer))
    (set-window-buffer (selected-window) thisbuf)))
(global-set-key [f2] 'swap-screen)
(global-set-key [S-f2] 'swap-screen-with-cursor)

;;auto complete clang
;; (require 'auto-complete-clang)
;; (defun my-ac-cc-mode-setup ()
;; ;; 読み込むプリコンパイル済みヘッダ
;; ;;(setq ac-clang-prefix-header "~/.emacs.d/elisp/stdafx.pch")

;; (setq ac-clang-flags '("-w" "-ferror-limit" "1"))
;; (setq ac-sources (append '(ac-source-clang
;; ac-source-yasnippet
;; ac-source-gtags)
;; ac-sources)))
;; (defun my-ac-config ()
;; ;(global-set-key "\M-/" 'ac-start)
;; ;; C-n/C-p で候補を選択
;; (define-key ac-complete-mode-map "\C-n" 'ac-next)
;; (define-key ac-complete-mode-map "\C-p" 'ac-previous)
;; ;(add-hook 'emacs-lisp-mode-hook 'ac-emacs-lisp-mode-setup)
;; (add-hook 'c-mode-common-hook 'my-ac-cc-mode-setup)
;; (add-hook 'c++-mode-hook 'ac-cc-mode-setup)
;; ;(add-hook 'ruby-mode-hook 'ac-css-mode-setup)
;; (add-hook 'auto-complete-mode-hook 'ac-common-setup)
;; (global-auto-complete-mode t))

;; (my-ac-config)

(set-face-background 'mode-line-inactive "gray85")

(require 'key-combo)
(key-combo-load-default)
(key-combo-define-global (kbd "{") '("{`!!'}"))
(key-combo-define-global (kbd "{}") "{}")
(key-combo-define-global (kbd "(") '("(`!!')"))
(key-combo-define-global (kbd "()") "()")
(key-combo-define-global (kbd "[") '("[`!!']"))
(key-combo-define-global (kbd "[]") "[]")
(key-combo-define-global (kbd "\"") '("\"`!!'\""))
(key-combo-define-global (kbd "\"\"") "\"\"")
(key-combo-define-global (kbd "'") '("'`!!''"))
(key-combo-define-global (kbd "''") "''")

;;yasnippetの設定
(add-to-list 'load-path "~/.emacs.d/yasnippet/")
(require 'yasnippet)
(yas/initialize)
(yas/load-directory "~/.emacs.d/snippets")

(require 'nav)
(setq nav-split-window-direction 'vertical) ;; 分割したフレームを垂直に並べる
(global-set-key "\C-x\C-d" 'nav-toggle)     ;; C-x C-d で nav をトグル

;; 左に行数の表示
(global-linum-mode t)
(setq linum-format "%4d")

;; modelineに全行数表示
(setcar mode-line-position
        '(:eval (format "%d" (count-lines (point-max) (point-min)))))

;; (add-to-list 'auto-mode-alist '("\\.phtml$"     . web-mode))
;; (add-to-list 'auto-mode-alist '("\\.tpl\\.php$" . web-mode))
;; (add-to-list 'auto-mode-alist '("\\.jsp$"       . web-mode))
;; (add-to-list 'auto-mode-alist '("\\.as[cp]x$"   . web-mode))
;; (add-to-list 'auto-mode-alist '("\\.erb$"       . web-mode))
;; (add-to-list 'auto-mode-alist '("\\.html?$"     . web-mode))

;; list packages
(when (>= emacs-major-version 24)                                                                                                                                                     
  (require 'package)
  (package-initialize)
  (add-to-list 'package-archives '("melpa" . "http://melpa.milkbox.net/packages/") t)
  )

(elscreen-start)
;; (elscreen-set-prefix-key "\C-o")
(setq elscreen-display-tab 10)

; タブの左端の×を非表示
(setq elscreen-tab-display-kill-screen nil)

;; タブの色
(custom-set-variables)

(custom-set-faces
 '(elscreen-tab-current-screen-face ((((class color)) (:background "gray0" :foreground "gray80"))))
  '(elscreen-tab-control-face ((t (:background "gray0" :foreground "gray0"))))
 '(elscreen-tab-other-screen-face ((((type x w32 mac) (class color)) (:background "Black50" :foreground "Gray10")))))

(global-set-key "\M-t" 'elscreen-create)
;; (global-set-key "\M-c" 'elscreen-clone)
(global-set-key "\M-]" 'elscreen-next)
(global-set-key "\M-[" 'elscreen-previous)
(global-set-key "\M-c" 'elscreen-kill)

;; タブの非表示
(setq elscreen-display-tab nil)

(when (locate-library "elscreen")
  (setq elscreen-prefix-key (if window-system [?\C-\;] "\C-\\"))
  (require 'elscreen)
  (require 'elscreen-plus nil t))

(defmacro elscreen-create-automatically (ad-do-it)
  `(if (not (elscreen-one-screen-p))
       ,ad-do-it
     (elscreen-create)
     (elscreen-notify-screen-modification 'force-immediately)
     (elscreen-message "New screen is automatically created")))
 
(defadvice elscreen-next (around elscreen-create-automatically activate)
  (elscreen-create-automatically ad-do-it))
 
(defadvice elscreen-previous (around elscreen-create-automatically activate)
  (elscreen-create-automatically ad-do-it))
 
(defadvice elscreen-toggle (around elscreen-create-automatically activate)
  (elscreen-create-automatically ad-do-it))

(defun elscreen-frame-title-update ()
  (when (elscreen-screen-modified-p 'elscreen-frame-title-update)
    (let* ((screen-list (sort (elscreen-get-screen-list) '<))
       (screen-to-name-alist (elscreen-get-screen-to-name-alist))
       (title (mapconcat
           (lambda (screen)
             (format "%d%s %s"
                 screen (elscreen-status-label screen)
                 (get-alist screen screen-to-name-alist)))
           screen-list " ")))
      (if (fboundp 'set-frame-name)
      (set-frame-name title)
    (setq frame-title-format title)))))
 
(eval-after-load "elscreen"
  '(add-hook 'elscreen-screen-update-hook 'elscreen-frame-title-update))

;; 既存スクリーンのリストを要求された際、0 番が存在しているかのように偽装する
(defadvice elscreen-get-screen-list (after my-ad-elscreen-get-screenlist disable)
  (add-to-list 'ad-return-value 0))

;; スクリーン生成時に 0 番が作られないようにする
(defadvice elscreen-create (around my-ad-elscreen-create activate)
  (interactive)
  ;; 0 番が存在しているかのように偽装
  (ad-enable-advice 'elscreen-get-screen-list 'after 'my-ad-elscreen-get-screenlist)
  (ad-activate 'elscreen-get-screen-list)
  ;; 新規スクリーン生成
  ad-do-it
  ;; 偽装解除
  (ad-disable-advice 'elscreen-get-screen-list 'after 'my-ad-elscreen-get-screenlist)
  (ad-activate 'elscreen-get-screen-list))

;; スクリーン 1 番を作成し 0 番を削除 (起動時、フレーム生成時用)
(defun my-elscreen-kill-0 ()
  (when (and (elscreen-one-screen-p)
             (elscreen-screen-live-p 0))
    (elscreen-create)
    (elscreen-kill 0)))

;; フレーム生成時のスクリーン番号が 1 番になるように
(defadvice elscreen-make-frame-confs (after my-ad-elscreen-make-frame-confs activate)
  (let ((selected-frame (selected-frame)))
    (select-frame frame)
    (my-elscreen-kill-0)
    (select-frame selected-frame)))

;; 起動直後のスクリーン番号が 1 番になるように
(add-hook 'after-init-hook 'my-elscreen-kill-0)

;; M-0 ～ M-9 で指定番号のスクリーンに切り替え
(let ((i 0))
  (while (<= i 9)
    (define-key esc-map (number-to-string i)
                        `(lambda () (interactive) (elscreen-goto ,i)))
    (setq i (1+ i))))

;;goto-line
(global-set-key "\C-z" 'goto-line)
