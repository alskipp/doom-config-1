;;; private-config --- My personal DOOM config file.  -*- lexical-binding: t; -*-

;;;;
;;;; General Settings and Doom Things
;;;;

;; Make Doom shut up about recentf-cleanup
(advice-add #'recentf-cleanup :around #'doom*shut-up)

;; Set user name, big-font, etc.
(setq-default
 user-full-name    "Alex Reinisch"
 user-mail-address "alex.p.reinisch@gmail.com"

 ;; +pretty-code-enabled-modes '(emacs-lisp-mode org-mode)
 ;; +format-on-save-enabled-modes '(not emacs-lisp-mode)

 ;; doom-variable-pitch-font (font-spec :family "Fira Sans")
 ;; doom-unicode-font (font-spec :family "Input Mono Narrow" :size 12)
 ;; TODO: Find a way to ensure `doom-big-font` choice exists
 doom-big-font (font-spec :family "Source Code Pro" :size 19))


;;;;
;;;; THEME
;;;;

;;; Set light and dark theme choices here!
(defvar light-theme 'doom-solarized-light) ; doom-solarized-light doom-nord-light doom-one-light
(defvar dark-theme  'doom-dracula)         ; doom-dracula doom-peacock doom-one doom-nord
(defvar mac-default-theme dark-theme
  "Controls whether default theme is `dark-theme` or `light-theme`.")
;; System agnostic default theme choice goes here:
(setq doom-theme light-theme)           ; set default theme choice

;;; Function for hot-swapping between light and dark themes.
(defun +areinisch/toggle-theme ()
  "Toggle between light and dark themes."
  (interactive)
  (cond ((eq doom-theme dark-theme)
         (message "Toggling to light-theme: %s" light-theme)
         (setq doom-theme light-theme)
         (doom/reload-theme))
        ((eq doom-theme light-theme)
         (message "Toggling to dark-theme: %s" dark-theme)
         (setq doom-theme dark-theme)
         (doom/reload-theme))
        (t (message "Can't toggle theme: not using light-theme (%s) or dark-theme (%s)." light-theme dark-theme))))


;;;;
;;;; macOS specific
;;;;

(when (eq system-type 'darwin)          ; should be the same as (when IS-MAC ...)
  (setq ns-use-thin-smoothing t)        ; Use thinner strokes for font smoothing.
  ;; macOS title-bar fix
  ;; TODO Figure out how to redraw the title-bar to change ns-appearance with theme.
  (add-to-list 'default-frame-alist '(ns-transparent-titlebar . t))
  (add-to-list 'default-frame-alist '(ns-appearance . light)) ; CDR: light | dark

  ;; Set this to nil if you don't want automagical theme switching.
  (defconst use-photometry t
    "Set this to `t` to use photometry, set it to `nil` to not use photometry.")
  (setq doom-theme mac-default-theme)   ; set theme to mac default (dark)

  ;; Photometry
  (when use-photometry
    ;; I want to be able to toggle "photometry" (automatic theme switching),
    ;; but I don't know how to properly build a module or code in elisp.
    (defvar photometry-state nil
      "Tracks whether photometry module is on (true) or off (false).")
    (defvar photometry-timer nil "Timer object used when photometry is on.")

    (defun photometry ()
      "Sense light and change themes.
Function for sensing light and changing themes based on apparent brightness
as reported through lmutracker executable. Adjust the integer compared to
current-light-sensor-reading to change low-light threshold---100000 means it's
fairly dark before switching to dark, higher numbers let you keep a dark theme
even with moderate ambient lighting."
      (let* ((current-light-sensor-reading
              (string-to-number
               (shell-command-to-string
                ;; this assumes you put the `lmutracker` executable
                ;; in your doom-config directory ("~/.doom.d/" or "~/.config/doom/")
                (concat doom-private-dir "lmutracker")))))
        (if (< current-light-sensor-reading 425000) ; test if environment is low-light
            (unless (eq doom-theme dark-theme) ; if theme is not yet dark
              (setq doom-theme dark-theme)     ; change to dark theme
              (doom/reload-theme))
          (when (eq doom-theme dark-theme)     ; if theme is dark
            (setq doom-theme light-theme)      ; change to light theme
            (doom/reload-theme)))))

    (defun photometry/toggle ()
      "Toggle photometry on/off.
Photometry is used to change the theme based on ambient light sensor readings."
      (interactive)
      (if (not photometry-state)                                                 ; test if photometry is currently off
          (progn (message "Photometry ON.")                                      ; print message about new state (ON)
                 (setq photometry-state (not photometry-state)                   ; update state variable
                       photometry-timer (run-with-idle-timer 3 t #'photometry))) ; start timer to run photometry during each idle-time > 3 seconds
        (progn (message "Photometry OFF")                                        ; print message about new state (OFF)
               (setq photometry-state (not photometry-state))                    ; update state variable
               (cancel-timer photometry-timer))))                                ; cancel timer object controlling photometry calls

    ;; Hooks to run photometry at startup.
    (add-hook! 'window-setup-hook #'photometry)        ; run photometry once after doom init
    (add-hook! 'window-setup-hook #'photometry/toggle) ; toggle photometry on

    ;; Keybinding for toggling photometry with `SPC t p`
    (map!
     (:leader
       (:prefix "t"
         :desc "Photometry"   :n "p" #'photometry/toggle)))))


;;;;
;;;; KEYBINDS
;;;;

(map!
 (:after fireplace
   (:map fireplace-mode-map
     "C-+"   #'fireplace-up
     "C--"   #'fireplace-down
     "C-*"   #'fireplace-toggle-smoke
     "C-q"   #'fireplace-off))
 (:after helm-files
   (:map helm-find-files-map
     ;; restores behavior of backspace going up a directory at a time
     "<DEL>" #'helm-find-files-up-one-level))
 ;; (:after smartparens
 ;;   (:map smartparens-mode-map
 ;;     ",s" #'sp-splice-sexp
 ;;     ",f" #'sp-forward-slurp-sexp
 ;;     ",w" #'sp-wrap-round))
 (:leader
   (:prefix "t"
     :desc "toggle-theme"  :n "t" #'+areinisch/toggle-theme
     :desc "Start a fire." :n "z" #'fireplace)))


;;;;
;;;; Modules
;;;;

;;; lang/org
;; Set org agenda file locations.
(setq org-directory (expand-file-name "~/org/")
      doom-directory (expand-file-name "~/.doom.d/")
      arws-organize (expand-file-name "~/Documents/arws-organize/")
      org-agenda-files (list org-directory
                             arws-organize
                             doom-directory))

;;; tools/magit
(when (and (featurep! :tools magit)
           (featurep! :emacs vc))
  ;; Make the VC portion of the modeline correctly update after magit actions.
  (defun +magit|update-vc-post-refresh ()
    (dolist (buf (buffer-list))
      (with-current-buffer buf
        (let ((revert-buffer-in-progress-p t))
          (vc-refresh-state)))))
  (add-hook 'magit-post-refresh-hook #'+magit|update-vc-post-refresh))
