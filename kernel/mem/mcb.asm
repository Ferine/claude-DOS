; ===========================================================================
; claudeDOS Memory Control Block (MCB) Manager
; ===========================================================================

; MCB chain starts after the kernel. Each MCB is a 16-byte paragraph header
; followed by the memory block (size in paragraphs).

; mcb_chain_start is now sysvars_mcb_ptr in data.asm
mcb_chain_start equ sysvars_mcb_ptr  ; Alias for compatibility

; ---------------------------------------------------------------------------
; init_memory - Initialize the MCB chain
; Creates one free MCB spanning all conventional memory after the kernel
; ---------------------------------------------------------------------------
init_memory:
    pusha
    push    es
    
    ; Calculate end of kernel (next paragraph after kernel code+data)
    mov     ax, cs
    ; Estimate kernel size: use a label at the end
    mov     bx, kernel_end
    add     bx, 15
    shr     bx, 4               ; Convert to paragraphs
    add     ax, bx              ; AX = first free segment
    
    mov     [mcb_chain_start], ax
    
    ; Get total conventional memory from BIOS
    int     0x12                ; AX = memory in KB
    ; Convert KB to paragraphs: KB * 64
    mov     cx, 64
    mul     cx                  ; AX = total paragraphs
    ; DX:AX = total paragraphs (but fits in 16 bits for conv. memory)
    
    ; MCB size = total_paragraphs - mcb_start - 1 (for the MCB header itself)
    sub     ax, [mcb_chain_start]
    dec     ax                  ; Subtract 1 for MCB header paragraph
    
    ; Create the initial MCB
    mov     es, [mcb_chain_start]
    mov     byte [es:0], 'Z'        ; Last block
    mov     word [es:1], 0           ; Free (no owner)
    mov     [es:3], ax               ; Size in paragraphs
    ; Clear name
    xor     ax, ax
    mov     word [es:5], ax
    mov     word [es:7], ax
    mov     word [es:9], ax
    mov     word [es:11], ax
    mov     word [es:13], ax
    
    pop     es
    popa
    ret

; ---------------------------------------------------------------------------
; mcb_alloc - Allocate memory block
; Input: BX = requested size in paragraphs
; Output: AX = segment of allocated block (after MCB header)
;         CF set on error, BX = largest available block
; ---------------------------------------------------------------------------
mcb_alloc:
    push    cx
    push    dx
    push    si
    push    es

    mov     ax, [mcb_chain_start]
    xor     dx, dx              ; Track largest free block

.scan_loop:
    mov     es, ax

    ; Verify valid MCB signature
    cmp     byte [es:0], 'M'
    je      .sig_ok
    cmp     byte [es:0], 'Z'
    je      .sig_ok
    ; Invalid MCB chain - bail out
    jmp     .no_memory

.sig_ok:
    ; Check if block is free
    cmp     word [es:1], 0
    jne     .next_block

    ; Free block - check size
    mov     cx, [es:3]
    cmp     cx, bx
    jae     .found_block

    ; Track largest
    cmp     cx, dx
    jbe     .next_block
    mov     dx, cx

.next_block:
    cmp     byte [es:0], 'Z'   ; Last block?
    je      .no_memory
    
    ; Next MCB = current + 1 + size
    mov     cx, [es:3]
    inc     cx                  ; +1 for MCB header
    add     ax, cx
    jmp     .scan_loop
    
.found_block:
    ; Check if we should split the block
    mov     cx, [es:3]
    sub     cx, bx              ; Remaining size = original - requested
    cmp     cx, 2               ; Need at least 2 paragraphs for new MCB + 1 para data
    jb      .use_whole_block

    ; Split: create new free MCB after the allocated block
    push    ax
    mov     si, ax
    add     si, bx
    inc     si                  ; New MCB segment = current_mcb + 1 + requested

    ; Get original block's signature (use DL to avoid corrupting CX)
    mov     dl, [es:0]          ; Original signature ('M' or 'Z')

    ; Set up new free MCB
    push    es
    mov     es, si
    mov     [es:0], dl          ; New block gets original's signature
    mov     word [es:1], 0      ; Free (no owner)
    ; New block size = remaining - 1 (for the new MCB header)
    dec     cx
    mov     [es:3], cx
    ; Clear name field
    mov     word [es:5], 0
    mov     word [es:7], 0
    pop     es

    ; Update original block (the one we're allocating)
    mov     byte [es:0], 'M'    ; Not last anymore
    mov     [es:3], bx          ; Exact size requested

    pop     ax
    jmp     .alloc_done
    
.use_whole_block:
    ; Use entire block (no split)
    ; AX already has segment
    
.alloc_done:
    ; Mark as owned by current process
    mov     cx, [current_psp]
    mov     [es:1], cx          ; Set owner
    
    ; Return segment after MCB header
    inc     ax                  ; Skip MCB header paragraph
    
    clc
    pop     es
    pop     si
    pop     dx
    pop     cx
    ret
    
.no_memory:
    mov     bx, dx              ; Return largest available
    stc
    pop     es
    pop     si
    pop     dx
    pop     cx
    ret

; ---------------------------------------------------------------------------
; mcb_free - Free a memory block
; Input: ES = segment of block to free (segment after MCB, i.e. what alloc returned)
; Output: CF set on error
; ---------------------------------------------------------------------------
mcb_free:
    push    ax
    push    es
    
    ; MCB is one paragraph before the block
    mov     ax, es
    dec     ax
    mov     es, ax
    
    ; Verify it's a valid MCB
    cmp     byte [es:0], 'M'
    je      .valid
    cmp     byte [es:0], 'Z'
    je      .valid
    
    stc                         ; Invalid MCB
    pop     es
    pop     ax
    ret
    
.valid:
    mov     word [es:1], 0          ; Mark as free

    ; Coalesce with next block if free
    cmp     byte [es:0], 'Z'
    je      .free_done              ; Last block

    push    bx
    push    cx
    push    dx

    mov     ax, es
    mov     cx, [es:3]              ; Current size
    add     ax, cx
    inc     ax                      ; Next MCB segment

    push    es
    mov     es, ax
    cmp     byte [es:0], 'M'
    je      .check_free
    cmp     byte [es:0], 'Z'
    je      .check_free
    pop     es
    jmp     .no_coalesce

.check_free:
    cmp     word [es:1], 0
    jne     .not_free

    ; Merge: size += 1 + next_size
    mov     dx, [es:3]
    mov     bl, [es:0]
    pop     es
    add     cx, dx
    inc     cx
    mov     [es:3], cx
    mov     [es:0], bl
    jmp     .coalesce_done

.not_free:
    pop     es
.no_coalesce:
.coalesce_done:
    pop     dx
    pop     cx
    pop     bx

.free_done:
    clc
    pop     es
    pop     ax
    ret

; ---------------------------------------------------------------------------
; mcb_resize - Resize a memory block
; Input: ES = segment of block, BX = new size in paragraphs
; Output: CF set on error, BX = max available size
; ---------------------------------------------------------------------------
mcb_resize:
    push    ax
    push    cx
    push    dx
    push    si
    push    es

    ; MCB is one paragraph before the block
    mov     ax, es
    dec     ax
    mov     es, ax                  ; ES = MCB segment

    ; Verify valid MCB
    cmp     byte [es:0], 'M'
    je      .valid
    cmp     byte [es:0], 'Z'
    je      .valid
    jmp     .resize_fail

.valid:
    mov     cx, [es:3]              ; CX = current size in paragraphs

    cmp     bx, cx
    je      .resize_same
    ja      .resize_grow

    ; --- SHRINK ---
    ; Create new free MCB at ES + 1 + BX
    mov     ax, es
    add     ax, bx
    inc     ax                      ; AX = new free MCB segment
    push    es
    mov     si, es                  ; SI = original MCB segment

    ; Save original signature
    mov     dl, [es:0]              ; Original signature

    ; Set up the new free MCB
    mov     es, ax
    mov     [es:0], dl              ; New MCB gets original's signature
    mov     word [es:1], 0          ; Free block
    mov     ax, cx
    sub     ax, bx
    dec     ax                      ; New block size = old_size - new_size - 1
    mov     [es:3], ax
    ; Clear name
    mov     word [es:5], 0
    mov     word [es:7], 0
    mov     word [es:9], 0
    mov     word [es:11], 0

    ; Update original MCB
    pop     es                      ; ES = original MCB again
    mov     [es:3], bx              ; Set new size
    mov     byte [es:0], 'M'        ; Not last anymore

    ; Try to coalesce the new free MCB with the following block
    mov     ax, es
    add     ax, bx
    inc     ax                      ; AX = new free MCB segment
    call    .coalesce_with_next

    jmp     .resize_ok

    ; --- GROW ---
.resize_grow:
    ; Check if next MCB is free and adjacent
    cmp     byte [es:0], 'Z'        ; If this is the last block, can't grow
    je      .grow_fail

    ; Next MCB segment = current_mcb + 1 + current_size
    mov     ax, es
    add     ax, cx
    inc     ax                      ; AX = next MCB segment

    push    es
    mov     es, ax                  ; ES = next MCB

    ; Verify it's a valid MCB
    cmp     byte [es:0], 'M'
    je      .next_valid
    cmp     byte [es:0], 'Z'
    je      .next_valid
    pop     es
    jmp     .grow_fail

.next_valid:
    ; Check if it's free
    cmp     word [es:1], 0
    jne     .next_not_free

    ; Combined size = current_size + 1 (for next MCB header) + next_size
    mov     dx, [es:3]              ; Next block size
    mov     si, dx
    add     si, cx
    inc     si                      ; SI = total available

    cmp     si, bx                  ; Enough space?
    jb      .not_enough

    ; Save next block's signature
    mov     dl, [es:0]              ; Next block's signature

    pop     es                      ; ES = original MCB

    ; Merge: set current size to combined
    ; If combined > requested, re-split
    cmp     si, bx
    je      .exact_fit

    ; Re-split: create new free MCB after our new size
    mov     [es:3], bx              ; Set our new size
    mov     byte [es:0], 'M'        ; We're not last

    ; New free MCB at current_mcb + 1 + bx
    push    es
    mov     ax, es
    add     ax, bx
    inc     ax
    mov     es, ax
    mov     [es:0], dl              ; Use saved signature from DL

    ; Actually recalculate: the new free block gets the old next block's signature
    ; We saved it in AL above but it got clobbered. Let's fix the approach.
    pop     es

    ; Redo: save signature properly
    ; Original MCB at ES. Next MCB sig was saved in AL before pop.
    ; But we already did pop es. Let me restructure.
    ; The next block's signature tells us if it was the last ('Z') or not ('M').
    ; If next was 'Z', our new remainder should be 'Z'.
    ; If next was 'M', our new remainder should be 'M'.
    ; We need to track this. Let's use the stack.

    ; Hmm, let me just re-check the next-next block situation.
    ; After merging, if the original next was 'Z', the remainder is 'Z'.
    ; If 'M', the remainder is 'M'.
    ; But we lost the sig. Let's just check: is there a block after the combined area?
    ; combined_end = current_mcb + 1 + current_size + 1 + next_size
    ; If next sig was 'Z', nothing after. Our remainder is 'Z'.
    ; If next sig was 'M', there's more. Our remainder is 'M'.

    ; Since we already merged and the signature is now in the MCB area that
    ; we're about to overwrite, let's just check if current_mcb + 1 + si
    ; is within memory. Simpler: if si > bx by enough, the remainder gets
    ; the same sig the next block had.

    ; Let's redo this more carefully
    jmp     .grow_resplit

.exact_fit:
    ; Use entire merged area
    mov     [es:3], bx
    ; Keep signature from next block (if next was 'Z', we become 'Z')
    mov     [es:0], dl              ; DL still has next block's sig
    jmp     .resize_ok

.grow_resplit:
    ; We need the next block's signature. Let's re-read it.
    ; Next MCB is at current_mcb + 1 + cx (cx = original current size)
    push    es
    mov     ax, es
    add     ax, cx
    inc     ax
    mov     es, ax
    mov     dl, [es:0]              ; DL = next block's signature
    pop     es

    ; Now set our block size
    mov     [es:3], bx
    mov     byte [es:0], 'M'        ; Not last (there's a remainder)

    ; Create remainder free MCB
    push    es
    mov     ax, es
    add     ax, bx
    inc     ax
    mov     es, ax
    mov     [es:0], dl              ; Remainder gets next block's signature
    mov     word [es:1], 0          ; Free
    mov     ax, si
    sub     ax, bx
    dec     ax                      ; Remainder size
    mov     [es:3], ax
    mov     word [es:5], 0
    mov     word [es:7], 0
    mov     word [es:9], 0
    mov     word [es:11], 0
    pop     es
    jmp     .resize_ok

.not_enough:
    ; Not enough space even with merge
    ; BX = max we could offer = current_size + 1 + next_size
    mov     bx, si
    pop     es
    jmp     .resize_fail

.next_not_free:
    pop     es
    ; Can't grow - next block is in use
    mov     bx, cx                  ; BX = current size (max available)
    jmp     .resize_fail

.grow_fail:
    mov     bx, cx                  ; BX = current size (max available)
    jmp     .resize_fail

.resize_same:
    ; Nothing to do
.resize_ok:
    clc
    pop     es
    pop     si
    pop     dx
    pop     cx
    pop     ax
    ret

.resize_fail:
    stc
    pop     es
    pop     si
    pop     dx
    pop     cx
    pop     ax
    ret

; ---------------------------------------------------------------------------
; .coalesce_with_next - Merge a free MCB with the following free MCB if possible
; Input: AX = segment of free MCB to try coalescing
; Clobbers: AX, CX, DX, ES
; ---------------------------------------------------------------------------
.coalesce_with_next:
    push    es
    mov     es, ax

    ; If this is the last block, nothing to coalesce
    cmp     byte [es:0], 'Z'
    je      .coal_done

    ; Find next MCB
    mov     cx, [es:3]              ; Current block size
    mov     dx, ax
    add     dx, cx
    inc     dx                      ; DX = next MCB segment

    push    es
    mov     es, dx

    ; Check if next is free
    cmp     word [es:1], 0
    jne     .coal_not_free

    ; Merge: add next block's size + 1 to current
    mov     ax, [es:3]
    mov     dl, [es:0]              ; Next block's signature
    pop     es                      ; ES = current free MCB

    add     cx, ax
    inc     cx                      ; Combined size
    mov     [es:3], cx
    mov     [es:0], dl              ; Inherit signature

    pop     es
    ret

.coal_not_free:
    pop     es
.coal_done:
    pop     es
    ret

