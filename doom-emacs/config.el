;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; ---------------------------------------------------------------------------
;; Appearance
;; ---------------------------------------------------------------------------

(setq doom-font (font-spec
                 :family "Fira Mono"
                 :size 16))

(setq doom-theme 'doom-vibrant)

;; Relative line numbers
;; (setq display-line-numbers-type 'relative)

;; ---------------------------------------------------------------------------
;; Cursor
;; ---------------------------------------------------------------------------

;; Clean modern bar cursor
(setq-default cursor-type 'bar)

;; Smooth cursor blinking
(blink-cursor-mode 1)

(setq blink-cursor-interval 0.6
      blink-cursor-delay 0.2
      blink-cursor-blinks 0)

;; ---------------------------------------------------------------------------
;; Ultra-scroll / smooth scrolling
;; ---------------------------------------------------------------------------

;; Required by ultra-scroll.
(setq scroll-margin 0)

(setq scroll-conservatively 101
      scroll-preserve-screen-position 'always

      ;; Horizontal scrolling
      hscroll-margin 5
      hscroll-step 1

      ;; Mouse wheel scrolling
      mouse-wheel-scroll-amount '(1 ((shift) . 1))
      mouse-wheel-progressive-speed nil
      mouse-wheel-follow-mouse t)

;; ---------------------------------------------------------------------------
;; Helpful visual feedback
;; ---------------------------------------------------------------------------

(show-paren-mode 1)
(column-number-mode 1)
(global-hl-line-mode 1)

;; ---------------------------------------------------------------------------
;; Extra smooth pixel scrolling
;; ---------------------------------------------------------------------------

(when (fboundp 'pixel-scroll-precision-mode)
  (pixel-scroll-precision-mode 1))

;; Treemacs on the right side
(setq treemacs-position 'right)
