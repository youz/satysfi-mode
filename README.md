# satysfi-mode for xyzzy

xyzzyで[SATySFi](https://github.com/gfngfn/SATySFi)を書く人用


## Window版SATySFi
[こちら](https://github.com/qnighy/satysfi-cross-windows)からインストールしましょう


## .xyzzy設定例

```lisp
(in-package "user")

(require "satysfi-mode")
(push '("\\.satyh?$" . satysfi-mode) *auto-mode-alist*)

;; SATySFiコマンドとlibディレクトリのパス設定
(setq satysfi-mode:*satysfi-cmd* "C:/path/to/satysfi.exe"
      satysfi-mode:*satysfi-lib* :env)  ; 環境変数 %SATYSFI_RUNTIME% から取得

;; browserexでpdfプレビューする場合
(require "satysfi-bx")
(satysfi-mode.bx:setup)

;; 他お好みでhook設定
(add-hook 'satysfi:*satysfi-mode-hook* 'colorize-paren)
(add-hook 'satysfi:*before-compile-hook* 'save-buffer)
```


## keymap

- `C-c c`    - コンパイル実行
- `C-c C-c`  - コンパイル実行&成功ならPDFを表示
- `C-c C-v`  - コンパイル済みのPDFを表示
- `F10`      - `@require` や `@import`の行で押すと参照先satyhファイルを開く

### コンパイルログバッファでの操作
errorやwarningが出ている場合`F10`でエラー箇所に飛びます


## LICENSE
MIT
