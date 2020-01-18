=====
websh
=====

`シェル芸botのDockerイメージ`_ を利用したWeb移植。

* https://websh.jiro4989.com/

|image-top|

.. contents:: 目次

背景
====

`シェル芸Bot`_ のWeb移植の SGWeb_ というWebアプリがある。

最新のシェル芸botに追従してなかったので、試しに自分が最新のシェル芸botに追従する
Webアプリ作って公開してみるか、と思ったから。
あとWebアプリを作る勉強もかねて。

システム構成
============

* フロントエンド

  * Nim_ ( Karax_ )

* バックエンド

  * Nim_ ( Jester_ )
  * Docker

ローカル環境
------------

シェル芸botのDockerコンテナをDockerコンテナ内で起動したくなかった(docker on docker)ので
websh_serverをホストPCで実行するようにしている。

nginxはコンテナ内からホストPCのwebsh_serverにリバースプロキシしてシェル芸botコンテナを操作する。

|image-local|

本番環境
---------

Infrastructure as Codeしている。
ソースコードは infra_ リポジトリ（非公開）で管理。
以下はアプリレベルでの構成図。

|image-system|

URLレベルでのアクセスフローは以下。

|access-flow|

API
====

実体はフロントエンドのHTMLからAPIリクエストして実行結果を受け取ってるだけです。
なので普通にcurlでPOSTリクエスト送れば画面がなくても動きます。

以下のようなリクエストを送ればコマンドラインからwebshを使用できます。

.. code-block:: shell

   curl -X POST -d '{"code":"echo hello"}' 'https://websh.jiro4989.com/api/shellgei'

開発
====

前提条件
--------

以下のツールがインストールされている必要があります。

* Nim_
* docker
* docker-compose

ファイル・ディレクトリ構成
--------------------------


=====================   ========================================
Path                    Description
=====================   ========================================
docs                    READMEの画像ファイルなど
proxy                   ローカル開発用のnginxの設定
websh_front             フロントエンドのソースコード
websh_server            バックエンドのソースコード
config.nims             タスク定義
Dockerfile              ローカル開発でのみ使用する
docker-compose.yml      ローカル開発でのみ使用する開発環境設定
docker-compose-ci.yml   GitHub Actionsでのみ使用する
=====================   ========================================


開発環境の起動方法
------------------

リポジトリのルート直下の `config.nims` にリポジトリ内で使用するタスクを定義して
いる。
以下のコマンドをリポジトリディレクトリ配下で実行する。

.. code-block:: shell

   # 最初の一度、あるいはDockerイメージを更新したいときだけ実行
   nim --hints:off pullShellgeiBotImage

   # 開発環境の起動
   nim --hints:off run

サーバを起動して待機状態になったら、ブラウザで以下のページにアクセスする。

http://localhost

ブランチ運用
------------

以下の5種類のブランチを使う。

================   =============================================================================
Branch name        Description
================   =============================================================================
master             本番用
develop            たまに使うが基本放置
feature/#xx-desc   新機能、UI改善
hotfix/#xx-desc    バグ修正
chore/#xx-desc     CIやローカル開発環境の整備など、アプリに影響しない雑多なもの
================   =============================================================================

feature, hotfix, choreのブランチ名のプレフィックスは、PR作成時のラベル自動付与にも使用している。
よって、必ずブランチ命名規則を守ること。

1つずつリリースしたいので各ブランチからmasterにPRを出す。
複数の改修をまとめてリリースしたい時だけdevelopブランチを使う。

ドキュメントの更新だけの場合はmasterブランチから直接pushする。
この時は必ずコミットログに `[skip ci]` を含めなければならない。
masterブランチのCIが走るとリリースドラフトが生成されてしまうため。
詳細は CI のセクションを参照。

フロントエンド
--------------

`websh_frontディレクトリ配下のREADME`_ を参照。

バックエンド
------------

`websh_serverディレクトリ配下のREADME`_ を参照。

CI
----

`.github` ディレクトリ配下にワークフローを定義している。
ビルド、テスト、デプロイのフローは `.github/workflows/main.yml` に定義している。

CIのジョブフローは以下。

|image-ci-flow|

masterブランチでのpush、margeの場合は `create-tag-draft` が実行される。

`create-tag-draft` ではタグのドラフトを作成する。
タグのドラフトは、PRの説明から自動でセットされる。
Feature/BugFixなどの分類は、 PR時のラベルでカテゴライズされる。

PR時のラベルはブランチのプレフィックスから自動でセットされる。
ブランチ命名規則については <<開発,ブランチ運用>> を参照。

タグドラフトをpublishすると `deploy` が実行され、サーバ上にmasterのビルド成果物をデプロイする。

デプロイ方法
------------

前述のCIの通り、リリースを作成すると自動でデプロイされる。

リリースの下書きはGitHub Actionsが下書きを作成する。
下書きをpublishすると、GitHub Actionが起動して、デプロイされる。
以下はデプロイのフロー。

|image-release-flow|

プルリクエスト
==============

デザインとか超手抜きですので、プルリクエストお待ちしてます。

LISENCE
=======

Apache License

多謝
====

* `シェル芸Bot`_
* `シェル芸botのDockerイメージ`_
* SGWeb_

.. _`シェル芸botのDockerイメージ`: https://github.com/theoremoon/ShellgeiBot-Image
.. _`シェル芸Bot`: https://github.com/theoremoon/ShellgeiBot
.. _SGWeb: https://github.com/kekeho/SGWeb
.. _infra: https://github.com/jiro4989/infra
.. _`websh_frontディレクトリ配下のREADME`: ./websh_front/README.rst
.. _`websh_serverディレクトリ配下のREADME`: ./websh_server/README.rst

.. |image-top| image:: ./docs/top.png
.. |image-local| image:: ./docs/local.svg
   :alt: ローカル環境の構成図
.. |image-system| image:: ./docs/system.svg
   :alt: システム構成図
.. |image-ci-flow| image:: ./docs/ci-main.svg
   :alt: CIフロー
.. |image-release-flow| image:: ./docs/release_flow.svg
   :alt: リリースフロー
.. |access-flow| image:: ./docs/access_flow.svg
   :alt: アクセスフロー

.. _Nim: https://nim-lang.org/
.. _Karax: https://github.com/pragmagic/karax
.. _Jester: https://github.com/dom96/jester
