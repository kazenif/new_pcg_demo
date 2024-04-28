# new_pcg_demo
ちくらっぺさん([@chiplappe](https://twitter.com/chiqlappe))の[新PCG](https://github.com/chiqlappe/new_pcg)のデモ用のライブラリです。40桁×25行で
実行するので、320×200ドットのグラフィックが扱えます。

ソースをいじれば、80桁×40行でも実行可能ですが、その場合は各ブロックの
文字数が640文字となり、256種ではすぐに文字が足りなくなりそうなので、
1ブロックあたり320文字の40桁モードを利用してます。

# 動作原理
最初にPCGのパタンを255で全クリア。ブロック３以外の画面を文字コード0で埋めておく。<br>
ブロック３は40文字しかないので、最初から文字コード1～40の文字で埋めておく。<br>
各PCGのブロックの文字コード0は空白を表現する文字としてリザーブ。


ドットをプロットする際は、次の手順で実行。

1. 当該位置に文字が存在すれば、その文字に対して、ドットを追加
2. 文字が存在しない場合は、当該ブロックに存在する文字コードの最大値を検索し、最大値に+1した文字を置き、ドットを追加。
3. 文字コードの最大値が255に達している場合は、これ以上プロットができないものとして、プロットリクエストを無視。


# 利用時の準備
C000Hよりマシン語で書かれているので、BASICプログラムでは
```
CLEAR 300, &HBFFF
```
を記述してください。詳細な記述方法は、[デモプログラム](#デモプログラム)を参照ください。

新PCGをグラフィック画面的に使用するサブルーチン群は、```pcg_demo5.cmt```にマシン語ファイルとして格納されています。

# 基本的な使い方
DEF USR を使って、ユーザ関数として呼び出します。引数は、整数型です。

```
DEF USR1=&hC000 : USR1(0)   : 'PCGの初期化
DEF USR2=&hC003 : USR2(X1%)  : 'X1座標のセット
DEF USR3=&hC006 : USR3(Y1%)  : 'Y1座標のセット
DEF USR4=&hC009 : USR4(X2%) : 'X2座標のセット
DEF USR5=&hC00C : USR5(Y2%) : 'Y2座標のセット
DEF USR6=&HC00F : USR6(0)   : 'PSET(X1, Y1) 実施
DEF USR7=&HC012 : USR7(0)   : '(X1,Y1)-(X2,Y2)にラインを描画
DEF USR8=&HC015 : USR8(0)   : '(X1,Y1)を中心に半径X2 の円を描く
DEF USR9=&HC018 : USR9(0)   : 'バッファフラッシュ
```

## 初期化
PCGや画面の初期化は、&HC000 のルーチンで行います。
```
DEF USR1=&hC000 : USR1(0)   : 'PCGの初期化
LOCATE 0,0,0                : 'カーソル非表示
```
40桁×25行、白黒モードで初期化されます。
また、カーソルは ```locate 0,0,0``` で非表示にしておくとよいです。

### pset
グラフィックで(X%, Y%)座標に１点プロットを打つ手順は以下の通り

1. ```DEF USR2=&HC003``` の ```A%=USR2(X%)``` でX座標を指定、
2. ```DEF USR3=&HC006``` の ```A%=USR3(Y%)``` でY座標を指定
3. ```DEF USR6=&HC00F``` の ```A%=USR6(0)```でPSET実行
4. 1～3を必要なだけ繰り返す
5. ```DEF USR9=&HC018``` の ```A%=USR9(0)```でバッファ上のPCGの設定を反映させる

プロットは、８点プロットされるごとに、PCGに対してVSYNC待ちを行い、反映されます。
毎回PCGに対して反映させたい場合は、明示的に```A%=USR9(0)```を実行してください。

### line
グラフィックで(X1%, Y1%)-(X2%,Y2%)に直線を描画する

1. ```DEF USR2=&HC003``` の ```A%=USR2(X1%)``` でX1座標を指定、
2. ```DEF USR3=&HC006``` の ```A%=USR3(Y1%)``` でY1座標を指定
3. ```DEF USR4=&HC009``` の ```A%=USR4(X2%)``` でX2座標を指定、
4. ```DEF USR5=&HC00C``` の ```A%=USR5(Y2%)``` でY2座標を指定
5. ```DEF USR7=&HC012``` の ```A%=USR7(0)``` でline実行
6. 1～5を必要なだけ繰り返す
7. ```DEF USR9=&HC018``` の ```A%=USR9(0)```でバッファ上のPCGの設定を反映させる

line では、内部的に pset 機能が呼び出され、８点プロットされるごとに、
PCGに対してVSYNC待ちを行い、反映されます。毎回PCGに対して反映させたい場合は、
明示的に```A%=USR9(0)```を実行してください。

### circle
グラフィックで、(X%, Y%)座標を中心、半径R%の円を描く

1. ```DEF USR2=&HC003``` の ```A%=USR2(X%)``` でX座標を指定、
2. ```DEF USR3=&HC006``` の ```A%=USR3(Y%)``` でY座標を指定
3. ```DEF USR4=&HC009``` の ```A%=USR4(R%)``` で半径を指定、
4. ```DEF USR8=&HC015``` の ```A%=USR8(0)``` でcircle実行
5. 1～4を必要なだけ繰り返す
6. ```DEF USR9=&HC018``` の ```A%=USR9(0)```でバッファ上のPCGの設定を反映させる

line では、内部的に pset 機能が呼び出され、８点プロットされるごとに、
PCGに対してVSYNC待ちを行い、反映されます。基本的に、circleでは円を８分割して描画して
いるので、最後に```A%=USR9(0)```を実行するだけで十分だと考えられます。

# デモプログラム
本ライブラリとN-BASICで書かれたデモプログラムのCMTファイルを３個用意しました。

## 3D demo プログラム
00_PCG_3D.CMT で、マシン語とBASICからなります。実行には、20分強かかります。

```
mon
*L
*[Ctrl+B]
cload"DEMO"
run
```
![実行結果](./3d_demo.jpg)
```
10000 CLEAR 300,&HBFFF
10010 TIME$="00:00:00":LOCATE 0,0,0
10020 DEF USR1=&HC000:A=USR1(0)
10030 DEF USR2=&HC003:DEF USR3=&HC006:DEF USR4=&HC00F:DEF USR5=&HC018
10040 DIM DT%(255),DB%(255):DR=3.14/90
10050 FOR I=0 TO 255:DT%(I)=192:DB%(I)=-1:NEXT
10060 FOR Y=-45 TO 45:FOR X=-90 TO 90 STEP 2
10070 R=DR*SQR(X*X+Y*Y*4):Z=50*COS(R)-15*COS(3*R)
10080 SX%=INT(128+X-Y):SY%=INT(80-Y-Z):PS=0
10090 IF SX%<0 OR 255<SX% THEN 10130
10100 IF DT%(SX%)>SY% THEN DT%(SX%)=SY%:PS=1
10110 IF DB%(SX%)<SY% THEN DB%(SX%)=SY%:PS=1
10120 IF PS THEN A%=USR2(INT(SX%+32)):A%=USR3(SY%):A%=USR4(0)
10130 A%=USR5(0):NEXT X,Y
10140 COLOR 8:LOCATE 16,24:PRINT TIME$;
10150 A$=INKEY$:IF A$="" GOTO 10150
10160 LOCATE 0,0,1:OUT 8,0:PRINT CHR$(12)
```
## circle デモプログラム
00_PCG_3D.CMT で、マシン語とBASICからなります。ほぼすべての処理がマシン語で実行されるので、実行時間は約10秒
```
mon
*L
*[Ctrl+B]
cload"DEMO"
run
```
![実行結果](./circle_demo.jpg)

```
1000 CLEAR 300,&HBFFF
1010 TIME$="00:00:00":LOCATE 0,0,0
1020 DEF USR1=&HC000:A=USR1(0)
1030 DEF USR2=&HC003:DEF USR3=&HC006:DEF USR4=&HC009:DEF USR5=&HC015
1040 DEF USR6=&HC015
1050 FOR I%=0 TO 15
1060 X0%=RND(1)*240+70:Y0%=RND(1)*160+20:R%=RND(1)*60+5
1070 A%=USR2(X0%):A%=USR3(Y0%):A%=USR4(R%):A%=USR5(0)
1080 NEXT
1090 COLOR 8:LOCATE 16,24:PRINT TIME$;
1100 A$=INKEY$:IF A$="" GOTO 1100
1110 LOCATE 0,0,1:OUT 8,0:PRINT CHR$(12)
```

## line デモプログラム
00_PCG_LINE.CMT で、マシン語とBASICからなります。SINカーブの計算がBASICで行われているため、実行時間は約40秒
```
mon
*L
*[Ctrl+B]
cload"DEMO"
run
```
![実行結果](./line_demo.jpg)

```
1000 CLEAR 300,&HBFFF
1010 TIME$="00:00:00":LOCATE 0,0,0
1020 DEF USR1=&HC000:A=USR1(0)
1030 DEF USR2=&HC003:DEF USR3=&HC006:DEF USR4=&HC009:DEF USR5=&HC00C
1040 DEF USR6=&HC012:DEF USR7=&HC018
1050 '
1060 X1%=0:Y1%=50
1070 FOR T%=1 TO 319 STEP 2
1080 X0%=X1%:Y0%=Y1%:X1%=T%:Y1%=20*SIN(T%/32*3.1415)+50
1090 A%=USR2(X0%):A%=USR3(Y0%):A%=USR4(X1%):A%=USR5(Y1%):A%=USR6(0)
1100 A%=USR7(0):NEXT
1110 '
1120 X1%=0:Y1%=100
1130 FOR T%=1 TO 319 STEP 2
1140 X0%=X1%:Y0%=Y1%:X1%=T%:Y1%=20*SIN(T%/16*3.1415)+100
1150 A%=USR2(X0%):A%=USR3(Y0%):A%=USR4(X1%):A%=USR5(Y1%):A%=USR6(0)
1160 A%=USR7(0):NEXT
1170 '
1180 X1%=0:Y1%=150
1190 FOR T%=1 TO 319
1200 X0%=X1%:Y0%=Y1%:X1%=T%:Y1%=20*SIN(T%/8*3.1415)+150
1210 A%=USR2(X0%):A%=USR3(Y0%):A%=USR4(X1%):A%=USR5(Y1%):A%=USR6(0)
1220 A%=USR7(0):NEXT
1230 '
1240 COLOR 8:LOCATE 16,24:PRINT TIME$;
1250 A$=INKEY$:IF A$="" GOTO 1250
1260 LOCATE 0,0,1:OUT 8,0:WIDTH 80,25:PRINT CHR$(12)
```
