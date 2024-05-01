;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;
; @kazenifukarete
;
; New PCG by @chiqlappe PC8001 routines
;
; 40colx25rows, Black and White mode,
; Emulate 320dot x 200 dot graphics
;
; 2024.05.01
;
;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

  ORG 0C000H

;
; DEF USR1=&hC000 : USR1(0)     : 'PCG�̏�����
; DEF USR2=&hC003 : USR2(X%)    : 'X1���W�̃Z�b�g
; DEF USR3=&hC006 : USR3(Y%)    : 'Y1���W�̃Z�b�g
; DEF USR4=&hC009 : USR4(X2%)   : 'X2���W�̃Z�b�g
; DEF USR5=&hC00C : USR5(Y2%)   : 'Y2���W�̃Z�b�g&PSET
; DEF USR6=&HC00F : USR6(0|1|2) : 'PSET/PRESET/PXOR/BOXFILL���{
;                               : '   ����:0:PSET
;                               : '        1:PRESET
;                               : '        2:XOR
;                               : '
;                               : '        4:BOX-PSET
;                               : '        5:BOX-PRESET
;                               : '        6:BOX-XOR
;                               : '        8:BOXFILL-PSET
;                               : '        9:BOXFILL-PRESET
;                               : '       10:BOXFILL-XOR
; DEF USR7=&HC012 : USR7(0|1|2) : '(X1,Y1)-(X2,Y2)�Ƀ��C��,BOX,BOXFILL ��`��
;                               : '   ����:0:PSET
;                               : '        1:PRESET
;                               : '        2:XOR
;                               : '
;                               : '        4:BOX-PSET
;                               : '        5:BOX-PRESET
;                               : '        6:BOX-XOR
;                               : '        8:BOXFILL-PSET
;                               : '        9:BOXFILL-PRESET
;                               : '       10:BOXFILL-XOR
; DEF USR8=&HC015 : USR8(0|1|2) ; '(X1,Y1)�𒆐S�ɔ��aX2 �̉~��`��
;                               : '   ����:0:PSET
;                               : '        1:PRESET
;                               : '        2:XOR
; DEF USR9=&HC018 : USR9(0)     ; '�o�b�t�@�t���b�V��

  SYS_CLS EQU 45AH
  SYS_WIDTH EQU 843H
  SYS_CONSOLE EQU 884H
  SYS_CURSOR_OFF EQU 0BD2H
  BUF_MAX EQU 16  ; 128
  VRMDAT EQU 0675H ; VRAM LINE TOP ADDRESS DATA

; VSYNC�� 331 x 36 =11916

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


INIT_PCG:                ; ��ʃ��[�h��ݒ�B40���~25�s�A����
  CALL SYS_CLS
  LD   HL, WIDTH
  CALL SYS_WIDTH
  LD   HL, CONSOLE       ; �������[�h
  CALL SYS_CONSOLE
  CALL SYS_CURSOR_OFF    ; �J�[�\���N���A

CLS:                     ; ��ʂ��N���A(PCG�O���t�B�b�N����)
  CALL CLEAR_PCG
  CALL SET_ATTRIB
  CALL CLEAR_SCREEN
  LD   HL,BUFFER
  LD   (BUF_PTR),HL
  XOR  A
  LD   (NUM_BUF),A
  RET

;
; �o�b�t�@�ɗ��܂����`�����f���o��
;
BUFFER_CHECK:
  LD   A, (NUM_BUF)      ; �o�b�t�@�̋󂫂��m�F
  CP   BUF_MAX
  RET  C
BUFFER_FLASH:
  LD   A, (NUM_BUF)      ; �o�b�t�@�̋󂫂��m�F
  OR   A
  RET  Z
  LD   D, A
  LD   HL,BUFFER
  LD   (BUF_PTR),HL
  XOR  A
  LD   (NUM_BUF),A
  CALL VSYNC                   ; VSYNC�҂�
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
; X���W��ݒ�
;

SET_X:
  LD   A,(HL)
  LD   (X_POS),A
  INC  HL
  LD   A,(HL)
  LD   (X_POS+1),A
  RET

;
; Y���W��ݒ�
;

SET_Y:
  LD   A,(HL)
  LD   (Y_POS),A
  INC  HL
  LD   A,(HL)
  LD   (Y_POS+1),A
  RET

;
; X2���W��ݒ�
;

SET_X2:
  LD   A,(HL)
  LD   (X2_POS),A
  INC  HL
  LD   A,(HL)
  LD   (X2_POS+1),A
  RET

;
; Y2���W��ݒ�
;
SET_Y2:
  LD   A,(HL)
  LD   (Y2_POS),A
  INC  HL
  LD   A,(HL)
  LD   (Y2_POS+1),A
  RET

;
; BOXFILL �̍��W����ʓ��ɖ߂�
;
TRIM_BOX:
  LD   HL,(X1_POS)    ; X1 < 0 �� X1=0
  BIT  7,H
  JR   Z,TRIM_BOX_1
  LD   HL,0
  LD   (X1_POS),HL
TRIM_BOX_1:
  LD   DE,320         ; X1 >=320 �� X1=319
  OR   A
  SBC  HL,DE
  JR   C,TRIM_BOX_2
  LD   HL,319
  LD   (X1_POS),HL
TRIM_BOX_2:
  LD   HL,(X2_POS)    ; X2 < 0 �� X2 = 0
  BIT  7,H
  JR   Z,TRIM_BOX_3
  LD   HL,0
  LD   (X2_POS),HL
TRIM_BOX_3:
  LD   DE,320         ; X2 >=320 �� X1=319
  OR   A
  SBC  HL,DE
  JR   C,TRIM_BOX_4
  LD   HL,319
  LD   (X2_POS),HL
TRIM_BOX_4:
  LD   HL,(Y1_POS)    ; Y1 < 0 �� Y1=0
  BIT  7,H
  JR   Z,TRIM_BOX_5
  LD   HL,0
  LD   (Y1_POS),HL
TRIM_BOX_5:
  LD   DE,200         ; Y1 >=200 �� Y1=199
  OR   A
  SBC  HL,DE
  JR   C,TRIM_BOX_6
  LD   HL,199
  LD   (Y1_POS),HL
TRIM_BOX_6:
  LD   HL,(Y2_POS)    ; Y2 < 0 �� Y2=0
  BIT  7,H
  JR   Z,TRIM_BOX_7
  LD   HL,0
  LD   (Y2_POS),HL
TRIM_BOX_7:
  LD   DE,200         ; Y2 >=200 �� Y2=199
  OR   A
  SBC  HL,DE
  RET  C
  LD   HL,199
  LD   (Y2_POS),HL
  RET

;
; BOX �n�̍��W�̑召�֌W�̐����������
;
BOX_XY_SWAP:
  LD   HL,(X1_POS)
  LD   DE,(X2_POS)
  OR   A
  SBC  HL,DE
  JR   C, BOX_XY_SWAP1

  LD   HL,(X1_POS)
  LD   (X1_POS),DE
  LD   (X2_POS),HL

BOX_XY_SWAP1:
  LD   HL,(X1_POS)
  LD   (X_ORG),HL

  LD   HL,(Y1_POS)
  LD   DE,(Y2_POS)
  OR   A
  SBC  HL,DE
  RET  C

  LD   HL,(Y1_POS)
  LD   (Y1_POS),DE
  LD   (Y2_POS),HL

  RET


;
; BOXFILL
;
BOXFILL:
  CALL TRIM_BOX
  CALL BOX_XY_SWAP

BOXFILL_Y_LOOP:
  LD   HL,(X_ORG)
  LD   (X1_POS),HL
BOXFILL_X_LOOP:
  CALL BOXFILL_8DOT
  JR   NC,BOXFILL_X_LOOP_NEXT

  CALL CHECK_BUFFER_AND_PSET
  LD   HL,(X1_POS)
  INC  HL
  LD   (X1_POS),HL
BOXFILL_X_LOOP_NEXT:
  LD   DE,(X2_POS)
  EX   DE,HL
  OR   A
  SBC  HL,DE
  JR   NC, BOXFILL_X_LOOP

  LD   HL,(Y1_POS)
  INC  HL
  LD   (Y1_POS),HL
  LD   DE,(Y2_POS)
  EX   DE,HL
  OR   A
  SBC  HL,DE
  JR   NC, BOXFILL_Y_LOOP
  JP   BUFFER_FLASH



BOX:
  CALL BOX_XY_SWAP

BOX_Y_LOOP:
BOX_X0_LOOP:
  CALL BOXFILL_8DOT
  JR   NC,BOX_X0_LOOP_NEXT
  CALL CHECK_BUFFER_AND_PSET

  LD   HL,(X1_POS)
  INC  HL
  LD   (X1_POS),HL

BOX_X0_LOOP_NEXT:
  LD   DE,(X2_POS)
  EX   DE,HL
  OR   A
  SBC  HL,DE
  JR   NC, BOX_X0_LOOP

  LD   HL,(Y1_POS)
  INC  HL
  LD   (Y1_POS),HL
  LD   DE,(Y2_POS)
  EX   DE,HL
  OR   A
  SBC  HL,DE
  JP   C, BUFFER_FLASH     ; Y2 > Y1  �Ȃ�I��
  JR   Z, BOX_FINAL_LOOP   ; Y2 == Y1 �Ȃ�ŏI���C���`���

BOX_Y1_LOOP:
  LD   HL,(X_ORG)
  LD   (X1_POS),HL
  CALL CHECK_BUFFER_AND_PSET
  LD   HL,(X2_POS)
  LD   (X1_POS),HL
  CALL CHECK_BUFFER_AND_PSET

  LD   HL,(Y1_POS)
  INC  HL
  LD   (Y1_POS),HL
  LD   DE,(Y2_POS)
  OR   A
  SBC  HL,DE
  JP   C, BOX_Y1_LOOP

BOX_FINAL_LOOP:
  LD   HL,(X_ORG)
  LD   (X1_POS),HL
BOX_X2_LOOP:
  CALL BOXFILL_8DOT
  JR   NC,BOX_X2_LOOP_NEXT

  CALL CHECK_BUFFER_AND_PSET
  LD   HL,(X1_POS)
  INC  HL
  LD   (X1_POS),HL
BOX_X2_LOOP_NEXT:
  LD   DE,(X2_POS)
  EX   DE,HL
  OR   A
  SBC  HL,DE
  JR   NC, BOX_X2_LOOP
  JP   BUFFER_FLASH


;
; BOX FILL ������
;


BOXFILL_8DOT_NONE:
  SCF
  RET

BOXFILL_8DOT_DONE:
  LD   HL,(X1_POS)
  LD   A,8
  ADD  A,L
  LD   L,A
  JR   NC, BOXFILL_8DOT_DONE_FIN
  INC  H
BOXFILL_8DOT_DONE_FIN:
  LD   (X1_POS),HL
  OR   A
  RET

BOXFILL_8DOT:
  LD  HL,(X_POS)
  LD  A,L                   ; 8�̔{���ȊO�̏ꏊ�ł� return
  AND 7
  JR  NZ,BOXFILL_8DOT_NONE
  LD  DE,312
  SBC HL,DE
  JR  NC,BOXFILL_8DOT_NONE  ; 312�ȏ�ł�ret

  LD   HL,(X2_POS)
  LD   DE,(X_POS)
  OR   A
  SBC  HL,DE
  OR   A
  LD   DE,7
  SBC  HL,DE
  JR   C,BOXFILL_8DOT_NONE  ; �`��K�v����8�s�N�Z���ȉ��Ȃ�ret

  LD   A,(Y_POS)            ; CALC (BLK)
  RLCA                      ; A=A/64
  RLCA
  AND  3
  LD   (BLK),A

  LD   A,(PRESET_FLAG)
  DEC  A
  JP   Z, BOXFILL_8DOT_PRESET_XY
  DEC  A
  JP   Z, BOXFILL_8DOT_XOR    ; XOR �ɕ���

  CALL CALC_ADR               ; �w����W�ɕ��������邩�m�F
  JR   NZ,BOXFILL_8DOT_CH_NO  ; �������������ꍇ�́A���Y�����Ƀh�b�g��ǉ�

  LD   A,(BLK)                ; �u���b�N3�ł́A���g�p�����̒��o�͍s��Ȃ�
  CP   3
  JR   Z,BOXFILL_8DOT_NONE

  CALL SEARCH_NEXT           ; �u���b�N���̖��g�p�����R�[�h�𒊏o
  JR   Z,BOXFILL_8DOT_NONE   ; ���g�p�����Ȃ�
;  LD   A,(CH_NO)
  LD   HL,(VRAM_ADR)         ; ���g�p������VRAM�ɓo�^
  LD   (HL),A

BOXFILL_8DOT_CH_NO:          ; CH_NO �Ƀh�b�g��ǉ�����
  CALL BUFFER_CHECK
  CALL CALC_PCG_RAM_ADR

;  LD   (PCG_RAM_ADDR),HL    ; ���̏����s�v�H

  XOR  A                     ; PCG RAM �Ƀr�b�g�p�^����AND����
  LD   (HL),A

  CALL STORE_PCG_DATA_TO_BUFFER
  JP   BOXFILL_8DOT_DONE


BOXFILL_8DOT_PRESET_XY:
  CALL CALC_ADR              ; �w����W�ɕ��������邩�m�F
  JP   Z,BOXFILL_8DOT_DONE   ; �����������ꍇ�͉������Ȃ�

BOXFILL_8DOT_PRESET_CH_NO:   ; CH_NO �̃h�b�g���N���A����
  CALL BUFFER_CHECK
  CALL CALC_PCG_RAM_ADR
;  LD   (PCG_RAM_ADDR),HL   ; ���̏����s�v�H


  LD   A,255                ; PCG RAM �ɋ󔒃r�b�g�p�^��������
  LD   (HL),A

  CALL STORE_PCG_DATA_TO_BUFFER


CHECK_EMPTY_CHAR_BOXFILL_8DOT:

  LD   A,(BLK)   ; �u���b�N3 �Ȃ�APCG�̋󕶎��`�F�b�N�͍s��Ȃ�
  CP   3
  JP   Z,BOXFILL_8DOT_DONE
  CALL CHECK_EMPTY_CHAR
  JP   BOXFILL_8DOT_DONE



BOXFILL_8DOT_XOR:
  CALL CALC_ADR               ; �w����W�ɕ��������邩�m�F
  JR   NZ,BOXFILL_8DOT_XOR_CH_NO   ; �������������ꍇ�́A���Y�����Ƀh�b�g��ǉ�

  LD   A,(BLK)                  ; �u���b�N3�ł́A���g�p�����̒��o�͍s��Ȃ�
  CP   3
  JP   Z,BOXFILL_8DOT_NONE

  CALL SEARCH_NEXT         ; �u���b�N���̖��g�p�����R�[�h�𒊏o
  JP   Z,BOXFILL_8DOT_NONE ; ���g�p�����Ȃ�
;  LD   A,(CH_NO)
  LD   HL,(VRAM_ADR)       ; ���g�p������VRAM�ɓo�^
  LD   (HL),A

BOXFILL_8DOT_XOR_CH_NO:    ; CH_NO �Ƀh�b�g��ǉ�����
  CALL BUFFER_CHECK
  CALL CALC_PCG_RAM_ADR

;  LD   (PCG_RAM_ADDR),HL   ; ���̏����s�v�H

  LD   A,255                ; PCG RAM �Ƀr�b�g�p�^����AND����
  XOR  (HL)
  LD   (HL),A

  CALL STORE_PCG_DATA_TO_BUFFER

  LD   A,(HL)
  INC  A
  JP   NZ,BOXFILL_8DOT_DONE   ; �������ݒl��255�ȊO�̎��̓`�F�b�N�s�v
  JP   CHECK_EMPTY_CHAR_BOXFILL_8DOT


CALC_PCG_RAM_ADR:
  LD   HL,PCG_RAM
  LD   A,(BLK)
  ADD  A,A                   ; (BLK) * 2K �� HL�ɉ�����
  ADD  A,A
  ADD  A,A
  ADD  A,H
  LD   H,A
  LD   A,(CH_NO)             ; (CH_NO)*8 �� HL�ɉ�����
  LD   D,0
  ADD  A,A
  RL   D
  ADD  A,A
  RL   D
  ADD  A,A
  RL   D
  LD   E,A
  ADD  HL,DE

  LD   (PCG_CH_TOP),HL       ; PCG�̕����p�^���g�b�v�̃A�h���X�ۑ�

  LD   A,(Y_POS)             ; (Y_POS) AND 7��HL�ɉ�����
  AND  7
  LD   C,A                   ; ���̒l�́AOUT (C),A �܂ŕς��Ȃ�
  ADD  A,L
  LD   L,A
  RET  NC
  INC  H
  RET


STORE_PCG_DATA_TO_BUFFER:    ; HL �� PCG_RAM �̓��Y�p�^�����w��
  LD   DE,(BUF_PTR)
  LD   A,(BLK)
  OR   12
  LD   (DE),A                ; �u���b�N�ԍ����w��
  INC  DE
  LD   A,(CH_NO)
  LD   (DE),A                ; �L�����N�^�R�[�h�w��
  INC  DE
  LD   A,C
  LD   (DE),A
  INC  DE
  LD   A,(HL)                ; PCG�������݃p�^����p��
  LD   (DE),A
  INC  DE
  LD   (BUF_PTR),DE
  LD   A,(NUM_BUF)
  INC  A
  LD   (NUM_BUF),A
  RET


USR_PSET:
  LD  A,(HL)
  AND 3
  LD  (PRESET_FLAG),A
  LD  A,(HL)
  AND 12
  CP  4
  JP  Z, BOX
  CP  8
  JP  Z, BOXFILL

CHECK_BUFFER_AND_PSET:
  LD   A,(NUM_BUF)        ; �v���b�g�o�b�t�@�����t���`�F�b�N
  CP   BUF_MAX
  JR   C,PSET_XY          ; �v���b�g�o�b�t�@�ɋ󂫂���
  CALL BUFFER_FLASH       ; �v���b�g�o�b�t�@���t���b�V��

PSET_XY:
  LD   HL,(X_POS)         ; 0 <= X_POS < 320 �`�F�b�N
  BIT  7,H
  RET  NZ
  LD   DE,320
  OR   A
  SBC  HL,DE              ; >= 320 �Ȃ��RET
  RET  NC
  LD   HL,(Y_POS)         ; 0 <= Y_POS < 200 �`�F�b�N
  BIT  7,H                ; ���̒l�Ȃ�΁ARET
  RET  NZ
  LD   DE,200
  OR   A
  SBC  HL,DE              ; >= 200 �Ȃ��RET
  RET  NC


;  CALL CHK_BLK           ; (Y_POS) ����u���b�N�ԍ��v�Z

  LD   A,(Y_POS)
  RLCA                    ; A=A/64
  RLCA
  AND  3
  LD   (BLK),A

  LD   A,(PRESET_FLAG)
  DEC  A
  JP   Z, PRESET_XY
  DEC  A
  JP   Z,PXOR_XY          ; PRESET �ɕ���

  CALL CALC_ADR           ; �w����W�ɕ��������邩�m�F
  JR   NZ,PSET_CH_NO      ; �������������ꍇ�́A���Y�����Ƀh�b�g��ǉ�

  LD   A,(BLK)            ; �u���b�N3�ł́A���g�p�����̒��o�͍s��Ȃ�
  CP   3
  RET  Z

  CALL SEARCH_NEXT        ; �u���b�N���̖��g�p�����R�[�h�𒊏o
  RET  Z                  ; ���g�p�����Ȃ�
;  LD   A,(CH_NO)
  LD   HL,(VRAM_ADR)      ; ���g�p������VRAM�ɓo�^
  LD   (HL),A

PSET_CH_NO:               ; CH_NO �Ƀh�b�g��ǉ�����
  CALL CALC_PCG_RAM_ADR    ; PCG RAM �A�h���X�v�Z

;  LD   (PCG_RAM_ADDR),HL  ; ���̏����s�v�H
  LD   A,(X_POS)           ; (X_POS)����r�b�g�p�^�����v�Z
  AND  7
  LD   B,A
  LD   A,7FH
  JR   Z,SHIFTED
SHIFT_LOOP:
  RRCA
  DJNZ SHIFT_LOOP
SHIFTED:

  AND  (HL)                 ; PCG RAM �Ƀr�b�g�p�^����AND����
  LD   (HL),A

  CALL STORE_PCG_DATA_TO_BUFFER
  RET

PXOR_XY:
  CALL CALC_ADR           ; �w����W�ɕ��������邩�m�F
  JR   NZ,XOR_CH_NO       ; �������������ꍇ�́A���Y�����Ƀh�b�g��XOR

  LD   A,(BLK)            ; �u���b�N3�ł́A���g�p�����̒��o�͍s��Ȃ�
  CP   3
  RET  Z

  CALL SEARCH_NEXT        ; �u���b�N���̖��g�p�����R�[�h�𒊏o
  RET  Z                  ; ���g�p�����Ȃ�
;  LD   A,(CH_NO)
  LD   HL,(VRAM_ADR)      ; ���g�p������VRAM�ɓo�^
  LD   (HL),A

XOR_CH_NO:                ; CH_NO �Ƀh�b�g��XOR����
  CALL CALC_PCG_RAM_ADR    ; PCG RAM �A�h���X�v�Z
;  LD   (PCG_RAM_ADDR),HL   ; ���̏����s�v�H
  LD   A,(X_POS)           ; (X_POS)����r�b�g�p�^�����v�Z
  AND  7
  LD   B,A
  LD   A,80H
  JR   Z,SHIFTED_XOR
SHIFT_LOOP_XOR:
  RRCA
  DJNZ SHIFT_LOOP_XOR
SHIFTED_XOR:

  XOR  (HL)                 ; PCG RAM �Ƀr�b�g�p�^����AND����
  LD   (HL),A

  CALL STORE_PCG_DATA_TO_BUFFER

  LD   A,(HL)
  INC  A
  RET  NZ

  JP   CHECK_EMPTY_CHAR

;
; �u���b�N���̖��g�p�����R�[�h��T��(CH_NO)�ɓ����B
; ���ꂪ 0 �Ȃ�A�������蓖�Ă���R�[�h�͑��݂��Ȃ�
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
  XOR  A             ; �󂢂Ă���L�����N�^��������Ȃ�����
  LD   (CH_NO),A
  RET

EMPTY_CHAR_FOUND:
  LD   A,D
  LD   (HL),A        ; ��[���̒l�������Ă���̂ŁA�t���O����ɗp����
  LD   (CH_NO),A
  OR   A
  RET

;
; �x���W����u���b�N�ԍ��ɕϊ����A(BLK)�Ɋi�[
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
; (X_POS),(Y_POS)����AVRAM�A�h���X���v�Z
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

  LD   A,(NUM_BUF)        ; �v���b�g�o�b�t�@�����t���`�F�b�N
  CP   BUF_MAX
  JR   C,PRESET_XY          ; �v���b�g�o�b�t�@�ɋ󂫂���
  CALL BUFFER_FLASH       ; �v���b�g�o�b�t�@���t���b�V��

PRESET_XY:
PRESET_XY_SUB:
  CALL CALC_ADR           ; �w����W�ɕ��������邩�m�F
  RET  Z                  ; �w����W�ɕ������Ȃ���ΏI��

PRESET_CH_NO:             ; CH_NO �̃h�b�g���팸����
  CALL CALC_PCG_RAM_ADR   ; PCG RAM �A�h���X�v�Z

  LD   A,(X_POS)          ; (X_POS)����r�b�g�p�^�����v�Z
  AND  7
  LD   B,A
  LD   A,80H
  JR   Z,SHIFTED_PRESET
SHIFT_LOOP_PRESET:
  RRCA
  DJNZ SHIFT_LOOP_PRESET
SHIFTED_PRESET:

  OR   (HL)               ; PCG RAM �Ƀr�b�g�p�^����OR����
  LD   (HL),A

  CALL STORE_PCG_DATA_TO_BUFFER

  LD   A,(HL)
  INC  A                  ; PCG�p�^����255�łȂ���΁A�I��
  RET  NZ

; ��������APCG�̃p�^����All 255�łȂ����̃`�F�b�N
CHECK_EMPTY_CHAR:
  LD   A,(BLK)   ; �u���b�N3 �Ȃ�A���̏����͍s��Ȃ�
  CP   3
  RET  Z

  LD   HL, (PCG_CH_TOP)

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
  RET  NZ        ; All 255 �ł͂Ȃ�

  XOR  A
  LD   HL,(VRAM_ADR)
  LD   (HL),A    ; VRAM��̃L�������N���A

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
; �����A�����ԑ҂�
; A���W�X�^�͔j�󂳂��
;

VSYNC:
;  PUSH AF
VSYNC_0:
  IN   A,(40H)
  AND  20H
  JR   NZ,VSYNC_0
VSYNC_1:
  IN   A,(40H)
  AND  20H
  JR   Z,VSYNC_1
;  POP  AF
  RET

;
; V-RAM���N���A
;

CLEAR_SCREEN:
  LD   HL,0F300H
  LD   C,24
;
; 1�s�ڂ���24�s�ڂ̏���
;
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
;
; 25�s�ڂ݂̂̏���
;
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
; V-RAM�A�g���r���[�g�𔽓]�ɐݒ�
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
; PCG��RAM�o�b�t�@��PCG�̓o�^��S�N���A����
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
CLEAR_PCG_256_LOOP:
  LD   D,63
  CALL VSYNC
  LD   A,255
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
  CALL CLEAR_CHAR_USED_SUB   ; CLEAR BLOCK 0
  CALL CLEAR_CHAR_USED_SUB   ; CLEAR BLOCK 1
  CALL CLEAR_CHAR_USED_SUB   ; CLEAR BLOCK 1
  CALL CLEAR_CHAR_USED_SUB41 ; CLEAR BLOCK 3
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
  LD  A,(HL)
  AND 3
  LD  (PRESET_FLAG),A

  LD   DE,(Radius)
  LD   A,D                       ; ���a��0�̎��́A�P�_�����v���b�g����
  OR   E
  JP   Z,CHECK_BUFFER_AND_PSET

  LD   (cy), DE
  LD   HL,3
  OR   A
  SBC  HL,DE
  OR   A
  SBC  HL,DE
  LD   (M_d),HL

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

  ;    ���������Q��v���b�g���Ȃ��悤�Ƀ`�F�b�N
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
; (X1,Y1)��(X2,Y2)����������
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
  AND 3
  LD  (PRESET_FLAG),A
  LD  A,(HL)
  AND 12
  CP  4
  JP  Z, BOX
  CP  8
  JP  Z, BOXFILL

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
; �c����`��
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
; ������`��
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
; x������ɕ`��
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
M_d: DS 2

PRESET_FLAG: DS 1
X1_POS:
X_POS: DS 2
Y1_POS:
Y_POS: DS 2

Radius:
X2_POS: DS 2
Y2_POS: DS 2

X_ORG:  DS 2

BLK:   DS 1
CH_NO: DS 1
NUM_BUF: DS 1
BUF_PTR: DS 2
PCG_CH_TOP: DS 2    ; PCG�̂P�L�����N�^�̃o�b�t�@�g�b�v


BUFFER: DS 4*BUF_MAX
VRAM_ADR: DS 2
;PCG_RAM_ADDR: DS 2

CHAR_USED: DS 3*256
PCG_RAM DS 256*8*3+8*41

  END
