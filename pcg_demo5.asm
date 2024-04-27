;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;
; @kazenifukarete
;
; New PCG by @chiqlappe PC8001 routines
;
; 40colx25rows, Black and White mode,
; Emulate 320dot x 200 dot graphics
;
; 2024.04.27
;
;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

  ORG 0C000H


;
; DEF USR1=&hC000 : USR1(0)   : 'PCGの初期化
; DEF USR2=&hC003 : USR2(X%)  : 'X1座標のセット
; DEF USR3=&hC006 : USR3(Y%)  : 'Y1座標のセット
; DEF USR4=&hC009 : USR4(X2%) : 'X2座標のセット
; DEF USR5=&hC00C : USR5(Y2%) : 'Y2座標のセット&PSET
; DEF USR6=&HC00F : USR6()    ; 'PSET実施
; DEF USR7=&HC012 : USR7(0)   : '(X1,Y1)-(X2,Y2)にラインを描画
; DEF USR8=&HC015 : USR8(0)   ; '(X1,Y1)を中心に半径X2 の円を描く
; DEF USR9=&HC018 : USR9(0)   ; 'バッファフラッシュ

  SYS_CLS EQU 45AH
  SYS_WIDTH EQU 843H
  SYS_CONSOLE EQU 884H
  BUF_MAX EQU 8  ; 128

; VSYNC後 331 x 36 =11916

ENTRY:
  JP   INIT_PCG
  JP   SET_X
  JP   SET_Y
  JP   SET_X2
  JP   SET_Y2
  JP   CHECK_BUFFER_AND_PSET
  JP   LINE
  JP   MiechenerCircle
  JP   BUFFER_FLASH


INIT_PCG:                ; 画面モードを設定。40桁×25行、白黒
  CALL SYS_CLS
  LD   HL, WIDTH
  CALL SYS_WIDTH
  LD   HL, CONSOLE
  CALL SYS_CONSOLE

CLS:                     ; 画面をクリア
  CALL CLEAR_PCG
  CALL SET_ATTRIB
  CALL CLEAR_SCREEN
  LD   HL,BUFFER
  LD   (BUF_PTR),HL
  XOR  A
  LD   (NUM_BUF),A
  RET

;
; バッファに溜まった描画情報を吐き出す
;
BUFFER_FLASH:
  LD   A, (NUM_BUF)      ; バッファの空きを確認
  OR   A
  RET  Z
  LD   D, A
  LD   HL,BUFFER
  LD   (BUF_PTR),HL
  XOR  A
  LD   (NUM_BUF),A
  CALL VSYNC                   ; VSYNC街ち
BUFFER_FLASH_LOOP:
  LD   A,(HL)                  ;  7 clk
  INC  HL                      ;  6 clk
  OUT  (8),A                   ; 11 clk
  LD   B,(HL)                  ;  7 clk
  INC  HL                      ;  6 clk
  LD   C,(HL)                  ;  7 clk
  INC  HL                      ;  6 clk
  LD   A,(HL)                  ;  7 clk
  INC  HL                      ;  6 clk
  OUT  (C),A                   ; 12 clk
  DEC  D                       ;  4 clk
  JR   NZ, BUFFER_FLASH_LOOP   ; 12 clk : Total 91 clk
  RET


;
; X座標を設定
;

SET_X:
  LD   A,(HL)
  LD   (X_POS),A
  INC  HL
  LD   A,(HL)
  LD   (X_POS+1),A
  RET

;
; Y座標を設定し、プロットバッファに収める
;

SET_Y:
  LD   A,(HL)
  LD   (Y_POS),A
  INC  HL
  LD   A,(HL)
  LD   (Y_POS+1),A
  RET

SET_X2:
  LD   A,(HL)
  LD   (X2_POS),A
  INC  HL
  LD   A,(HL)
  LD   (X2_POS+1),A
  RET

SET_Y2:
  LD   A,(HL)
  LD   (Y2_POS),A
  INC  HL
  LD   A,(HL)
  LD   (Y2_POS+1),A
  RET

CHECK_BUFFER_AND_PSET:
  LD   A,(NUM_BUF)        ; プロットバッファが満杯かチェック
  CP   BUF_MAX
  JR   C,PSET_XY          ; プロットバッファに空きあり
  CALL BUFFER_FLASH       ; プロットバッファをフラッシュ

PSET_XY:
  LD   HL,(X_POS)         ; 0 <= X_POS < 320 チェック
  BIT  7,H
  RET  NZ
  LD   DE,320
  OR   A
  SBC  HL,DE              ; >= 320 ならばRET
  RET  NC
  LD   HL,(Y_POS)         ; 0 <= Y_POS < 200 チェック
  BIT  7,H                ; 負の値ならば、RET
  RET  NZ
  LD   DE,200
  OR   A
  SBC  HL,DE              ; >= 200 ならばRET
  RET  NC


;  CALL CHK_BLK           ; (Y_POS) からブロック番号計算

  LD   A,(Y_POS)
  RLCA                    ; A=A/64
  RLCA
  AND  3
  LD   (BLK),A


  CALL CALC_ADR           ; 指定座標に文字があるか確認
  JR   NZ,REGISTER_CH_NO  ; 文字があった場合は、当該文字にドットを追加
  CALL IS_NEXTCHR         ; ブロック内の未使用文字コードを抽出
  RET  Z                  ; 未使用文字なし
  LD   A,(CH_NO)
  LD   HL,(VRAM_ADR)      ; 未使用文字をVRAMに登録
  LD   (HL),A

REGISTER_CH_NO:           ; CH_NO にドットを追加する
  LD   HL,PCG_RAM
  LD   A,(BLK)
  ADD  A,A                  ; (BLK) * 2K を HLに加える
  ADD  A,A
  ADD  A,A
  ADD  A,H
  LD   H,A
  LD   A,(CH_NO)          ; (CH_NO)*8 を HLに加える
  LD   D,0
  ADD  A,A
  RL   D
  ADD  A,A
  RL   D
  ADD  A,A
  RL   D
  LD   E,A
  ADD  HL,DE
  LD   A,(Y_POS)          ; (Y_POS) AND 7をHLに加える
  AND  7
  LD   C,A                ; この値は、OUT (C),A まで変えない
  ADD  A,L
  LD   L,A
  JR   NC,NO_CARRY_1
  INC  H
NO_CARRY_1:
;  LD   (PCG_RAM_ADDR),HL   ; この処理不要？
  LD   A,(X_POS)           ; (X_POS)からビットパタンを計算
  AND  7
  LD   B,A
  LD   A,7FH
  JR   Z,SHIFTED
SHIFT_LOOP:
  RRCA
  DJNZ SHIFT_LOOP
SHIFTED:
  LD   DE,(BUF_PTR)
  AND  (HL)                 ; PCG RAM にビットパタンをANDする
  LD   (HL),A
  LD   A,(BLK)
  OR   12
  LD   (DE),A               ; ブロック番号を指定
  INC  DE
  LD   A,(CH_NO)
  LD   (DE),A               ; キャラクタコード指定
  INC  DE
  LD   A,C
  LD   (DE),A
  INC  DE
  LD   A,(HL)               ; PCG書き込みパタンを用意
  LD   (DE),A
  INC  DE
  LD   (BUF_PTR),DE
  LD   A,(NUM_BUF)
  INC  A
  LD   (NUM_BUF),A
  RET


IS_NEXTCHR:
  LD   HL,0F300H
  LD   A,(BLK)
  OR   A
  JR   Z, CHK_NEXTCHR
  LD   HL,0F300H+120*8
  DEC  A
  JR   Z, CHK_NEXTCHR
  LD   HL,0F300H+120*16
CHK_NEXTCHR:
  CALL SEARCH_NEXT
  RET

;
; ブロック内の最大の文字コードを探し、+1 した値を
; (CH_NO)に入れる。これが０なら、もう割り当てられる
; コードは存在しない
;

SEARCH_NEXT:
  LD   D,0
  LD   C,8
SEARCH_Y_LOOP:
  LD   B,40
SEARCH_X_LOOP:
  LD   A,(HL)
  INC  HL
  INC  HL
  CP   D
  JR   C,LESS_THAN
  LD   D,A
LESS_THAN:
  DJNZ SEARCH_X_LOOP
  LD   A,40
  ADD  A,L
  LD   L,A
  JR   NC, NO_CARRY_SEARCH
  INC  H
NO_CARRY_SEARCH:
  DEC  C
  JR   NZ, SEARCH_Y_LOOP
  LD   A,D
  INC  A
  LD   (CH_NO),A
  RET

;
; Ｙ座標からブロック番号に変換し、(BLK)に格納
;
;CHK_BLK:
;  LD   A,(Y_POS)
;  SRL  A          ; A=A/64
;  RLCA
;  RLCA
;  AND  3
;  LD   (BLK),A
;  RET

;
; (X_POS),(Y_POS)から、VRAMアドレスを計算
;
CALC_ADR:
  LD   HL,0F300H
  LD   A,(Y_POS)
  RRCA              ; A=A/8
  RRCA
  RRCA
  AND  31
  JR   Z,NO_Y80
  LD   B,A
  LD   DE,120
Y80_LOOP:
  ADD  HL,DE
  DJNZ  Y80_LOOP
NO_Y80:
  LD   A,(X_POS+1)
  LD   B, A
  LD   A,(X_POS)
  SRL  B
  RRA
  SRL  B
  RRA
  AND  0FEH
  ADD  A,L
  LD   L,A
  JR   NC, CALC_ADR_NO_CARRY
  INC  H
CALC_ADR_NO_CARRY:
  LD   (VRAM_ADR),HL
  LD   A,(HL)
  LD   (CH_NO),A
  OR   A
  RET

;
; 垂直帰線期間待ち
;

VSYNC:
  PUSH AF
VSYNC_0:
  IN   A,(40H)
  AND  20H
  JR   NZ,VSYNC_0
VSYNC_1:
  IN   A,(40H)
  AND  20H
  JR   Z,VSYNC_1
  POP  AF
  RET

;
; V-RAMをクリア
;

CLEAR_SCREEN:
  LD   HL,0F300H
  LD   C,24
CLEAR_SCREEN_Y_LOOP:
  LD   B,40
  XOR  A
CLEAR_SCREEN_X_LOOP:
  LD   (HL),A
  INC  HL
  INC  HL
  DJNZ CLEAR_SCREEN_X_LOOP
  LD   A,40
  ADD  A,L
  LD   L,A
  JR   NC, CEAR_SCREEN_X_FIN
  INC  H
CEAR_SCREEN_X_FIN:
  DEC  C
  JR   NZ, CLEAR_SCREEN_Y_LOOP

  LD   B,40
  LD   A,1
CLEAR_SCREEN_X_LOOP2:
  LD   (HL),A
  INC  A
  INC  HL
  INC  HL
  DJNZ CLEAR_SCREEN_X_LOOP2
  RET

;
; V-RAMアトリビュートを反転に設定
;

SET_ATTRIB:
  LD  DE,0F350H
  LD  B,25

SET_ATTRIB_LOOP:
  PUSH BC
  LD   BC, 4
  LD   HL, ATTRIB_DATA
  LDIR
  LD   HL,120-4
  ADD  HL,DE
  LD   D,H
  LD   E,L
  POP  BC
  DJNZ SET_ATTRIB_LOOP
  RET

;
; PCGのRAMバッファとPCGの登録を全クリアする
;

CLEAR_PCG:
  LD   HL,PCG_RAM
  LD   BC,2000H
CLEAR_PCG_0:
  LD   A,255
  LD   (HL),A
  INC  HL
  DEC  BC
  LD   A,B
  OR   C
  JR   NZ,CLEAR_PCG_0

  LD   A,12
  OUT  (8),A
  CALL CLEAR_PCG_256

  LD   A,13
  OUT  (8),A
  CALL CLEAR_PCG_256

  LD   A,14
  OUT  (8),A
  CALL CLEAR_PCG_256

  LD   A,15
  OUT  (8),A
  CALL CLEAR_PCG_256
  RET


CLEAR_PCG_256:
  LD   B,0
  LD   A,255
CLEAR_PCG_256_LOOP:
  LD   D,63
  CALL VSYNC
CONTINUOUS_CLEAR:
  CALL CLEAR_1CH_PCG         ; 165 clk
  DEC  B                     ;   4 clk
  DEC  D                     ;   4 clk
  JR   NZ, CONTINUOUS_CLEAR  ;  12 clk  : Total 185 clk
  CALL CLEAR_1CH_PCG
  DJNZ CLEAR_PCG_256_LOOP
  RET


CLEAR_1CH_PCG:
  LD   C,0         ; 7 clk
  OUT  (C),A
  INC  C
  OUT  (C),A
  INC  C
  OUT  (C),A
  INC  C
  OUT  (C),A
  INC  C
  OUT  (C),A
  INC  C
  OUT  (C),A
  INC  C
  OUT  (C),A
  INC  C            ;  4 clk
  OUT  (C),A        ; 12 clk
  RET               ; 10 clk : Total 145 clk

WIDTH DB "40,25",0
CONSOLE DB "0,25,0,0",0
ATTRIB_DATA DB 0,4,80,0

;
;
; CIRCLE
;
; https://dencha.ojaru.jp/programs_07/pg_graphic_09a1.html
;
MiechenerCircle:
  LD  DE,(Radius)
  LD  (cy), DE
  LD  HL,3
  OR  A
  SBC HL,DE
  OR  A
  SBC HL,DE
  LD  (M_d),HL

  LD   HL,(X_POS)
  LD   (center_x),HL

  LD   HL,(Y_POS)
  LD   (center_y),HL

  LD   DE,(Radius)
  ADD  HL,DE
  LD   (Y_POS),HL
  CALL CHECK_BUFFER_AND_PSET

  LD   HL,(center_y)
  LD   DE,(Radius)
  OR   A
  SBC  HL,DE
  LD   (Y_POS),HL
  CALL CHECK_BUFFER_AND_PSET


  LD   HL,(center_y)
  LD   (Y_POS),HL
  LD   HL,(center_x)
  LD   DE,(Radius)
  ADD  HL,DE
  LD   (X_POS),HL
  CALL CHECK_BUFFER_AND_PSET

  LD   HL,(center_y)
  LD   (Y_POS),HL
  LD   HL,(center_x)
  LD   DE,(Radius)
  OR   A
  SBC  HL,DE
  LD   (X_POS),HL
  CALL CHECK_BUFFER_AND_PSET

  LD   HL,0
  LD   (cx),HL
for_cx_loop:
  LD   HL,(cx)
  LD   DE,(cy)
  OR   A
  SBC  HL,DE
  JR   Z, for_cx_body
  JR   C, for_cx_body
  JP   BUFFER_FLASH
;  RET
for_cx_body:
  LD   HL,(cx)      ; DE = 4*cx
  ADD  HL,HL
  ADD  HL,HL
  EX   DE,HL
  LD   HL,(cy)      ; BC = 4*cy
  ADD  HL,HL
  ADD  HL,HL
  LD   B,H
  LD   C,L

  LD   HL,(M_d)
  BIT  7,H
  JR   Z, for_cx_plus
  ADD  HL,DE
  LD   DE,6
  ADD  HL,DE
  LD   (M_d),HL
  JR   for_cx_body2

for_cx_plus:
  ADD  HL,DE
  OR   A
  SBC  HL,BC
  LD   DE,10
  ADD  HL,DE
  LD   (M_d),HL
  LD   DE,(cy)
  DEC  DE
  LD   (cy),DE

for_cx_body2:
  LD   HL,(center_x)
  LD   DE,(cy)
  ADD  HL,DE
  LD   (X_POS),HL
  LD   HL,(center_y)
  LD   DE,(cx)
  ADD  HL,DE
  LD   (Y_POS),HL
  CALL CHECK_BUFFER_AND_PSET

  LD   HL,(center_x)
  LD   DE,(cx)
  ADD  HL,DE
  LD   (X_POS),HL
  LD   HL,(center_y)
  LD   DE,(cy)
  ADD  HL,DE
  LD   (Y_POS),HL
  CALL CHECK_BUFFER_AND_PSET

  LD   HL,(center_x)
  LD   DE,(cx)
  OR   A
  SBC  HL,DE
  LD   (X_POS),HL
  LD   HL,(center_y)
  LD   DE,(cy)
  ADD  HL,DE
  LD   (Y_POS),HL
  CALL CHECK_BUFFER_AND_PSET

  LD   HL,(center_x)
  LD   DE,(cy)
  OR   A
  SBC  HL,DE
  LD   (X_POS),HL
  LD   HL,(center_y)
  LD   DE,(cx)
  ADD  HL,DE
  LD   (Y_POS),HL
  CALL CHECK_BUFFER_AND_PSET

  LD   HL,(center_x)
  LD   DE,(cy)
  OR   A
  SBC  HL,DE
  LD   (X_POS),HL
  LD   HL,(center_y)
  LD   DE,(cx)
  OR   A
  SBC  HL,DE
  LD   (Y_POS),HL
  CALL CHECK_BUFFER_AND_PSET

  LD   HL,(center_x)
  LD   DE,(cx)
  OR   A
  SBC  HL,DE
  LD   (X_POS),HL
  LD   HL,(center_y)
  LD   DE,(cy)
  OR   A
  SBC  HL,DE
  LD   (Y_POS),HL
  CALL CHECK_BUFFER_AND_PSET

  LD   HL,(center_x)
  LD   DE,(cx)
  ADD  HL,DE
  LD   (X_POS),HL
  LD   HL,(center_y)
  LD   DE,(cy)
  OR   A
  SBC  HL,DE
  LD   (Y_POS),HL
  CALL CHECK_BUFFER_AND_PSET

  LD   HL,(center_x)
  LD   DE,(cy)
  ADD  HL,DE
  LD   (X_POS),HL
  LD   HL,(center_y)
  LD   DE,(cx)
  OR   A
  SBC  HL,DE
  LD   (Y_POS),HL
  CALL CHECK_BUFFER_AND_PSET

  LD   HL,(cx)
  INC  HL
  LD   (cx),HL
  JP   for_cx_loop

;
; (X1,Y1)と(X2,Y2)を交換する
;

SWAP_X1Y1_X2Y2:
  LD   HL,(X1_POS)
  LD   DE,(X2_POS)
  LD   (X1_POS),DE
  LD   (X2_POS),HL

  LD   HL,(Y1_POS)
  LD   DE,(Y2_POS)
  LD   (Y1_POS),DE
  LD   (Y2_POS),HL
  RET


NEG_HL:
  PUSH DE
  LD   DE,0
  EX   DE,HL
  OR   A
  SBC  HL,DE
  POP  DE
  RET

LINE:
CALC_DXDY:
  LD   HL,(X1_POS)
  LD   DE,(X2_POS)
  OR   A
  SBC  HL,DE
  JR   NC,CALC_DXDY_X
  CALL NEG_HL
CALC_DXDY_X:
  LD   (dx),HL
  LD   HL,(Y1_POS)
  LD   DE,(Y2_POS)
  OR   A
  SBC  HL,DE
  JR   NC,CALC_DXDY_Y
  CALL NEG_HL
CALC_DXDY_Y:
  LD   (dy),HL

  LD   A,(dx)
  LD   B,A
  LD   A,(dx+1)
  OR   B
  JR   Z, LINE_vertical

  LD   A,(dy)
  LD   B,A
  LD   A,(dy+1)
  OR   B
  JR   Z, LINE_horizontal

  LD   HL,(dx)
  LD   DE,(dy)
  OR   A
  SBC  HL,DE
  JP   C, LINE_y_base
  JP   LINE_x_base

;
; 縦線を描く
;

LINE_vertical:
  LD   A,(dy)
  LD   B,A
  LD   A,(dy+1)
  OR   B
  JP   Z, CHECK_BUFFER_AND_PSET

  LD   HL,(Y1_POS)
  LD   DE,(Y2_POS)
  OR   A
  SBC  HL,DE
  JR   C, LINE_vertical_start
  CALL SWAP_X1Y1_X2Y2
LINE_vertical_start:
  CALL CHECK_BUFFER_AND_PSET
  LD   DE,(Y1_POS)
  LD   HL,(Y2_POS)
  OR   A
  SBC  HL,DE
  RET  Z
  INC  DE
  LD   (Y1_POS),DE
  JR   LINE_vertical_start

;
; 横線を描く
;
LINE_horizontal:
  LD   HL,(X1_POS)
  LD   DE,(X2_POS)
  OR   A
  SBC  HL,DE
  JR   C, LINE_horizontal_start
  CALL SWAP_X1Y1_X2Y2
LINE_horizontal_start:
  CALL CHECK_BUFFER_AND_PSET
  LD   DE,(X1_POS)
  LD   HL,(X2_POS)
  OR   A
  SBC  HL,DE
  RET  Z
  INC  DE
  LD   (X1_POS),DE
  JR   LINE_horizontal_start

;
; x軸を基準に描く
;
LINE_x_base:
  LD   HL,0
  LD   (line_drawn),HL
  LD   HL,(X1_POS)
  LD   DE,(X2_POS)
  OR   A
  SBC  HL,DE
  JR   C, LINE_x_base_start
  CALL SWAP_X1Y1_X2Y2
LINE_x_base_start:
  LD   HL,(Y1_POS)
  LD   DE,(Y2_POS)
  OR   A
  SBC  HL,DE
  JR   C, LINE_x_base_down
LINE_x_base_up:
  CALL CHECK_BUFFER_AND_PSET
  LD   DE,(X1_POS)
  LD   HL,(X2_POS)
  OR   A
  SBC  HL,DE
  RET  Z
  INC  DE
  LD   (X1_POS),DE
  LD   HL,(line_drawn)
  LD   DE,(dy)
  ADD  HL,DE
  LD   (line_drawn),HL
  LD   DE,(dx)
  OR   A
  SBC  HL,DE
  JR   C, LINE_x_base_up
  LD   (line_drawn),HL
  LD   HL,(Y1_POS)
  DEC  HL
  LD   (Y1_POS),HL
  JR   LINE_x_base_up

LINE_x_base_down:
  CALL CHECK_BUFFER_AND_PSET
  LD   DE,(X1_POS)
  LD   HL,(X2_POS)
  OR   A
  SBC  HL,DE
  RET  Z
  INC  DE
  LD   (X1_POS),DE
  LD   HL,(line_drawn)
  LD   DE,(dy)
  ADD  HL,DE
  LD   (line_drawn),HL
  LD   DE,(dx)
  OR   A
  SBC  HL,DE
  JR   C, LINE_x_base_down
  LD   (line_drawn),HL
  LD   HL,(Y1_POS)
  INC  HL
  LD   (Y1_POS),HL
  JR   LINE_x_base_down



LINE_y_base:
  LD   HL,0
  LD   (line_drawn),HL
  LD   HL,(Y1_POS)
  LD   DE,(Y2_POS)
  OR   A
  SBC  HL,DE
  JR   C, LINE_y_base_start
  CALL SWAP_X1Y1_X2Y2
LINE_y_base_start:
  LD   HL,(X1_POS)
  LD   DE,(X2_POS)
  OR   A
  SBC  HL,DE
  JR   C, LINE_y_base_right
LINE_y_base_left:
  CALL CHECK_BUFFER_AND_PSET
  LD   DE,(Y1_POS)
  LD   HL,(Y2_POS)
  OR   A
  SBC  HL,DE
  RET  Z
  INC  DE
  LD   (Y1_POS),DE
  LD   HL,(line_drawn)
  LD   DE,(dx)
  ADD  HL,DE
  LD   (line_drawn),HL
  LD   DE,(dy)
  OR   A
  SBC  HL,DE
  JR   C, LINE_y_base_left
  LD   (line_drawn),HL
  LD   HL,(X1_POS)
  DEC  HL
  LD   (X1_POS),HL
  JR   LINE_y_base_left

LINE_y_base_right:
  CALL CHECK_BUFFER_AND_PSET
  LD   DE,(Y1_POS)
  LD   HL,(Y2_POS)
  OR   A
  SBC  HL,DE
  RET  Z
  INC  DE
  LD   (Y1_POS),DE
  LD   HL,(line_drawn)
  LD   DE,(dx)
  ADD  HL,DE
  LD   (line_drawn),HL
  LD   DE,(dy)
  OR   A
  SBC  HL,DE
  JR   C, LINE_y_base_right
  LD   (line_drawn),HL
  LD   HL,(X1_POS)
  INC  HL
  LD   (X1_POS),HL
  JR   LINE_y_base_right

line_drawn: DS 2
dx: DS 2
dy: DS 2
center_x: DS 2
center_y: DS 2
cx: DS 2
cy: DS 2
 DS 2


M_d: DS 2


X1_POS:
X_POS: DS 2
Y1_POS:
Y_POS: DS 2

Radius:
X2_POS: DS 2
Y2_POS: DS 2

BLK:   DS 1
CH_NO: DS 1
NUM_BUF: DS 1
BUF_PTR: DS 2

BUFFER: DS 4*BUF_MAX
VRAM_ADR: DS 2
;PCG_RAM_ADDR: DS 2
PCG_RAM DS 2000H

  END
