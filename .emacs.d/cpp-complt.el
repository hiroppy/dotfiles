;; cpp-complt.el --- Inserting cpp instruction with completion and selecting header with mouse.

;; Copyright (C) 1996, 1997 Masatake YAMATO.

;; Author: Masatake YAMATO <masata-y@is.aist-nara.ac.jp>
;; Keywords: cpp, c, completion

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.

;; 		  ----cpp-complt.elの使いかた----
;; 	    Masatake YAMATO <jet@airlab.cs.ritsumei.ac.jp>
;; 		      <Tue Apr  9 21:55:53 1996>
;; 			For 20th: cpp-complt.el
;; 
;; * インストールの方法: (10thとはインストールの方針が変ったので注意)
;; 
;; (1) cpp-complt.elをemacs lispのディレクトリに置く。
;; 
;; (2)hookに引っ掛けたキーを割り当てを.emacsに書く。
;; 例えば, c-modeで使う場合:
;;  (add-hook 'c-mode-hook 
;;      	  (function (lambda ()
;;                     (require 'cpp-complt)
;;                     (define-key c-mode-map [mouse-2]
;;                                 'cpp-complt-include-mouse-select))
;; 		      (define-key  c-mode-map "#" 
;;                                  'cpp-complt-instruction-completing)
;; 		      (define-key c-mode-map "\C-c#" 
;;                                  'cpp-complt-ifdef-region)
;;                                   (cpp-complt-init))))
;; 
;; cc-modeを使っていれば次のようにしてもよい。
;; (add-hook 'c-mode-common-hook 
;;      	  (function (lambda ()
;;                     (require 'cpp-complt)
;;                     (define-key (current-mode-map) [mouse-2]
;;                                 'cpp-complt-include-mouse-select)
;; 		      (define-key (current-mode-map) "#" 
;;                                  'cpp-complt-instruction-completing)
;; 		      (define-key (current-mode-map) "\C-c#" 
;;                                  'cpp-complt-ifdef-region)
;;                                  (cpp-complt-init))))
;; 
;; (3)必要であればヘッダファイルのパスのリスト設定する。
;; #includeの後<>で囲んでヘッダファイル名を挿入したいファイルのある場所を
;; cpp-complt-standard-header-path
;; に
;; " "で囲んでヘッダファイル名を挿入したいファイルのある場所を
;; cpp-complt-own-header-path
;; にリストとして設定する。デフォルトでは
;; 
;; (defvar cpp-complt-standard-header-path (list "/usr/include") 
;;   "*Standard headers file path list.")
;; 
;; (defvar cpp-complt-own-header-path ()
;;   "*User own headers file path list.")
;; となっている。
;; カレントディレクトリは常に調査されるので設定に入れる必要はない。
;; 
;;  例:
;; (setq cpp-complt-own-header-path 
;; 	       (list "~/lib/include" "~/project/header"))
;; (setq cpp-complt-standard-header-path 
;; 	       (list "/usr/include" "/usr/local/include"))
;; 
;; 
;; * 使用
;; 
;; ** マウスによるヘッダファイルの選択
;; インクルードファイルのある行でmouseの第二ボタンをクリックするとそのファ
;; イルを表示します. 
;; 前置引数を与えて実行すると, 他のフレームに表示します. 
;; ヘッダファイル名部分にマウスポイントが近づくと反転させる属性の更新には
;; C-lできます. 
;; 
;; ** 補完
;; 上で設定したモード(ここではc-mode)のバッファの*行頭*で'#'を押す。すると
;; 次に示す, cppへの命令とそれ以外の幾つかの命令を補完をともなって取る。
;; (幾つかの意味の分りにくい命令は補完の為である。)
;;  "else"
;;  "include"
;;  "define"
;;  "undef"
;;  "if"
;;  "elif"
;;  "ifdef"
;;  "ifndef"
;;  "endif"
;;  "pragma"
;;  "standard-add"
;;  "own-add"
;;  "frame"
;;  "window"
;;  "look"
;;  "."
;;  "reset" 
;;  "#"
;; 
;; (1) "else", "pragma".
;; その命令自身を挿入する. 
;; 
;; (2) "include".
;; この後ヘッダファイル名を補完して取る。includeは先の述べたルールで括弧
;; を付けて挿入する。
;; 
;; (3) "define", "if", "elif", "undef", "ifdef", "ifndef", "endif".
;; 引数あるいは条件を読み挿入する. 
;; ifの条件部の左辺, 右辺の入力を右辺と左辺を等号(==)で結ぶことを前提に入
;; 力が要求されるが, 左辺に条件全体を書き右辺を省略することでこの仕様から
;; のがれることができる。(？)
;; 現在のバッファでdefineされているものなら, 補完できる. 
;; 
;; (4) "reset": 
;; standard-header-pathにあるヘッダファイル名の連想配列は最初の一回目に作
;; りそれを(セッション中)使い続ける。このコマンドはその連想配列を破棄する。
;; そののち, 再構築する. 
;; (但し"standard-add"を行った場合自動的に連想配列は破棄されるので
;;  "standard-add"実行後resetする必要はない。)
;; 
;; (4)  "look",  ".", "frame", "window": 
;; ポイントに前でincludeが指示されているfileを探しに行く。
;; look,"." は現在のウィンドウに, frameは他のフレームに, window, ","は他
;; のウィンドウに表示する。
;; 
;; (5) "#":
;; '#'自身を挿入する。
;; 
;; ** ifdef regionの利用
;; "\C-c#" でregionを#ifdef #endifで囲む。
;;                   ~~~~~~
;; "\C-u\C-c#" でregionを#ifndef #endifで囲む。
;;                       ~~~~~~~
;; * その他
;; 19thからヘッダファイルのパスを情報をファイル
;; (デフォルトでは~/.header_dump)に書き出しをできるようにした. 
;; 変数cpp-complt-always-dumpをnilを与えることで, これをやめさせることが
;; できる. 
;; 
;; * TODO
;; own-header-file-alistをTAGSから得るようにする。
;; 

;; Commentary:

;;+Intro
;; This program supports two things:
;;
;;  To insert a C preprocesseror instruction and header file name 
;; with completing. Typing '#' is the triger of completing.
;;
;;  To find header file near the cursor or mouse point(with mouse
;; button clicking) and show it on a buffer.

;;+Install
;;  First, put this file in the lisp directory. Then put next code into 
;; your .emacs:
;;
;; <If you use other mode, change the hook symbol properly.>
;; (add-hook 'c-mode-hook 
;;     	  (function (lambda ()
;;                    (require 'cpp-complt)
;;                    (define-key c-mode-map [mouse-2]
;;                                'cpp-complt-include-mouse-select))
;;		      (define-key  c-mode-map "#" 
;;                                 'cpp-complt-instruction-completing)
;;		      (define-key c-mode-map "\C-c#" 
;;                                 'cpp-complt-ifdef-region)
;;                                  (cpp-complt-init))))
;; <Or if you use cc-mode>
;; (add-hook 'c-mode-common-hook 
;;     	  (function (lambda ()
;;                    (require 'cpp-complt)
;;                    (define-key (current-mode-map) [mouse-2]
;;                                'cpp-complt-include-mouse-select)
;;		      (define-key (current-mode-map) "#" 
;;                                 'cpp-complt-instruction-completing)
;;		      (define-key (current-mode-map) "\C-c#" 
;;                                 'cpp-complt-ifdef-region)
;;                                 (cpp-complt-init))))
;;
;;  Second, set variables, 'cpp-complt-standard-header-path' and 
;; 'cpp-complt-own-header-path' properly if need be.
;; These variables are referred at header file name completing.
;; ---------------------------------------------------------------------
;;   The author defined 'own header' as a file name string which is
;; surrounded with double quotations in a C source code files.
;;  And author defined 'standard header' as a file name string which is
;; surrounded with angle brackets.
;; ---------------------------------------------------------------------
;;  Each two variables should be list.
;;  "/usr/include" is given as a default value of 
;; 'cpp-complt-standard-header-path'. None is given as the default
;; value of 'cpp-complt-own-header-path'. But "." (current directory) is
;; always reffered at header file name completing. So don't add "." to
;; 'cpp-complt-own-header-path'.
;;
;;  <Example>
;;  If you have your own header file directories at ~/lib/include 
;; and ~/project/header , put next to your .emacs file:
;; (setq cpp-complt-own-header-path 
;;       (list "~/lib/include" "~/project/header"))
;; To check "/usr/local/include" as standard header files directory:
;; (setq cpp-complt-standard-header-path 
;;       (list "/usr/include" "/usr/local/include"))
;;
;;  <Note>
;; The function which builds the header file names associative list
;; works following rules:
;;  Adding all files matching with '*.h' in each directory of 
;; 'cpp-complt-own-header-path', 'standard-header-path' and ".".
;;  And adding all files matching with *.h files in all direct sub 
;;  directories of all members in 'cpp-complt-own-header-path'
;; , 'standard-header-path' and ".".

;;; ChangeLog:
;;   33th, Wed Aug 20 22:59:00 1997 (masata-y@is.aist-nara.ac.jp)
;;      o New suffix, `.hh' for C++ header files.
;;   32th, Sun May 18 08:07:10 1997 (masata-y@is.aist-nara.ac.jp)
;;      o Change the regexp to find a "#include" line.
;;        Now recognize the tab character between "#include" and
;;        a header file name.
;;   31th, Sat Apr 26 18:44:29 1997 (masata-y@is.aist-nara.ac.jp)
;;      o Change the const string inserted after "#endif" in
;;        the function `cpp-complt-ifdef-region'.
;;   30th, Sat Apr 19 05:55:58 1997 (masata-y@is.aist-nara.ac.jp)
;;      o Use `cpp-complt-scan-define' to read an argument 
;;        interactively in `cpp-complt-ifdef-region'.
;;   29th, Fri Apr 18 21:18:24 1997 (masata-y@is.aist-nara.ac.jp)
;;      o New function `cpp-complt-generate-header-siege'.
;;   28th, Thu Mar 20 19:58:29 1997 (jet@airlab.cs.ritsumei.ac.jp)
;;      o Fix wrong regular expressions. 
;;   27th, Fri Aug 30 13:25:13 1996 (jet@idaten)
;;      o Add a variable declaration `file' in `let' block in
;;        `cpp-complt-build-header-file-alist-here'.
;;   26th, Thu Aug 29 04:55:45 1996 (jet@sgr)
;;      o Esteem user paren selection in `cpp-complt-complete-header-file'.
;;   25th, Fri Aug 23 04:47:20 1996 (jet@grus)
;;      o Add new function(subst) `cpp-complt-string-asooc'
;;        to work on mule2.3-19.31. `assoc' cannot find 
;;        a string with text properties.
;;        All `assoc' are replaced with `cpp-complt-string-asooc'.
;;   24th, Fri Aug 23 03:52:53 1996 (jet@grus)
;;      o Replace `equal' with `string='.
;;      o Rename the function `cpp-complt-mapequal' to `cpp-complt-map-string='.
;;   23th, Fri Jul 12 16:52:37 1996 (jet@raga)
;;      o Fix bug in `cpp-complt-ifdef-region'.
;;      o Fix typo in `cpp-complt-build-own-header-file-alist'.
;;   22th, Thu May 16 17:04:51 1996
;;      o If null-string is given as a header file name, insert only `#include'.
;;        Double quotes are never inserted.
;;      o Add an user option cpp-complt-always-taking-universal-arg.
;;      
;;       Thanx to Masahioro `bee' Hachiya<masahiro@airlab.cs.ritsumei.ac.jp>
;;       for good suggestions.
;;
;;   21th, Thu Apr 25 17:57:43 1996
;;      o Fix a bug(infinity roop) reported from SHOHEI NODA<scs30119.bkc.ritsumei.ac.jp>.
;;   20th, Wed Apr 10 20:10:23 1996
;;      o ReRe-write documentas.
;;      o Change the header file display policy.
;;        If header file name is selected with the mouse, display 
;;        it on the other window. 
;;   19th, Wed Apr  3 19:48:59 1996
;;      o Jump unreadable directory.
;;   18th, Tue Apr  2 19:30:59 1996
;;      o Change cpp-complt-scan-define.
;;   17th, Tue Apr  2 11:56:05 1996
;;      o Clean up and split the function 'cpp-complt-complete-header-file'.
;;      o Implement read-function and write-function for the headfile list dump.
;;   16th, Fri Mar 29 19:36:47 1996
;;      o Implementation 'cpp-complt-scan-define'.
;;   15th, Fri Mar 29 18:59:13 1996
;;      o Fixed a mouse commnad bug.
;;   14th, Fri Mar 29 00:58:25 1996
;;      o Use 'cons' in place of 'nconc'.
;;   13th, Wed Mar 27 01:44:02 1996
;;      o Use 'nconc' in place of 'append'.
;;   12th, Tue Mar 26 19:54:46 1996
;;      o Improvem the ouse command 'cpp-complt-include-mouse-select'.
;;   11th, Wed Mar 20 15:02:38 1996
;;      o Implementat header file selection with mouse.
;;   10th, Sun Mar  3 09:46:03 1996
;;      o Change program name.
;;      o Clean up doc and comment.
;;      o Change working dir.
;;      o Fj debut.
;;   9th, Thu Feb 29 23:32:51 1996:
;;      o Re-change the input style of #if command condition.
;;   8th, Thu Feb 29 01:08:29 1996:
;;       o Change the input style of #if command condition.
;;        * Thanx to SHOHEI NODA<scs30119.bkc.ritsumei.ac.jp> 
;;        for bug report and good suggestion. 
;;       o Fix elif bus.
;;       o Remove: #find command.
;;       o New: #frame command.
;;       o Quick alist building.
;;   7th, Tue Feb 27 16:28:51 1996:
;;       o Clean up the regexp.
;;   6th, Fri Nov 24 00:32:27 1995: 
;;       o Remove slash in dir string automaticly. But more work needed.
;;   5th, Thu Nov 23 21:51:42 1995: Brush up documentation.
;;   4th, Tue Nov 21 06:15:28 1995: Header file name completion.
;;   3rd, Mon Oct 16 20:39:32 1995: Brush up documentation(Net debut).
;;   2nd, Mon Sep 18 16:05:56 1995: Check beginning of line.

;;; X-Working-song:
;; 29th: kd.lang, all you can eat
;; 26th: Luscious Jackson, Natural Ingredients
;; 22th: Anne Claire Marin.
;; 20th: Underworld, second toughest in the infants, juantia.
;; 13th: EverythingButTheGirl, missing<single>.
;; 12th: Joan Osborne, relish, One of us.
;; 11th: CLoudberryJAM, PROVinding the ATMOSPHERE, CLICES.
;;  9th: Bjork, Human Behaviour[The Underworld Mix].

;;; TODO:
;; Refering to TAGS file :own-path
;; Use 'nconc' more in place of 'append'.
;; Support '#import' against grain :-P.

;;; Code:
(provide 'cpp-complt)
(require 'cl)				; For 'mapcar*'
;;
;; User Options.
;;
(defvar cpp-complt-standard-header-path '("/usr/include") 
  "Standard headers file path list.")

(defvar cpp-complt-own-header-path ()
  "User own headers file path list.")

(defvar cpp-complt-dump-file "~/.header_dump"
  "Name of file to read header files name list.")

(defvar cpp-complt-always-dump t	; Need more work(doc)
  "*Non-nil means always dumping out header file names list when the list is built.")

(defvar cpp-complt-always-taking-universal-arg nil
  "*If non-nil, calling `cpp-complt-instruction-completing' with prefix argument
the function behaves as `self-insert-command'. If nil, calling the function 
with prefix argument inserts one `#'.")

;;
;; Interanl Vars.
;;
(defvar cpp-complt-standard-header-path-alist () 
  "Standard header filenames assoc list for completing.
Once this assoc list is built, this is never changed during 
the session unless #reset command is used in 'cpp-complt-instruction-completing'.")
;;
;; Front end funs.
;;
(defun cpp-complt-instruction-completing (arg)
  "Read cpp instruction from minibuffer with completing.
There are some virtual instructions.
This command only works if the point is at the beginning of line.
If the point is not there or given prefix argument ARG,
this command behaves as 'self-insert-command' if 
`cpp-complt-always-taking-universal-arg' is t, else insert only one `#'.

instructions: After calling this function you should type 
following instructions.

(1) \"else\", \"pragma\", \"#\".
Insert itself.

(2) \"include\".
Read header file name with completion and insert it with paren.

(3) \"define\", \"if\", \"elif\", \"undef\", \"ifdef\", \"ifndef\", \"endif\".
Read arguments(or if-condition) for the command and Insert them.

(4) \"reset\".
Clear the 'cpp-complt-standard-header-path-alist' and rebuild 
'cpp-complt-standard-header-path-alist'.

(5) \"standard-add\", \"own-add\".
Add new path to the 'cpp-complt-standard-header-path' or '
cpp-complt-own-header-path'.  If the new path added to the '
cpp-complt-standard-header-path', 
'cpp-complt-standard-header-path-alist' is cleared.

(6) \"look\", \".\", \"window\", \"frame\".
Find header file included near at the point. \"window\" shows it on
the other window. \"frame\" shows it on the other frame.

(7)\"save\".
Write out header file name associative list to the file.
'cpp-complt-dump-file' specifies the output filename.

(8) \"#\".
    Insert \"#\" itself."
  (interactive "P")
  (if arg
      (if cpp-complt-always-taking-universal-arg
	(self-insert-command (prefix-numeric-value arg))
	  (insert "#"))
    (if (bolp)
	(cpp-complt-instruction-insert
	 (completing-read "CPP instraction:#"
			  '(("else")
			    ("include") ; Should support import for Stepers.
			    ("define")
			    ("undef")
			    ("if")
			    ("elif")
			    ("ifdef")
			    ("ifndef")
			    ("endif")
			    ("pragma")
			    ("save")
			    ("standard-add")
			    ("own-add")
			    ("frame")
			    ("window")
			    ("look")
			    (".")	; alias for "look"
			    ("reset")
			    ("#")))) ;self insert
      (self-insert-command (prefix-numeric-value arg)))))

;; Region surrounding
(defun cpp-complt-ifdef-region (condition nondef)
  "Insert #ifdef and #endif around the region with condition CONDITION.
With prefix argument, NONDEF insert #ifndef and #endif around the 
region."
  (interactive (list 
		(completing-read
		 (if current-prefix-arg "Not Def: " "Def: ")
		 (cpp-complt-scan-define))
		current-prefix-arg))
  (save-excursion 
    (goto-char (region-beginning))
    (let ((inst (if nondef "#ifndef " "#ifdef "))) 
      (insert inst condition "\n")))
  (goto-char (region-end))
  (insert "\n#endif /* " 
	  (if nondef "Not def:"
	    "Def:")
	  " "  condition " */"))

;;
;; Interanl Funs
;;

;; Completing instractions.

;; Selector.
(defun cpp-complt-instruction-insert (instruction)
  "Read cpp instruction's arguments for INSTRUCTION from minibuffer and insert them.
INSTRUCTION is the selector for the next action of this function."
  ;; Too many conditions: I should use assoc (instrucion -> fun) list.
  (cond					
   ((string= instruction "else")
    (insert "#else "))

   ((string= instruction "include")
    (insert "#include " (cpp-complt-complete-header-file 'paren)))

   ((string= instruction "define")
    (let 
	((def (completing-read  "Def: " (cpp-complt-scan-define)))
	 (ref (completing-read "Ref: " (cpp-complt-scan-define))))
      (insert "#define " def " " ref)))

   ((string= instruction "ifdef")
    (let (( def (completing-read "If def: "
				 (cpp-complt-scan-define))))
      (insert "#ifdef " def "\n")
      (save-excursion
	(insert "\n#endif" " /* Def: " def " */"))))

   ((string= instruction "if")
    (let* ((ifcondL (completing-read "If: "
				     (cpp-complt-scan-define)))
	   (ifcondR (completing-read
		     (format "[option] %s == " ifcondL)
		     (cpp-complt-scan-define))))
      (if (string= ifcondR "")		
	  (progn			; NULL string
	    (insert "#if " ifcondL "\n")
	    (save-excursion
	      (insert "\n#endif" " /* " ifcondL " */")))
	(insert "#if " ifcondL " == " ifcondR "\n")
	(save-excursion
	  (insert "\n#endif" " /* " ifcondL " == " ifcondR " */")))))

   ((string= instruction "pragma")
    (insert "#pragma " (read-from-minibuffer "Pragma: ")))

   ((string= instruction "endif")
    (let ((end (completing-read "End what: "
				(cpp-complt-scan-define))))
      (if (string= end "")
	  (insert "#endif")
	(insert "#endif" "  /* " end " */"))))

   ((string= instruction "ifndef")
    (let (( ndef (completing-read "If n-def: "
				  (cpp-complt-scan-define)
				  )))
      (insert "#ifndef " ndef "\n")
      (save-excursion
	(insert "\n#endif" " /* Not def: " ndef " */"))))

   ((string= instruction "elif")
    (let* ((ifcondL (completing-read "Elif: "
					  (cpp-complt-scan-define)))
	   (ifcondR (completing-read
		     (format "[option] %s == " ifcondL)
		     (cpp-complt-scan-define)
		     )))
      (if (string= ifcondR "")		
	  (insert "#elif " ifcondL)
	(insert "#elif " ifcondL " == " ifcondR))))

   ((string= instruction "undef")
    (insert "#undef " (completing-read "Undef what: "
				       (cpp-complt-scan-define))))

   ((string= instruction "standard-add")
    (let (tmp)
      (setq tmp default-directory)
      ;; Wrong coding style.
      (cd "/")
      (call-interactively 'cpp-complt-add-standard-header-path)
      (cd tmp)))

   ((string= instruction "save")
    (cpp-complt-dump-alist))

     ((string= instruction "own-add")
    (call-interactively 'cpp-complt-add-own-header-path))

   ((string= instruction "window")
    (let ((flag (cpp-complt-look-include)))
      (if flag
	  (find-file-other-window flag)
	(message "Cannot find.")
	)))
   
   ((or (string= instruction "look")
	(string= instruction "."))
    (let ((flag (cpp-complt-look-include)))
      (if flag
	  (find-file flag)
	(message "Cannot find."))))
   
   ((string= instruction "frame")
    (if window-system
	(let ((flag (cpp-complt-look-include)))
	  (if flag
	      (find-file-other-frame flag)
	    (message "Cannot find.")))
      (message "Use #frame with window system!")
      ))
   
   ((string= instruction "reset")
    (cpp-complt-reset-standard-header-path-alist))

   ((string= instruction "#")
    (insert "#"))

   (t
    (message instruction ": Bad instruction!")
    (insert "#" instruction))))

;; Fri Mar 29 19:39:39 1996
(defun cpp-complt-scan-define ()
  "Return symbol assoc list defined in the current buffer."
  (let ((rtnlist ()))
    (save-excursion
      (goto-char (point-min))
      (while (not (eobp))
	(if (re-search-forward "^# *define +\\([a-zA-Z_0-9]+\\)" nil t)
	      (setq rtnlist
		    (cons (list (buffer-substring (match-beginning 1) (match-end 1)))  rtnlist))
	  (goto-char (point-max))))
      (goto-char (point-min))
      (while (not (eobp))
	(if (re-search-forward "^# *ifdef +\\([a-zA-Z_0-9]+\\)" nil t)
	      (setq rtnlist
		    (cons (list (buffer-substring 
				 (match-beginning 1) (match-end 1)))  rtnlist))
	  (goto-char (point-max))))
      (goto-char (point-min))
      (while (not (eobp))
	(if (re-search-forward "^# *ifndef +\\([a-zA-Z_0-9]+\\)" nil t)
	      (setq rtnlist
		    (cons (list (buffer-substring (match-beginning 1) (match-end 1)))  rtnlist))
	  (goto-char (point-max))))
      (goto-char (point-min))
      (while (not (eobp))
	(if (re-search-forward "^# *if +\\([a-zA-Z_0-9]+\\)" nil t)
	    (setq rtnlist
		  (cons (list (buffer-substring (match-beginning 1) (match-end 1)))  rtnlist))
	  (goto-char (point-max))))
      
      (goto-char (point-min))
      )
    (cons (list (cpp-complt-generate-header-siege)) rtnlist)))

(defun cpp-complt-generate-header-siege ()
  (let* ((fname (file-name-sans-extension
		 (file-name-nondirectory (buffer-file-name))))
	(c)
	(n (- (length fname) 1))
	(result "_H"))
    
    (while (<= 0 n)
      (setq c (aref fname n))
      (cond
       ((and (<= ?a c) 
	     (<= c ?z))
	(setq result (concat (char-to-string (upcase c)) result)))
       ((and (<= ?A c)
	     (<= c ?Z))
	(setq result (if (= n 0)
			 (concat (char-to-string c) result)
		       (concat "_" (char-to-string c) result))))
       ((= ?_ c)
	(setq result (concat (char-to-string c) result))))
      (setq n (1- n)))
  result))
;;
;; Header file name completion.
;;

;; Support stuffs.
(defun cpp-complt-add-standard-header-path (newpath)
  "Add NEWPATH to 'cpp-complt-standard-header-path.'"
  (interactive "DAdd to standard path: ")
  ;; Reset alist
  (cpp-complt-reset-standard-header-path-alist)
  (setq newpath (expand-file-name newpath))
  (if (string= "/" 
	       (substring newpath (1- (length newpath))))
      (setq newpath (substring newpath 0 (1- (length newpath)))))
  (setq cpp-complt-standard-header-path
	(cons newpath cpp-complt-standard-header-path)))

(defun cpp-complt-add-own-header-path (newpath)
  "Add NEWPATH to 'cpp-complt-own-header-path.'"
  (interactive "DAdd to own path: ")
  (setq newpath (expand-file-name newpath))
  (if (string= "/" 
	       (substring newpath (1- (length newpath))))
      (setq newpath (substring newpath 0 (1- (length newpath)))))
  (setq cpp-complt-own-header-path
	(cons newpath cpp-complt-own-header-path)))

(defun cpp-complt-reset-standard-header-path-alist ()
  "Reset 'cpp-complt-standard-header-path-alist.'"
  (interactive)
  (message "Reset standard header file alist.")
  (setq cpp-complt-standard-header-path-alist ())
  (cpp-complt-build-standard-header-file-alist)
  )

;; Header file name complete engine.
;; DUMP
(defvar cpp-complt-standard-header-path-dump-alist nil
  "Dumped 'cpp-complt-standard-header-path-alist'")
(defvar cpp-complt-standard-header-path-dump nil
  "Dumped 'cpp-complt-standard-header-path'")

(defun cpp-complt-undump-alist ()
  "Reload dumped header file names data from file 'cpp-complt-dump-file'.
If dumped file does not exist, return nil. 
Else return 'cpp-complt-standard-header-path-dump-alist'."
  (if (not (file-exists-p  cpp-complt-dump-file))
      ()				; Not exsits: return nil
      (load-library cpp-complt-dump-file)
      (cons cpp-complt-standard-header-path-dump-alist 
	    cpp-complt-standard-header-path-dump)))

(defun cpp-complt-dump-alist ()
  "Write out 'cpp-complt-standard-header-path' to the file specified in 'cpp-complt-dump-file'." 
  (interactive)
  (find-file cpp-complt-dump-file)
  (erase-buffer)
  (insert (format ";; %s -- Headerfile names list dump.\n" cpp-complt-dump-file))
  (insert ";; by cpp-complt.el\n") 
  (insert "(setq cpp-complt-standard-header-path-dump '")
  (prin1 cpp-complt-standard-header-path (current-buffer))
  (insert ")\n")

  (insert "(setq cpp-complt-standard-header-path-dump-alist '")
  (prin1 cpp-complt-standard-header-path-alist (current-buffer))
  (insert ")")
  (save-buffer)
  (kill-buffer (buffer-name)))

(defun cpp-complt-map-string= (a b)
  (if (not (= (length a) (length b)))
      nil
  (let (tmp 
	(flag t))
    (setq tmp (mapcar* 
	       (function (lambda (x y)
			   (string= x y))) a b))
    (mapcar (function 
	     (lambda (x)
	       (if (and flag x)
		   ()
		 (setq flag nil)))) tmp)
    flag)))

(defun cpp-complt-build-standard-header-file-alist ()
  "Set 'cpp-complt-standard-header-path-alist' properly.
The function which builds the header file names associative list
works following rules:
 Adding all files matching with '*.h' in each directory of 
'cpp-complt-own-header-path', 'standard-header-path' and \".\".
And adding all files matching with *.h files in all direct sub 
directories of all members in 'cpp-complt-own-header-path'
, 'standard-header-path' and \".\"."
  (message "Listing...")
  (let ((gc-cons-threshold 1000000)
	(dirlist cpp-complt-standard-header-path)
	direlt)				;element
    (while dirlist
      (setq direlt (car dirlist))
      ;; Remove last "/"
      (if (string= "/" 
		   (substring direlt (1- (length direlt))))
	  (setq direlt (substring direlt 0 (1- (length direlt)))))

      (if (not (file-directory-p direlt))
	  ;; File: Do nothing, It is not directory.
	  ;; Should return warning message?
	  () 
	;; Directory
	(if cpp-complt-standard-header-path-alist
	    (nconc cpp-complt-standard-header-path-alist
		   (cpp-complt-build-header-file-alist 
		    direlt))
	  (setq cpp-complt-standard-header-path-alist
		(cpp-complt-build-header-file-alist 
				 direlt))))
      ;;increment
      (setq dirlist (cdr dirlist))))
  (garbage-collect)
  (if cpp-complt-always-dump
      (cpp-complt-dump-alist))
  (message "Listing done.")
  t)

(defun cpp-complt-build-own-header-file-alist ()
  "Set 'cpp-complt-own-header-file-alist' properly.
About building list policy, read the function description of
'cpp-complt-build-standard-header-file-alist'."
  (let ((dirlist cpp-complt-own-header-path)
	direlt
	(own nil))
    (while dirlist
      ;; Remove last "/"
      (setq direlt (car dirlist))
      (if (string= "/" 
		   (substring direlt (1- (length direlt))))
	  (setq direlt (substring direlt 0 (1- (length direlt)))))
      (if (not (file-directory-p direlt))
	  ()				; Do nothing.
	(if own
	    (nconc own
		   (cpp-complt-build-header-file-alist direlt))
	  (setq own (cpp-complt-build-header-file-alist direlt))))
      (setq dirlist (cdr dirlist)))
    own))

(defsubst cpp-complt-string-assoc (keystring list)
  "String property of KEYSTRING, then call `assoc'."
  (assoc (format "%s" keystring) list))

(defun cpp-complt-complete-header-file (returntype &optional prefile noninteractive)
  "Read a header file name from the minibuffer with completion.
Return the name.
If the first argument RETURNTYPE is full, return the full path to the file.
Else if paren, return surrounded header file name with '<,>' or '\",\"'
 properly.
If the second optional argument, PREFILE is a string, its contents are 
inserted into the minibuffer as initial contents.
If NONINTERACTIVE is t, the filename has not been confirmed its existing in the
completion list."
  (let ((header-alist ());; Used in completion
	(own ());; Part of the header-alist. own-path
	(here ());; Part of the header-alist. ".", current-dir
	str)

    ;; Build cpp-complt-standard-header-path-alist
    ;; Loading
    (if cpp-complt-standard-header-path-alist
	()
      (if (and (cpp-complt-undump-alist)
	       (cpp-complt-map-string= cpp-complt-standard-header-path
				    cpp-complt-standard-header-path-dump))
	  (setq cpp-complt-standard-header-path-alist
		cpp-complt-standard-header-path-dump-alist)
	(setq cpp-complt-standard-header-path-dump-alist nil)
	(cpp-complt-build-standard-header-file-alist)))

    ;; Checking own dirs
    (setq own
	  (cpp-complt-build-own-header-file-alist))

    ;;Checking current directory.
    (setq here
	  (cpp-complt-build-header-file-alist "."))

    ;; Append all ;; Use nconc!
    (setq header-alist 
	  (append here own cpp-complt-standard-header-path-alist))
    ;; Get headfile name from the user.
    (if prefile
	(if (not noninteractive)
	    (setq str 
		  (completing-read "Header file: " 
				   header-alist nil nil prefile))
	  (setq str prefile))
      (setq str (completing-read "Header file: " header-alist)))
    
    (cond 
     ;; Nothing is given with `completing-read' from user
     ((string= str "")
      str)
     ;; File name only.
     ((eq returntype 'full)
      (or (cdr (cpp-complt-string-assoc str header-alist))
	  nil))
     ;; Selecting paren.
     ((eq returntype 'paren)
      (if (cpp-complt-string-assoc str cpp-complt-standard-header-path-alist)
	  (concat "<" str ">")
	;; If paren type is specified by the user,
	;; use it.
	(if (string= (substring str 0 1) "<")
	    (if (string= (substring str -1) ">")
		str			; <foo.h>
	      (concat str ">"))		; <foo.h
	  (concat "\"" str "\"")))))))	; foo.h

(defun cpp-complt-build-header-file-alist (entry)
  "Pick up all header file names in the directory, ENTRY and its immediate sub directories.
Return an assoc list.
The assoc list of key is file name. The value is full path to the key file.
If a file is in a sub directory, the key will be like this:
\"sub-dir-name/the-file-name\"."
  (let ((file-alist ()))		; This value is returned.
    ;; Checking entry dir.
    (setq file-alist 
	  (cpp-complt-build-header-file-alist-here entry nil))
    ;; Checking sub dir.
    ;; Bad var name?
    ;; Ignoring ".." and  "." with cdr^2
    (let ((file-list (cdr (cdr (directory-files entry)))))
      (while file-list
        (if (let ((target (concat entry "/" (car file-list))))
		  (and
		   (file-directory-p target)
		   (file-readable-p target)))
	    (nconc file-alist
		   (cpp-complt-build-header-file-alist-here 
		    (concat entry "/" (car file-list))
		    (car file-list))))
        (setq file-list (cdr file-list))))
    file-alist))

(defun cpp-complt-build-header-file-alist-here (entry-dir swap-for)
  "Pick up all header file names in entry directory. 
Return an assoc list.
The assoc list of key is file name. The value is full path to the key file."
  (let ((files ())			; assoc list(Return)
	file				; Fri Aug 30 13:23:29 1996
        (rdir (directory-files entry-dir))) ; All files in entry.
    (while rdir
      (setq file (car rdir))
      ;; Header file? 
      ;; 'H' and 'hh' for c++.
      (if (string-match "\\.\\(h\\|H\\|hh\\)$" file) 
          (setq files (cons 
		       (cons (if swap-for ; Key
				 (concat swap-for "/" file)
			       file)
			     (concat entry-dir "/" file)) ; Value:full path
		       files)))
      (setq rdir (cdr rdir)))		;inc
    files))				; Return the result

;;
;; Working as file easy file browser.
;;
(defun cpp-complt-look-include ()
  "Find header file included near at the point. And return the name." ;done
  (interactive)
  (let ((fname
	 (save-excursion
	   (beginning-of-line)
	   ;; Pick up
	   (if (re-search-forward		
		"# *include[\t ]*[\"<]\\([_a-zA-Z0-9---./]+\\)[\">]" ; OK?
		nil t)      
	       (cpp-complt-complete-header-file 'full;; Needing full path
						(buffer-substring
						 (match-beginning 1) (match-end 1)))
	     ;; Aborting pick up.
	     (cpp-complt-complete-header-file 'full)))))
    
    (if (and fname (file-exists-p fname))
	fname
      nil)))
;; MOUSE Extention <Tue Mar 19 17:40:54 1996>
(defvar cpp-complt-key-def-backup-for-C-l nil
  "Key definition back up.")

(defun cpp-complt-init ()
  "Initialize cpp-complt.el for using header file selection with mouse."
  (make-variable-buffer-local 'cpp-complt-key-def-backup-for-C-l)
  (if cpp-complt-key-def-backup-for-C-l
      ()
    (fset 'cpp-complt-key-def-backup-for-C-l  
	  (lookup-key (current-local-map) "\C-l"))
    (if cpp-complt-key-def-backup-for-C-l
	()
      (fset 'cpp-complt-key-def-backup-for-C-l
	    (lookup-key (current-global-map) "\C-l")))
    (define-key (current-local-map) "\C-l" 'cpp-complt-face-mapper-drive))
    (cpp-complt-map-face))

(defun cpp-complt-map-face ()
  "Put 'mouse-face' property to the included filename strings in the buffer."
  (save-excursion
    (goto-char (point-min))
    ;; Buffer conditions back up. ;;
    (let ((oldmodp (buffer-modified-p))
	  (oldreadonlyp buffer-read-only)) ; Stack
      (setq buffer-read-only nil)	; Push

      (while (not (eobp))
	(let ((where (cpp-complt-include-position)))    
	  (if where
	      (put-text-property 
	       (car where) (cdr where) 
	       'mouse-face 
	       'highlight)		; change!
	    (goto-char (point-max)))
	  (forward-line 1)))

      (setq buffer-read-only oldreadonlyp) ; Pop
      (set-buffer-modified-p oldmodp)	; Pop
      )))

(defun cpp-complt-include-position ()
  "Return the position of include filename string.
The return value is a list. Its car is start position. 
Its cdr is end position. If fail just return nil."
  (if (re-search-forward		
       "# *include[\t ]*[\"<]\\([_a-zA-Z0-9---./]+\\)[\">]" ; OK?
       nil t)
      (cons (match-beginning 1) (match-end 1))
    nil))

(defun cpp-complt-include-select-file-name ()
  "Return file name string included at the currnet line.
If there is no included header file, return nil."
  (let* ((oldp (point))			; old point
	 (oldl (count-lines (point-min) oldp)) ; old linenum
	 flag)
    (beginning-of-line)
    (setq flag (cpp-complt-include-position))
    (if (= (count-lines (point-min) (point)) oldl)
	flag
      (goto-char oldp)
      nil)))

(defun cpp-complt-include-mouse-select (event &optional arg)
  "Display the file included at the currnet line on the other window.
If prefix argument, ARG is given, Find file other frame.
If there is no included header file, 'mouse-yank-at-click' is called."
  (interactive "e\nP")
  (let (filename flag)
    (save-excursion
      (set-buffer (window-buffer (posn-window (event-end event))))
      (save-excursion
	(goto-char (posn-point (event-end event)))
	(setq filename (cpp-complt-include-select-file-name)))
      (select-window (posn-window (event-end event))))
    (if filename
	(progn
	  (setq filename (buffer-substring
			  (car filename) (cdr filename)))
	  (setq flag (cpp-complt-complete-header-file 'full filename t))
	  (if flag
	      (if arg
		  (find-file-other-frame flag)
		(find-file-other-window flag))
	    (message "Sorry cannot find file: %s." filename)))
      ;;;
      (mouse-yank-at-click event arg)
      (message "Not selecting but yanking.")
      )))

(defun cpp-complt-face-mapper-drive (arg)
  "Put 'mouse-face' property to the included filename strings after calling 'cpp-complt-key-def-backup-for-C-l'."
  (interactive "P")
  (call-interactively 'cpp-complt-key-def-backup-for-C-l)
  (cpp-complt-map-face))

;;; cpp-complt.el ends here
