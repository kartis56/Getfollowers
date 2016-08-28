＜作成趣旨＞
相互フォロワーなどにSPAM業者が多く見受けられるので
そのフォロワーを手繰って一括してR4Sを楽に行い管理するために開発する

今までテキストファイルにリストなどからユーザ名をコピペして、エディタのマクロで抽出・ソートマージしてR4Sしていたが
リストやフォロワーの全件取得をブラウザから行うのは非常に重く、数万件フォロワーがあるようなものはAPI限界などで途中までしか取れなかったりするので
まともにやるにはAPIを使うしかなくなった
これら手順を半ば機械的に行うことを目的としてプログラム群を作成する。

大本の入力はspamer.txtとする。手作業での手順は、spamer.txtのユーザのフォロワーを取得し、その中から連番・botなどをR4sしてspamer.txtへ追記していた。
また、相互フォローなどのbotタグからユーザ（screen_name）を抽出・ソートマージしてspamer.txtへ追記していた
R4sする際は外部ツールを使っていたが、そのツールでは、自分がフォローしているアカウントは自動的に除外してR4sできた。

＜Todo＞

１．SPAMユーザのフォロワーを取得して、ブロック済み以外を除外したリストを作る （既存のR4Sアプリなどで報告できる）[followers2Unknown]
   (作成済み get_follwers.pl )

 1.1 Unknownテーブルを作る
    （テーブル作成済み、テキストからロードするsql作成済み）
 1.2 テキストロードしたUnknownにidを付ける (usersのscreen_nameと同じならupdateするsql 作成済み)
     (完成・完了 テキストからロードしたものに対してidを取得してupdateする。id取得できなかった物は削除  get_users_Unknown.pl ）
 1.3 blockedテーブルとuserテーブルができたら、APIより先にそっちでブロック済みかチェックして、取得したidをひたすらUnknownへ格納する（なるべくlookup_userしない）
     まずテーブル見ないでAPI使ってチェックして、Unknownとuser_idsへ格納するだけにする。userのチェックロジックが面倒なため
    （未実装  get_follwers_list.pl）


２．ブロック済みかどうかはuser情報取得しないとならないが、API限界が少ないのでブロック済みはキャッシュしておきたい。このため、ブロック済みidを一括取得しておく
  （完了 blockedテーブル作成済み、ブロック済み取り込み済み  get_blocked.pl）

 2.1 単発でブロックしたものをテキストからblockedテーブルに取り込みたい（userテーブルも更新・追加する）
    APIの blocked_listを使って100件取得ごとにblockedやuserテーブルへ追加する。追加できないならテーブルへの処理済みなのでそこで終了
  （未着手  get_blocked_list.pl）


３．ブロック済みテーブルをつかってuser情報を取得してuserテーブルに格納する。格納済みはdoneをtrueにする。取得できなかったものはブロック済みから削除
  （完了 get_users.pl）

４．フォローしている・されている人のid、screen_nameを取得してWhitelist に入れる（R4sで除外するため）
   (完了 add_white_list.pl 実行済み ただしファイル入力）

５．UnknownテーブルからBlockedにない、登録回数の多順でリスト化してR4S用テキストを作る（出力後削除）[Unknown2R4s]
  （一応完了 report_Spam.pl）4R4sがなければインサート、あればR4sしてBlockedへ追加、Unknownを削除。user自体が無いならuser_idsをdeletedへ更新、Unknown,Blockedを削除

 5.1 R4S用リスト(R4S.txt)を使ってR4Sをする。かつ、１のフォロワー取得リストへ追加する [R4s2follower]
   （一応完了  report_Spambytext.pl） <<R4S.txt から削除はしないので手作業になる>>
    Blockedへ追加、Unknownを削除。user自体が無いならuser_idsをdeletedへ更新、Unknown,Blockedを削除
 
 作業後はspamer.txtへ追加する

６．rate_limitを確保しておいて、上記コードでループの度に習得しないで済むようにする
  （完了 get_rate_limit.pl）


７．Twitterのリストからuserを取得してBlockedにないユーザをUnknownに格納する（まずは１と同じ動作とし、いずれBlockedを参照するよう修正する）




最終的に動かすのは
手作業で逐次
report_Spambytext.pl   

バッチなどでいつも（ただし以下の二つは排他）
report_Spam.pl      get_follwers_list.pl

アカウント削除などを同期するために不定期に実行する必要がある
get_blocked_list.pl
