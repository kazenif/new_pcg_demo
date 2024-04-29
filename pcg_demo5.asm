;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;
; @kazenifukarete
;
; New PCG by @chiqlappe PC8001 routines
;
; 40colx25rows, Black and White mode,
; Emulate 320dot x 200 dot graphics
;
; 2024.04.30
;
;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

  ORG 0C000H


;
; DEF USR1=&hC000 : USR1(0)     : 'PCGの初期化
; DEF USR2=&hC003 : USR2(X%)    : 'X1座標のセット
; DEF USR3=&hC006 : USR3(Y%)    : 'Y1座標のセット
; DEF USR4=&hC009 : USR4(X2%)   : 'X2座標のセット
; DEF USR5=&hC00C : USR5(Y2%)   : 'Y2座標のセット&PSET
; DEF USR6=&HC00F : USR6(0|1|2) : 'PSET/PRESET/PXOR実施
;                               : '   引数:0:PSET
;                               : '        1:PRESET
;                               : '        2:XOR
; DEF USR7=&HC012 : USR7(0|1|2) : '(X1,Y1)-(X2,Y2)にラインを描画
; DEF USR8=&HC015 : USR8(0|1|2) ; '(X1,Y1)を中心に半径X2 の円を描く
; DEF USR9=&HC018 : USR9(0)     ; 'バッファフラッシュ

  SYS_CLS EQU 45AH
  SYS_WIDTH EQU 843H
  SYS_CONSOLE EQU 884H
  BUF_MAX EQU 8  ; 128
  VRMDAT EQU 0675H ; VRAM LINE TOP ADDRESS DATA

; VSYNC後 331 x 36 =11916

ENTRY:
  JP   INIT_PCG
  JP   SET_X
  JP   SET_Y
  JP   SET_X2
  JP   SET_Y2
  JP   USR_PSET
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

USR_PSET:
  LD A,(HL)
  LD (PRESET_FLAG),A

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

  LD   A,(PRESET_FLAG)
  DEC  A
  JP   Z, PRESET_XY
  DEC  A
  JP   Z,PXOR_XY          ; PRESET に分岐

  CALL CALC_ADR           ; 指定座標に文字があるか確認
  JR   NZ,PSET_CH_NO      ; 文字があった場合は、当該文字にドットを追加

  LD   A,(BLK)            ; ブロック3では、未使用文字の抽出は行わない
  CP   3
  RET  Z

  CALL SEARCH_NEXT        ; ブロック内の未使用文字コードを抽出
  RET  Z                  ; 未使用文字なし
;  LD   A,(CH_NO)
  LD   HL,(VRAM_ADR)      ; 未使用文字をVRAMに登録
  LD   (HL),A

PSET_CH_NO:           ; CH_NO にドットを追加する
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

PXOR_XY:
  CALL CALC_ADR           ; 指定座標に文字があるか確認
  JR   NZ,XOR_CH_NO       ; 文字があった場合は、当該文字にドットをXOR

  LD   A,(BLK)            ; ブロック3では、未使用文字の抽出は行わない
  CP   3
  RET  Z

  CALL SEARCH_NEXT        ; ブロック内の未使用文字コードを抽出
  RET  Z                  ; 未使用文字なし
;  LD   A,(CH_NO)
  LD   HL,(VRAM_ADR)      ; 未使用文字をVRAMに登録
  LD   (HL),A

XOR_CH_NO:                ; CH_NO にドットをXORする
  LD   HL,PCG_RAM
  LD   A,(BLK)
  ADD  A,A                ; (BLK) * 2K を HLに加える
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

  PUSH HL                 ; PCGの文字のバッファのアドレスを保存
                          ; CHECK_EMPTY_CHAR で POP する

  LD   A,(Y_POS)          ; (Y_POS) AND 7をHLに加える
  AND  7
  LD   C,A                ; この値は、OUT (C),A まで変えない
  ADD  A,L
  LD   L,A
  JR   NC,NO_CARRY_3
  INC  H
NO_CARRY_3:
;  LD   (PCG_RAM_ADDR),HL   ; この処理不要？
  LD   A,(X_POS)           ; (X_POS)からビットパタンを計算
  AND  7
  LD   B,A
  LD   A,80H
  JR   Z,SHIFTED_XOR
SHIFT_LOOP_XOR:
  RRCA
  DJNZ SHIFT_LOOP_XOR
SHIFTED_XOR:
  LD   DE,(BUF_PTR)
  XOR  (HL)                 ; PCG RAM にビットパタンをANDする
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
  JP   CHECK_EMPTY_CHAR


;
; ブロック内の未使用文字コードを探し(CH_NO)に入れる。
; これが０なら、もう割り当てられるコードは存在しない
;

SEARCH_NEXT:
  LD   HL,CHAR_USED+1
  LD   A,(BLK)
  ADD  A,H
  LD   H,A

  LD   D,1
  LD   B,255
SEARCH_LOOP:
  LD   A,(HL)
  OR   A
  JR   Z,EMPTY_CHAR_FOUND
  INC  HL
  INC  D
  DJNZ SEARCH_LOOP
  XOR  A             ; 空いているキャラクタが見つからなかった
  LD   (CH_NO),A
  RET

EMPTY_CHAR_FOUND:
  LD   A,D
  LD   (HL),A        ; 非ゼロの値が入っているので、フラグ代わりに用いる
  LD   (CH_NO),A
  OR   A
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
  LD   HL,VRMDAT
  LD   A,(Y_POS)
  RRCA              ; A=A/4
  RRCA
  AND  31*2
  ADD  A,L
  LD   L,A
  LD   E,(HL)
  INC  HL
  LD   D,(HL)
  EX   DE,HL
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

CHECK_BUFFER_AND_PRESET:
  LD A,(HL)
  LD (PRESET_FLAG),A

  LD   A,(NUM_BUF)        ; プロットバッファが満杯かチェック
  CP   BUF_MAX
  JR   C,PRESET_XY          ; プロットバッファに空きあり
  CALL BUFFER_FLASH       ; プロットバッファをフラッシュ

PRESET_XY:
PRESET_XY_SUB:
  CALL CALC_ADR           ; 指定座標に文字があるか確認
  RET  Z                  ; 指定座標に文字がなければ終了

PRESET_CH_NO:             ; CH_NO のドットを削減する
  LD   HL,PCG_RAM
  LD   A,(BLK)
  ADD  A,A                ; (BLK) * 2K を HLに加える
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

  PUSH HL                 ; ここで、PCGのパタンの0行目のアドレスを記録

  LD   A,(Y_POS)          ; (Y_POS) AND 7をHLに加える
  AND  7
  LD   C,A                ; この値は、OUT (C),A まで変えない
  ADD  A,L
  LD   L,A
  JR   NC,NO_CARRY_2
  INC  H
NO_CARRY_2:
  LD   A,(X_POS)           ; (X_POS)からビットパタンを計算
  AND  7
  LD   B,A
  LD   A,80H
  JR   Z,SHIFTED_PRESET
SHIFT_LOOP_PRESET:
  RRCA
  DJNZ SHIFT_LOOP_PRESET
SHIFTED_PRESET:
  LD   DE,(BUF_PTR)
  OR   (HL)                 ; PCG RAM にビットパタンをORする
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

; ここから、PCGのパタンがAll 255でないかのチェック
CHECK_EMPTY_CHAR:
  POP  HL

  LD   A,(BLK)   ; ブロック3 なら、この処理は行わない
  CP   3
  RET  Z

  LD   A,(HL)    ; 0
  INC  HL
  AND  (HL)      ; 1
  INC  HL
  AND  (HL)      ; 2
  INC  HL
  AND  (HL)      ; 3
  INC  HL
  AND  (HL)      ; 4
  INC  HL
  AND  (HL)      ; 5
  INC  HL
  AND  (HL)      ; 6
  INC  HL
  AND  (HL)      ; 7
  INC  A
  RET  NZ        ; All 255 ではない
  XOR  A
  LD   HL,(VRAM_ADR)
  LD   (HL),A    ; VRAM上のキャラをクリア

  LD   HL,CHAR_USED
  LD   A,(BLK)
  ADD  A,H
  LD   H,A
  LD   A,(CH_NO)
  ADD  A,L
  LD   L,A
  JR   NC, NO_CARRY_CLEAR_USED
  INC  H
NO_CARRY_CLEAR_USED:
  XOR  A
  LD   (HL),A
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
  CALL CLEAR_CHAR_USED
  LD   HL,PCG_RAM
  LD   BC,256*8*3+8*41
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
; CALL CLEAR_PCG_256        ; Omit calling
;
;  RET


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


CLEAR_CHAR_USED:
  LD   HL,CHAR_USED
  CALL CLEAR_CHAR_USED_SUB  ; CLEAR BLOCK 0
  CALL CLEAR_CHAR_USED_SUB  ; CLEAR BLOCK 1
  CALL CLEAR_CHAR_USED_SUB  ; CLEAR BLOCK 1
  CALL CLEAR_CHAR_USED_SUB41  ; CLEAR BLOCK 3
  RET

CLEAR_CHAR_USED_SUB:
  LD   A,1
  LD   (HL),A
  INC  HL
  XOR  A
  LD   B,255
CLEAR_CHAR_USED_SUB_1:
  LD   (HL),A
  INC  HL
  DJNZ CLEAR_CHAR_USED_SUB_1
  RET

CLEAR_CHAR_USED_SUB41:
  LD   A,1
  LD   B,41
CLEAR_CHAR_USED_SUB41_1:
  LD   (HL),A
  INC  HL
  DJNZ CLEAR_CHAR_USED_SUB41_1

  XOR  A
  LD   B,215
CLEAR_CHAR_USED_SUB41_2:
  LD   (HL),A
  INC  HL
  DJNZ CLEAR_CHAR_USED_SUB41_2

  RET

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
  LD A,(HL)
  LD (PRESET_FLAG),A

  LD  DE,(Radius)
  LD  A,D                       ; 半径が0の時は、１点だけプロットする
  OR  E
  JP  Z,CHECK_BUFFER_AND_PSET

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

  ;    同じ所を２回プロットしないようにチェック
  ;
  LD   HL,(cx)
  LD   DE,(cy)
  OR   A
  SBC  HL, DE
  JR   Z,  circle_half
  JP   NC, BUFFER_FLASH

  LD   HL,(center_x)
;  LD   DE,(cy)
  ADD  HL,DE
  LD   (X_POS),HL
  LD   HL,(center_y)
  LD   DE,(cx)
  ADD  HL,DE
  LD   (Y_POS),HL
  CALL CHECK_BUFFER_AND_PSET    ; 0-45

  LD   HL,(center_x)
  LD   DE,(cx)
  OR   A
  SBC  HL,DE
  LD   (X_POS),HL
  LD   HL,(center_y)
  LD   DE,(cy)
  ADD  HL,DE
  LD   (Y_POS),HL
  CALL CHECK_BUFFER_AND_PSET    ; 90-135

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
  CALL CHECK_BUFFER_AND_PSET    ; 180-225

  LD   HL,(center_x)
  LD   DE,(cx)
  ADD  HL,DE
  LD   (X_POS),HL
  LD   HL,(center_y)
  LD   DE,(cy)
  OR   A
  SBC  HL,DE
  LD   (Y_POS),HL
  CALL CHECK_BUFFER_AND_PSET    ; 270-315


circle_half:

  LD   HL,(center_x)
  LD   DE,(cx)
  ADD  HL,DE
  LD   (X_POS),HL
  LD   HL,(center_y)
  LD   DE,(cy)
  ADD  HL,DE
  LD   (Y_POS),HL
  CALL CHECK_BUFFER_AND_PSET    ; 45-90

  LD   HL,(center_x)
  LD   DE,(cy)
  OR   A
  SBC  HL,DE
  LD   (X_POS),HL
  LD   HL,(center_y)
  LD   DE,(cx)
  ADD  HL,DE
  LD   (Y_POS),HL
  CALL CHECK_BUFFER_AND_PSET    ; 135-180

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
  CALL CHECK_BUFFER_AND_PSET    ; 225-270

  LD   HL,(center_x)
  LD   DE,(cy)
  ADD  HL,DE
  LD   (X_POS),HL
  LD   HL,(center_y)
  LD   DE,(cx)
  OR   A
  SBC  HL,DE
  LD   (Y_POS),HL
  CALL CHECK_BUFFER_AND_PSET    ; 315-360

circle_skip:

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
  LD A,(HL)
  LD (PRESET_FLAG),A
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

PRESET_FLAG: DS 1
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

CHAR_USED: DS 3*256
BUFFER: DS 4*BUF_MAX
VRAM_ADR: DS 2
;PCG_RAM_ADDR: DS 2
PCG_RAM DS 256*8*3+8*41

  END
