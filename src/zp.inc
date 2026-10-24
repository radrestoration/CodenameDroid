; Zero page used by the C64 engine: $d0-$df, $ee-$f7 are unused by the game ($e4-$e7 hold its
; former $00-$03).
zp_p1       = $d0           ; 2: pointer to the 8 bytes of a ring cell
zp_ci       = $d2           ; 2: ring cell index 0-1023
zp_c        = $d4           ; character
zp_h        = $d5           ; hash bucket
zp_oc       = $d6           ; the character the cell had
zp_t        = $d7           ; temporary
zp_u        = $d8           ; 2: temporary pointer
zp_vb       = $da           ; 2: ring cell index shown at the matrix's top left (S + 32*cam)
zp_dc       = $dc           ; 2: number of entries on the dirty list
zp_rs       = $de           ; 2: mark_rect: start of the current row
zp_rx       = $ee           ; mark_rect: columns
zp_ry       = $ef           ; mark_rect: rows
zp_fc       = $f0           ; number of free characters
zp_d        = $f1           ; 2: matrix offset work
zp_idx      = $f3           ; 2: remap: row start index
zp_v        = $f5           ; 2: spare
zp_nv       = $fa           ; 2: the view base the next remap will use
zp_remap    = $fc           ; non-zero: the view moved, a full remap follows (so show_cell need not)
zp_ev       = $fd           ; the eviction hand: where the search for an unreferenced character resumes
