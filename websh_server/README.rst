============
websh_server
============

.. contents:: 目次

開発言語
========

* Nim_

フレームワーク
==============

* Jester_ (sinatra風Webフレームワーク)

バックエンド構成
================

フロントエンドのJSからPOSTリクエストを処理する。

リクエストからシェルのコマンド列を取り出しでシェル芸botのDockerコンテナを起動し
、コンテナ内部でシェルを実行してその実行結果をレスポンスとして返却する。

CORSのチェックはアプリ側では行わず、nginxで行う。

ビルド方法
==========

以下のコマンドを実行する。

.. code-block:: shell

   nimble build

アプリ起動方法
==============

`リポジトリ直下のREADME`_ を参照。

.. _`リポジトリ直下のREADME`: ../README.rst
.. _Nim: https://nim-lang.org/
.. _Jester: https://github.com/dom96/jester
