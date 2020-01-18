===========
websh_front
===========

.. contents:: 目次

開発言語
========

* Nim_

フレームワーク
==============

* Karax_ (SPAフレームワーク)
* Bulma_ (CSSフレームワーク)

フロントエンド構成
==================

`public/index.html` がページの起点。
`public/index.html` から `public/js/index.js` を読み込んで画面を描画する。

`public/js/index.js` は以下のビルドによって生成される。
リリースの際はindex.htmlとjsを一緒にtar.gz圧縮してまとめてリリースする。

ビルド方法
==========

以下のコマンドを実行する。

.. code-block:: shell

   # ローカルビルド
   nimble build -d:local

   # 本番向けビルド
   nimble build

アプリ起動方法
==============

`リポジトリ直下のREADME`_ を参照。

.. _`リポジトリ直下のREADME`: ../README.rst
.. _Nim: https://nim-lang.org/
.. _Karax: https://github.com/pragmagic/karax
.. _Bulma: https://bulma.io/
