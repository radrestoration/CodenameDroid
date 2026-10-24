; Macros for the helper routines that the geometry patches (tools/wide_patches.py) call in place of the BBC game's
; inline address arithmetic. The game's screen addresses are 16-bit pointers into the ring (RING .. $7fff); a cell is 8
; bytes, a row of cells STRIDE bytes, and an address that leaves the ring wraps round it.

; RING_ADD slo, shi, dlo, dhi, K: (dhi:dlo) := (shi:slo) + K, wrapped into the ring. K is a constant (it may be
; negative). Clobbers A and the flags only.
.macro RING_ADD slo, shi, dlo, dhi, K
    clc
    lda slo
    adc #<(K)
    sta dlo
    lda shi
    adc #>(K)
.if (K) >= 0
    cmp #$80
    bcc :+
    sbc #RING_SZ_HI             ; (carry is set)
.else
    cmp #RING_HI
    bcs :+
    adc #RING_SZ_HI             ; (carry is clear)
.endif
  :
    sta dhi
.endmacro
