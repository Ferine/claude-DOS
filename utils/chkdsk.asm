; ===========================================================================
; CHKDSK.COM - Check disk integrity
; ===========================================================================
    CPU     186
    ORG     0x0100

    ; Get disk free space
    mov     ah, 0x36
    mov     dl, 0               ; Default drive
    int     0x21

    ; AX=sec/cluster, BX=free clusters, CX=bytes/sec, DX=total clusters
    push    ax
    push    bx
    push    cx
    push    dx

    ; Print header
    mov     dx, chk_header
    mov     ah, 0x09
    int     0x21

    ; Total space: total_clusters * sec_per_cluster * bytes_per_sector
    pop     dx                  ; Total clusters
    pop     cx                  ; Bytes/sector
    pop     bx                  ; Free clusters
    pop     ax                  ; Sec/cluster

    ; Calculate total bytes (simplified, may overflow for large disks)
    push    bx                  ; Save free clusters
    push    ax                  ; Save sec/cluster
    mul     dx                  ; AX = sec/cluster * total_clusters
    mul     cx                  ; DX:AX = total bytes

    push    dx
    push    ax
    mov     dx, chk_total
    mov     ah, 0x09
    int     0x21
    pop     ax
    pop     dx
    call    print_dec32
    mov     dx, chk_bytes
    mov     ah, 0x09
    int     0x21

    ; Free space
    pop     ax                  ; sec/cluster
    pop     bx                  ; free clusters
    mul     bx                  ; AX = sec/cluster * free_clusters
    mov     bx, 512
    mul     bx                  ; DX:AX = free bytes

    push    dx
    push    ax
    mov     dx, chk_free
    mov     ah, 0x09
    int     0x21
    pop     ax
    pop     dx
    call    print_dec32
    mov     dx, chk_bytes
    mov     ah, 0x09
    int     0x21

    mov     ax, 0x4C00
    int     0x21

; Print 32-bit number in DX:AX
print_dec32:
    ; Simple: just print AX (low 16 bits) for now
    push    ax
    mov     ax, dx
    test    ax, ax
    jz      .low_only
    ; Has high word - print it first (simplified)
    call    .print16
    mov     dl, ','
    mov     ah, 0x02
    int     0x21
.low_only:
    pop     ax
    call    .print16
    ret

.print16:
    xor     cx, cx
    mov     bx, 10
.div:
    xor     dx, dx
    div     bx
    push    dx
    inc     cx
    test    ax, ax
    jnz     .div
.out:
    pop     dx
    add     dl, '0'
    mov     ah, 0x02
    int     0x21
    loop    .out
    ret

chk_header  db  0x0D, 0x0A, 'claudeDOS Disk Check', 0x0D, 0x0A, 0x0D, 0x0A, '$'
chk_total   db  '  Total disk space:  $'
chk_free    db  '  Free disk space:   $'
chk_bytes   db  ' bytes', 0x0D, 0x0A, '$'
