; ===========================================================================
; claudeDOS INT 21h FCB Functions
; ===========================================================================
; FCB layout:
;   00h: Drive (0=default, 1=A:, 2=B:, etc)
;   01h: Filename (8 bytes, space-padded)
;   09h: Extension (3 bytes, space-padded)
;   0Ch: Current block (word)
;   0Eh: Record size (word, default 128)
;   10h: File size (dword)
;   14h: Date
;   16h: Time
;   18h: Reserved (8 bytes - we store SFT index here)
;   20h: Current record in block (byte)
;   21h: Random record number (dword)

FCB_DRIVE       equ     0
FCB_FILENAME    equ     1
FCB_EXTENSION   equ     9
FCB_CUR_BLOCK   equ     0x0C
FCB_REC_SIZE    equ     0x0E
FCB_FILE_SIZE   equ     0x10
FCB_DATE        equ     0x14
FCB_TIME        equ     0x16
FCB_RESERVED    equ     0x18
FCB_CUR_REC     equ     0x20
FCB_RAND_REC    equ     0x21

; ---------------------------------------------------------------------------
; int21_0F - FCB Open file
; Input: DS:DX = FCB pointer (caller's DS)
; Output: AL = 00h if successful, FFh if not found
; ---------------------------------------------------------------------------
int21_0F:
    push    es
    push    si
    push    di
    push    bx
    push    cx
    push    dx

    ; Get FCB pointer from caller's DS:DX
    mov     es, [save_ds]
    mov     di, [save_dx]           ; ES:DI = FCB

    ; Copy FCB filename (bytes 1-11) to fcb_name_buffer
    push    di
    add     di, FCB_FILENAME        ; Point to filename in FCB
    mov     si, fcb_name_buffer
    mov     cx, 11
.copy_name:
    mov     al, [es:di]
    mov     [si], al
    inc     di
    inc     si
    loop    .copy_name
    pop     di

    ; Search for file in root directory
    mov     si, fcb_name_buffer
    call    fat_find_in_root
    jc      .not_found

    ; Found: DI (kernel) = directory entry pointer, AX = sector
    ; ES:save_dx points to caller's FCB
    ; Get file info from directory entry in disk_buffer
    push    di                      ; Save dir entry pointer

    ; Get FCB pointer again (ES = caller's segment)
    mov     es, [save_ds]
    mov     di, [save_dx]           ; ES:DI = FCB

    pop     si                      ; SI = dir entry in disk_buffer

    ; Fill FCB fields from directory entry
    ; File size (offset 10h in FCB, offset 28 in dir entry)
    mov     ax, [si + 28]           ; Size low
    mov     [es:di + FCB_FILE_SIZE], ax
    mov     ax, [si + 30]           ; Size high
    mov     [es:di + FCB_FILE_SIZE + 2], ax

    ; Date (offset 14h in FCB, offset 24 in dir entry)
    mov     ax, [si + 24]
    mov     [es:di + FCB_DATE], ax

    ; Time (offset 16h in FCB, offset 22 in dir entry)
    mov     ax, [si + 22]
    mov     [es:di + FCB_TIME], ax

    ; Initialize FCB fields
    mov     word [es:di + FCB_CUR_BLOCK], 0     ; Current block = 0
    mov     word [es:di + FCB_REC_SIZE], 128    ; Default record size
    mov     byte [es:di + FCB_CUR_REC], 0       ; Current record = 0
    mov     word [es:di + FCB_RAND_REC], 0      ; Random record = 0 (low)
    mov     word [es:di + FCB_RAND_REC + 2], 0  ; Random record = 0 (high)

    ; Store first cluster in reserved area for later use
    mov     ax, [si + 26]           ; First cluster from dir entry
    mov     [es:di + FCB_RESERVED], ax
    ; Store directory sector/index for updates
    mov     ax, [search_dir_sector]
    mov     [es:di + FCB_RESERVED + 2], ax
    mov     ax, [search_dir_index]
    mov     [es:di + FCB_RESERVED + 4], ax

    ; Return success
    mov     byte [save_ax], 0       ; AL = 0 = success

    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    ret

.not_found:
    mov     byte [save_ax], 0xFF    ; AL = FFh = file not found
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    ret

; ---------------------------------------------------------------------------
; int21_10 - FCB Close file
; Input: DS:DX = FCB pointer
; Output: AL = 00h if successful, FFh if error
; ---------------------------------------------------------------------------
int21_10:
    ; For read-only operations, close is simple - just return success
    ; A full implementation would update the directory entry if modified
    mov     byte [save_ax], 0
    ret

; ---------------------------------------------------------------------------
; int21_11 - FCB Find first matching file
; Input: DS:DX = FCB pointer (may contain wildcards)
; Output: AL = 00h if found, FFh if not found
;         DTA filled with matching entry
; ---------------------------------------------------------------------------
int21_11:
    ; For now, stub - return not found
    mov     byte [save_ax], 0xFF
    ret

; ---------------------------------------------------------------------------
; int21_12 - FCB Find next matching file
; Output: AL = 00h if found, FFh if no more
; ---------------------------------------------------------------------------
int21_12:
    mov     byte [save_ax], 0xFF
    ret

; ---------------------------------------------------------------------------
; int21_13 - FCB Delete file
; Input: DS:DX = FCB pointer
; Output: AL = 00h if successful, FFh if not found
; ---------------------------------------------------------------------------
int21_13:
    mov     byte [save_ax], 0xFF
    ret

; ---------------------------------------------------------------------------
; int21_14 - FCB Sequential read
; Input: DS:DX = FCB pointer
; Output: AL = 00h if successful
;             01h if EOF (no data)
;             02h if DTA too small
;             03h if partial record at EOF
; Reads one record to DTA, advances current record
; ---------------------------------------------------------------------------
int21_14:
    push    es
    push    si
    push    di
    push    bx
    push    cx
    push    dx
    push    bp

    ; Get FCB pointer
    mov     es, [save_ds]
    mov     bp, [save_dx]           ; ES:BP = FCB

    ; Calculate file offset: (cur_block * 128 + cur_rec) * rec_size
    ; Record number = cur_block * 128 + cur_rec
    mov     ax, [es:bp + FCB_CUR_BLOCK]
    mov     cl, 7
    shl     ax, cl                  ; AX = cur_block * 128
    xor     bh, bh
    mov     bl, [es:bp + FCB_CUR_REC]
    add     ax, bx                  ; AX = record number

    ; File offset = record_number * record_size
    mov     bx, [es:bp + FCB_REC_SIZE]
    mul     bx                      ; DX:AX = file offset
    ; DX:AX is 32-bit file offset

    ; Check if offset >= file size (EOF)
    cmp     dx, [es:bp + FCB_FILE_SIZE + 2]
    ja      .eof
    jb      .read_ok
    cmp     ax, [es:bp + FCB_FILE_SIZE]
    jae     .eof

.read_ok:
    ; Save file offset for cluster walk
    mov     [.file_offset], ax
    mov     [.file_offset + 2], dx

    ; Calculate which cluster we need
    ; cluster_index = file_offset / 512 (for 1 sector/cluster)
    mov     ax, [.file_offset + 2]
    mov     dx, [.file_offset]
    ; Shift right 9 to divide by 512
    mov     cx, 9
.shift_loop:
    shr     ax, 1
    rcr     dx, 1
    loop    .shift_loop
    ; DX = cluster index (sector offset from start)
    mov     [.cluster_index], dx

    ; Walk cluster chain to find the cluster
    mov     ax, [es:bp + FCB_RESERVED] ; First cluster (stored in FCB)
    mov     cx, [.cluster_index]
    test    cx, cx
    jz      .have_cluster

.walk_chain:
    push    cx
    call    fat_get_next_cluster
    pop     cx
    cmp     ax, 0x0FF8
    jae     .eof                    ; Unexpected EOF
    dec     cx
    jnz     .walk_chain

.have_cluster:
    ; AX = cluster to read
    ; Read cluster into disk_buffer
    push    es
    push    cs
    pop     es
    mov     bx, disk_buffer
    call    fat_cluster_to_lba
    call    fat_read_sector
    pop     es
    jc      .read_error

    ; Calculate offset within sector
    mov     ax, [.file_offset]
    and     ax, 0x01FF              ; offset mod 512

    ; Calculate bytes to copy (record size, clamped to EOF)
    mov     cx, [es:bp + FCB_REC_SIZE]

    ; Check for partial record at EOF
    mov     bx, [es:bp + FCB_FILE_SIZE]
    mov     dx, [es:bp + FCB_FILE_SIZE + 2]
    sub     bx, [.file_offset]
    sbb     dx, [.file_offset + 2]
    ; DX:BX = bytes remaining in file

    test    dx, dx
    jnz     .copy_full              ; More than 64K remaining
    cmp     bx, cx
    jae     .copy_full
    ; Partial record
    mov     cx, bx
    test    cx, cx
    jz      .eof
    mov     byte [.partial], 1
    jmp     .do_copy

.copy_full:
    mov     byte [.partial], 0

.do_copy:
    ; Copy from disk_buffer + offset to DTA
    push    es
    push    di

    ; Get DTA address
    push    cs
    pop     es
    mov     di, [current_dta_off]
    mov     es, [current_dta_seg]   ; ES:DI = DTA

    ; Source: disk_buffer + offset
    mov     si, disk_buffer
    add     si, ax                  ; SI = disk_buffer + offset

    ; Handle case where read spans sector boundary
    mov     bx, 512
    sub     bx, ax                  ; BX = bytes available in this sector
    cmp     bx, cx
    jae     .single_copy

    ; Need to span two sectors - copy first part
    push    cx
    mov     cx, bx
    push    ds
    push    cs
    pop     ds
    rep     movsb
    pop     ds
    pop     cx
    sub     cx, bx                  ; Remaining bytes

    ; Read next cluster
    push    cx
    push    es
    push    di
    mov     ax, [.cluster_index]
    inc     ax
    mov     [.cluster_index], ax

    ; Get next cluster
    push    cs
    pop     es
    mov     ax, [cs:save_ds]
    mov     ds, ax
    mov     bp, [cs:save_dx]
    mov     ax, [bp + FCB_RESERVED] ; First cluster
    push    cs
    pop     ds
    mov     cx, [.cluster_index]
.walk2:
    push    cx
    call    fat_get_next_cluster
    pop     cx
    dec     cx
    jnz     .walk2

    mov     bx, disk_buffer
    push    cs
    pop     es
    call    fat_cluster_to_lba
    call    fat_read_sector
    pop     di
    pop     es
    pop     cx
    jc      .read_error_pop

    ; Copy remaining bytes from start of new sector
    mov     si, disk_buffer
    push    ds
    push    cs
    pop     ds
    rep     movsb
    pop     ds
    jmp     .copy_done

.single_copy:
    push    ds
    push    cs
    pop     ds
    rep     movsb
    pop     ds

.copy_done:
    pop     di
    pop     es

    ; Advance FCB record position
    mov     es, [save_ds]
    mov     bp, [save_dx]
    inc     byte [es:bp + FCB_CUR_REC]
    cmp     byte [es:bp + FCB_CUR_REC], 128
    jb      .no_block_inc
    mov     byte [es:bp + FCB_CUR_REC], 0
    inc     word [es:bp + FCB_CUR_BLOCK]
.no_block_inc:

    ; Return status
    cmp     byte [.partial], 0
    jne     .return_partial
    mov     byte [save_ax], 0       ; AL = 0 = success
    jmp     .done

.return_partial:
    mov     byte [save_ax], 3       ; AL = 3 = partial record

.done:
    pop     bp
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    ret

.eof:
    mov     byte [save_ax], 1       ; AL = 1 = EOF
    pop     bp
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    ret

.read_error:
    mov     byte [save_ax], 1       ; Treat as EOF
    pop     bp
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    ret

.read_error_pop:
    pop     di
    pop     es
    jmp     .read_error

; Local variables
.file_offset    dd  0
.cluster_index  dw  0
.partial        db  0

; ---------------------------------------------------------------------------
; int21_15 - FCB Sequential write
; Input: DS:DX = FCB pointer
; Output: AL = 00h if successful, 01h if disk full, 02h if error
; Writes one record from DTA, advances current record
; ---------------------------------------------------------------------------
int21_15:
    push    es
    push    si
    push    di
    push    bx
    push    cx
    push    dx
    push    bp

    ; Get FCB pointer
    mov     es, [save_ds]
    mov     bp, [save_dx]           ; ES:BP = FCB

    ; Calculate file offset: (cur_block * 128 + cur_rec) * rec_size
    mov     ax, [es:bp + FCB_CUR_BLOCK]
    mov     cl, 7
    shl     ax, cl                  ; AX = cur_block * 128
    xor     bh, bh
    mov     bl, [es:bp + FCB_CUR_REC]
    add     ax, bx                  ; AX = record number

    ; File offset = record_number * record_size
    mov     bx, [es:bp + FCB_REC_SIZE]
    mul     bx                      ; DX:AX = file offset

    ; Save file offset
    mov     [.wr15_offset], ax
    mov     [.wr15_offset + 2], dx

    ; Calculate which cluster we need (sector index = file_offset / 512)
    mov     ax, [.wr15_offset + 2]
    mov     dx, [.wr15_offset]
    mov     cx, 9
.shift_15:
    shr     ax, 1
    rcr     dx, 1
    loop    .shift_15
    mov     [.wr15_cluster_idx], dx ; Sector/cluster index

    ; Get first cluster from FCB
    mov     ax, [es:bp + FCB_RESERVED]

    ; If file has no clusters yet, allocate first one
    test    ax, ax
    jnz     .have_cluster_15
    call    fat_alloc_cluster
    jc      .disk_full_15
    ; AX = new cluster, mark it as end of chain
    push    ax
    mov     dx, 0x0FFF              ; End of chain marker
    call    fat_set_cluster
    pop     ax
    ; Store in FCB and directory entry
    mov     [es:bp + FCB_RESERVED], ax
    ; Also need to update directory entry
    push    ax
    push    es
    push    cs
    pop     es
    mov     bx, disk_buffer
    push    ax
    mov     ax, [cs:save_ds]
    mov     es, ax
    mov     ax, [es:bp + FCB_RESERVED + 2]  ; Dir sector
    push    cs
    pop     es
    call    fat_read_sector
    pop     ax
    pop     es
    jc      .error_15

    ; Update first cluster in directory entry
    push    es
    mov     es, [save_ds]
    mov     di, [es:bp + FCB_RESERVED + 4]  ; Dir index
    push    cs
    pop     es
    shl     di, 5                   ; * 32
    add     di, disk_buffer
    pop     ax                      ; First cluster
    mov     [di + 26], ax

    ; Write directory back
    push    cs
    pop     es
    push    ax
    mov     ax, [save_ds]
    push    ax
    mov     es, ax
    mov     ax, [es:bp + FCB_RESERVED + 2]
    pop     ax
    push    cs
    pop     es
    mov     bx, disk_buffer
    call    fat_write_sector
    pop     ax
    jc      .error_15
    jmp     .have_cluster_15

.have_cluster_15:
    ; Walk cluster chain to find target cluster
    mov     cx, [.wr15_cluster_idx]
    test    cx, cx
    jz      .at_cluster_15

.walk_chain_15:
    push    cx
    push    ax
    call    fat_get_next_cluster
    cmp     ax, 0x0FF8
    jae     .need_extend_15
    mov     bx, ax
    pop     ax
    mov     ax, bx
    pop     cx
    dec     cx
    jnz     .walk_chain_15
    jmp     .at_cluster_15

.need_extend_15:
    ; Need to extend file - allocate new cluster
    pop     ax                      ; Previous cluster
    pop     cx                      ; Remaining count
    push    ax                      ; Save prev cluster
    call    fat_alloc_cluster
    jc      .disk_full_15_pop
    mov     bx, ax                  ; BX = new cluster
    ; Link prev cluster to new cluster
    pop     ax                      ; AX = prev cluster
    push    bx                      ; Save new cluster
    mov     dx, bx                  ; DX = new cluster
    call    fat_set_cluster         ; Link prev -> new
    pop     ax                      ; AX = new cluster
    ; Mark new as end of chain
    push    ax
    mov     dx, 0x0FFF
    call    fat_set_cluster
    pop     ax
    dec     cx
    jnz     .walk_chain_15

.at_cluster_15:
    ; AX = cluster to write to
    mov     [.wr15_cur_cluster], ax

    ; Read the sector
    push    cs
    pop     es
    mov     bx, disk_buffer
    call    fat_cluster_to_lba
    push    ax                      ; Save LBA
    call    fat_read_sector
    pop     ax                      ; Restore LBA
    jc      .error_15

    ; Calculate offset within sector
    mov     bx, [.wr15_offset]
    and     bx, 0x01FF              ; offset mod 512

    ; Copy record from DTA to disk_buffer
    mov     es, [save_ds]
    mov     cx, [es:bp + FCB_REC_SIZE]
    mov     si, [current_dta_off]
    push    ds
    mov     ds, [current_dta_seg]   ; DS:SI = DTA
    push    cs
    pop     es
    mov     di, disk_buffer
    add     di, bx                  ; ES:DI = disk_buffer + offset
    rep     movsb
    pop     ds

    ; Write sector back
    push    cs
    pop     es
    mov     bx, disk_buffer
    ; AX still has LBA
    mov     ax, [.wr15_cur_cluster]
    call    fat_cluster_to_lba
    call    fat_write_sector
    jc      .error_15

    ; Update file size if we wrote past current end
    mov     ax, [.wr15_offset]
    mov     dx, [.wr15_offset + 2]
    mov     es, [save_ds]
    mov     cx, [es:bp + FCB_REC_SIZE]
    add     ax, cx
    adc     dx, 0                   ; DX:AX = new end position

    ; Compare with current file size
    cmp     dx, [es:bp + FCB_FILE_SIZE + 2]
    jb      .no_size_update_15
    ja      .update_size_15
    cmp     ax, [es:bp + FCB_FILE_SIZE]
    jbe     .no_size_update_15

.update_size_15:
    ; Update FCB file size
    mov     [es:bp + FCB_FILE_SIZE], ax
    mov     [es:bp + FCB_FILE_SIZE + 2], dx

    ; Also update directory entry
    push    ax
    push    dx
    push    cs
    pop     es
    mov     bx, disk_buffer
    push    ax
    mov     ax, [save_ds]
    mov     es, ax
    mov     ax, [es:bp + FCB_RESERVED + 2]  ; Dir sector
    push    cs
    pop     es
    call    fat_read_sector
    pop     ax
    jc      .error_15_pop2

    mov     es, [save_ds]
    mov     di, [es:bp + FCB_RESERVED + 4]  ; Dir index
    push    cs
    pop     es
    shl     di, 5
    add     di, disk_buffer
    pop     dx
    pop     ax
    mov     [di + 28], ax           ; Size low
    mov     [di + 30], dx           ; Size high
    ; Also update first cluster if needed
    mov     es, [save_ds]
    mov     ax, [es:bp + FCB_RESERVED]
    push    cs
    pop     es
    mov     [di + 26], ax

    ; Write directory back
    mov     bx, disk_buffer
    mov     es, [save_ds]
    mov     ax, [es:bp + FCB_RESERVED + 2]
    push    cs
    pop     es
    call    fat_write_sector
    jc      .error_15

.no_size_update_15:
    ; Advance FCB record position
    mov     es, [save_ds]
    inc     byte [es:bp + FCB_CUR_REC]
    cmp     byte [es:bp + FCB_CUR_REC], 128
    jb      .done_15
    mov     byte [es:bp + FCB_CUR_REC], 0
    inc     word [es:bp + FCB_CUR_BLOCK]

.done_15:
    mov     byte [save_ax], 0       ; Success
    pop     bp
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    ret

.error_15_pop2:
    add     sp, 4
.error_15:
    mov     byte [save_ax], 2       ; Error
    pop     bp
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    ret

.disk_full_15_pop:
    add     sp, 4
.disk_full_15:
    mov     byte [save_ax], 1       ; Disk full
    pop     bp
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    ret

; Local data for FCB Sequential Write
.wr15_offset        dd  0
.wr15_cluster_idx   dw  0
.wr15_cur_cluster   dw  0

; ---------------------------------------------------------------------------
; int21_16 - FCB Create file
; Input: DS:DX = FCB pointer
; Output: AL = 00h if successful, FFh if error
; ---------------------------------------------------------------------------
int21_16:
    push    es
    push    si
    push    di
    push    bx
    push    cx
    push    dx

    ; Get FCB pointer from caller's DS:DX
    mov     es, [save_ds]
    mov     di, [save_dx]           ; ES:DI = FCB

    ; Copy FCB filename (bytes 1-11) to fcb_name_buffer
    push    di
    add     di, FCB_FILENAME
    mov     si, fcb_name_buffer
    mov     cx, 11
.copy_name_16:
    mov     al, [es:di]
    mov     [si], al
    inc     di
    inc     si
    loop    .copy_name_16
    pop     di

    ; Search root directory for existing file
    mov     si, fcb_name_buffer
    call    fat_find_in_root
    jc      .create_new_16

    ; File exists - truncate it (free cluster chain, reset size)
    mov     [.cr16_dir_sector], ax
    push    di                      ; Save FCB pointer
    mov     bx, di
    mov     di, disk_buffer
    push    ax
    mov     ax, bx
    sub     ax, disk_buffer         ; Hmm, DI is in ES segment...

    ; Actually, dir entry is in disk_buffer (kernel segment)
    ; search_dir_sector and search_dir_index were set by fat_find_in_root
    ; Let me recalculate - DI from fat_find_in_root points into disk_buffer
    pop     ax                      ; Restore sector
    ; DI should still point to the directory entry in disk_buffer

    ; Free existing cluster chain if any
    mov     ax, [di + 26]           ; First cluster
    test    ax, ax
    jz      .no_chain_16
    cmp     ax, 2
    jb      .no_chain_16
    call    fat_free_chain

.no_chain_16:
    ; Reset entry to empty file
    xor     ax, ax
    mov     [di + 26], ax           ; First cluster = 0
    mov     [di + 28], ax           ; Size low = 0
    mov     [di + 30], ax           ; Size high = 0

    ; Write directory sector back
    push    cs
    pop     es
    mov     bx, disk_buffer
    mov     ax, [.cr16_dir_sector]
    call    fat_write_sector
    pop     di                      ; Restore FCB pointer
    mov     es, [save_ds]           ; Restore ES to caller's segment
    jc      .error_16
    jmp     .init_fcb_16

.create_new_16:
    ; File doesn't exist - find empty slot in root directory
    mov     ax, 19                  ; Root dir start
    mov     cx, 14                  ; Root dir sectors

.scan_root_16:
    push    cx
    push    ax
    push    cs
    pop     es
    mov     bx, disk_buffer
    call    fat_read_sector
    jc      .read_error_16

    ; Search 16 entries per sector
    mov     di, disk_buffer
    xor     cx, cx

.scan_entry_16:
    cmp     cx, 16
    jae     .next_sector_16
    cmp     byte [di], 0x00         ; Empty
    je      .found_slot_16
    cmp     byte [di], 0xE5         ; Deleted
    je      .found_slot_16
    add     di, 32
    inc     cx
    jmp     .scan_entry_16

.next_sector_16:
    pop     ax
    pop     cx
    inc     ax
    loop    .scan_root_16
    jmp     .dir_full_16

.found_slot_16:
    pop     ax                      ; Sector number
    mov     [.cr16_dir_sector], ax
    mov     [.cr16_dir_index], cx
    pop     cx                      ; Clean up outer CX

    ; Initialize directory entry
    ; Copy FCB name
    push    di
    mov     si, fcb_name_buffer
    mov     cx, 11
    rep     movsb
    pop     di

    ; Set attribute = 0 (normal file)
    xor     ax, ax
    mov     [di + 11], al

    ; Zero out all other fields
    mov     [di + 12], ax
    mov     [di + 14], ax
    mov     [di + 16], ax
    mov     [di + 18], ax
    mov     [di + 20], ax
    mov     [di + 22], ax           ; Time
    mov     [di + 24], ax           ; Date
    mov     [di + 26], ax           ; First cluster
    mov     [di + 28], ax           ; Size low
    mov     [di + 30], ax           ; Size high

    ; Write directory sector
    push    cs
    pop     es
    mov     bx, disk_buffer
    mov     ax, [.cr16_dir_sector]
    call    fat_write_sector
    mov     es, [save_ds]           ; Restore ES to caller's segment
    mov     di, [save_dx]           ; Restore FCB pointer
    jc      .error_16

.init_fcb_16:
    ; Initialize FCB fields
    ; ES:DI = FCB pointer
    mov     word [es:di + FCB_CUR_BLOCK], 0
    mov     word [es:di + FCB_REC_SIZE], 128
    mov     word [es:di + FCB_FILE_SIZE], 0
    mov     word [es:di + FCB_FILE_SIZE + 2], 0
    mov     word [es:di + FCB_DATE], 0
    mov     word [es:di + FCB_TIME], 0
    mov     byte [es:di + FCB_CUR_REC], 0
    mov     word [es:di + FCB_RAND_REC], 0
    mov     word [es:di + FCB_RAND_REC + 2], 0

    ; Store first cluster (0) and dir info in reserved area
    mov     word [es:di + FCB_RESERVED], 0          ; First cluster
    mov     ax, [.cr16_dir_sector]
    mov     [es:di + FCB_RESERVED + 2], ax          ; Dir sector
    mov     ax, [.cr16_dir_index]
    mov     [es:di + FCB_RESERVED + 4], ax          ; Dir index

    ; Return success
    mov     byte [save_ax], 0

    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    ret

.read_error_16:
    add     sp, 4                   ; Clean up pushed ax, cx
.dir_full_16:
.error_16:
    mov     byte [save_ax], 0xFF
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    ret

; Local data for FCB Create
.cr16_dir_sector    dw  0
.cr16_dir_index     dw  0

; ---------------------------------------------------------------------------
; int21_17 - FCB Rename file
; Input: DS:DX = FCB pointer (modified with new name at offset 11h)
; Output: AL = 00h if successful, FFh if error
; ---------------------------------------------------------------------------
int21_17:
    mov     byte [save_ax], 0xFF    ; Not implemented
    ret

; ---------------------------------------------------------------------------
; int21_18 - Reserved
; ---------------------------------------------------------------------------
int21_18:
    mov     byte [save_ax], 0xFF
    ret

; ---------------------------------------------------------------------------
; int21_21 - FCB Random Read
; Input: DS:DX = FCB pointer
; Output: AL = 00h if successful
;             01h if EOF (no data)
;             02h if DTA too small
;             03h if partial record at EOF
; Reads one record at random record position to DTA
; ---------------------------------------------------------------------------
int21_21:
    push    es
    push    si
    push    di
    push    bx
    push    cx
    push    dx
    push    bp

    ; Get FCB pointer
    mov     es, [save_ds]
    mov     bp, [save_dx]           ; ES:BP = FCB

    ; Get random record number (3 bytes at offset 21h)
    ; We only use the low word for simplicity (up to 65535 records)
    mov     ax, [es:bp + FCB_RAND_REC]

    ; Calculate file offset: random_record * record_size
    mov     bx, [es:bp + FCB_REC_SIZE]
    mul     bx                      ; DX:AX = file offset

    ; Check if offset >= file size (EOF)
    cmp     dx, [es:bp + FCB_FILE_SIZE + 2]
    ja      .eof_21
    jb      .read_ok_21
    cmp     ax, [es:bp + FCB_FILE_SIZE]
    jae     .eof_21

.read_ok_21:
    ; Save file offset for cluster walk
    mov     [.file_offset_21], ax
    mov     [.file_offset_21 + 2], dx

    ; Calculate which cluster we need (sector index = file_offset / 512)
    mov     ax, [.file_offset_21 + 2]
    mov     dx, [.file_offset_21]
    mov     cx, 9
.shift_loop_21:
    shr     ax, 1
    rcr     dx, 1
    loop    .shift_loop_21
    mov     [.cluster_index_21], dx

    ; Walk cluster chain to find the cluster
    mov     ax, [es:bp + FCB_RESERVED] ; First cluster
    mov     cx, [.cluster_index_21]
    test    cx, cx
    jz      .have_cluster_21

.walk_chain_21:
    push    cx
    call    fat_get_next_cluster
    pop     cx
    cmp     ax, 0x0FF8
    jae     .eof_21
    dec     cx
    jnz     .walk_chain_21

.have_cluster_21:
    ; Read cluster into disk_buffer
    push    es
    push    cs
    pop     es
    mov     bx, disk_buffer
    call    fat_cluster_to_lba
    call    fat_read_sector
    pop     es
    jc      .read_error_21

    ; Calculate offset within sector
    mov     ax, [.file_offset_21]
    and     ax, 0x01FF              ; offset mod 512

    ; Get record size
    mov     cx, [es:bp + FCB_REC_SIZE]

    ; Check for partial record at EOF
    mov     bx, [es:bp + FCB_FILE_SIZE]
    mov     dx, [es:bp + FCB_FILE_SIZE + 2]
    sub     bx, [.file_offset_21]
    sbb     dx, [.file_offset_21 + 2]

    test    dx, dx
    jnz     .copy_full_21
    cmp     bx, cx
    jae     .copy_full_21
    ; Partial record
    mov     cx, bx
    test    cx, cx
    jz      .eof_21
    mov     byte [.partial_21], 1
    jmp     .do_copy_21

.copy_full_21:
    mov     byte [.partial_21], 0

.do_copy_21:
    ; Copy from disk_buffer + offset to DTA
    push    es
    push    di
    mov     di, [current_dta_off]
    mov     es, [current_dta_seg]   ; ES:DI = DTA
    mov     si, disk_buffer
    add     si, ax                  ; SI = disk_buffer + offset

    push    ds
    push    cs
    pop     ds
    rep     movsb
    pop     ds

    pop     di
    pop     es

    ; Return status
    cmp     byte [.partial_21], 0
    jne     .return_partial_21
    mov     byte [save_ax], 0       ; AL = 0 = success
    jmp     .done_21

.return_partial_21:
    mov     byte [save_ax], 3       ; AL = 3 = partial record

.done_21:
    pop     bp
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    ret

.eof_21:
    mov     byte [save_ax], 1       ; AL = 1 = EOF
    pop     bp
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    ret

.read_error_21:
    mov     byte [save_ax], 1       ; Treat as EOF
    pop     bp
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    ret

; Local variables for int21_21
.file_offset_21     dd  0
.cluster_index_21   dw  0
.partial_21         db  0

; ---------------------------------------------------------------------------
; int21_22 - FCB Random Write
; Input: DS:DX = FCB pointer
; Output: AL = 00h if successful, 01h if disk full, 02h if error
; Writes one record from DTA to random record position
; ---------------------------------------------------------------------------
int21_22:
    push    es
    push    si
    push    di
    push    bx
    push    cx
    push    dx
    push    bp

    ; Get FCB pointer
    mov     es, [save_ds]
    mov     bp, [save_dx]           ; ES:BP = FCB

    ; Get random record number and calculate file offset
    mov     ax, [es:bp + FCB_RAND_REC]
    mov     bx, [es:bp + FCB_REC_SIZE]
    mul     bx                      ; DX:AX = file offset

    ; Save file offset
    mov     [.wr22_offset], ax
    mov     [.wr22_offset + 2], dx

    ; Calculate which cluster we need
    mov     ax, [.wr22_offset + 2]
    mov     dx, [.wr22_offset]
    mov     cx, 9
.shift_22:
    shr     ax, 1
    rcr     dx, 1
    loop    .shift_22
    mov     [.wr22_cluster_idx], dx

    ; Get first cluster from FCB
    mov     ax, [es:bp + FCB_RESERVED]

    ; If file has no clusters yet, allocate first one
    test    ax, ax
    jnz     .have_cluster_22
    call    fat_alloc_cluster
    jc      .disk_full_22
    push    ax
    mov     dx, 0x0FFF
    call    fat_set_cluster
    pop     ax
    mov     [es:bp + FCB_RESERVED], ax
    ; Update directory entry with new first cluster
    push    ax
    push    cs
    pop     es
    mov     bx, disk_buffer
    push    ax
    mov     ax, [save_ds]
    mov     es, ax
    mov     ax, [es:bp + FCB_RESERVED + 2]
    push    cs
    pop     es
    call    fat_read_sector
    pop     ax
    jc      .error_22_pop

    mov     es, [save_ds]
    mov     di, [es:bp + FCB_RESERVED + 4]
    push    cs
    pop     es
    shl     di, 5
    add     di, disk_buffer
    pop     ax
    mov     [di + 26], ax

    push    cs
    pop     es
    mov     bx, disk_buffer
    mov     ax, [save_ds]
    push    ax
    mov     es, ax
    mov     ax, [es:bp + FCB_RESERVED + 2]
    pop     bx
    push    cs
    pop     es
    mov     bx, disk_buffer
    call    fat_write_sector
    jc      .error_22
    mov     es, [save_ds]

.have_cluster_22:
    ; Walk cluster chain
    mov     cx, [.wr22_cluster_idx]
    test    cx, cx
    jz      .at_cluster_22

.walk_22:
    push    cx
    push    ax
    call    fat_get_next_cluster
    cmp     ax, 0x0FF8
    jae     .need_extend_22
    mov     bx, ax
    pop     ax
    mov     ax, bx
    pop     cx
    dec     cx
    jnz     .walk_22
    jmp     .at_cluster_22

.need_extend_22:
    pop     ax
    pop     cx
    push    ax
    call    fat_alloc_cluster
    jc      .disk_full_22_pop
    mov     bx, ax
    pop     ax
    push    bx
    mov     dx, bx
    call    fat_set_cluster
    pop     ax
    push    ax
    mov     dx, 0x0FFF
    call    fat_set_cluster
    pop     ax
    dec     cx
    jnz     .walk_22

.at_cluster_22:
    mov     [.wr22_cur_cluster], ax

    ; Read sector
    push    cs
    pop     es
    mov     bx, disk_buffer
    call    fat_cluster_to_lba
    push    ax
    call    fat_read_sector
    pop     ax
    jc      .error_22

    ; Calculate offset within sector
    mov     bx, [.wr22_offset]
    and     bx, 0x01FF

    ; Copy from DTA to disk_buffer
    mov     es, [save_ds]
    mov     cx, [es:bp + FCB_REC_SIZE]
    mov     si, [current_dta_off]
    push    ds
    mov     ds, [current_dta_seg]
    push    cs
    pop     es
    mov     di, disk_buffer
    add     di, bx
    rep     movsb
    pop     ds

    ; Write sector back
    push    cs
    pop     es
    mov     bx, disk_buffer
    mov     ax, [.wr22_cur_cluster]
    call    fat_cluster_to_lba
    call    fat_write_sector
    jc      .error_22

    ; Update file size if needed
    mov     ax, [.wr22_offset]
    mov     dx, [.wr22_offset + 2]
    mov     es, [save_ds]
    mov     cx, [es:bp + FCB_REC_SIZE]
    add     ax, cx
    adc     dx, 0

    cmp     dx, [es:bp + FCB_FILE_SIZE + 2]
    jb      .done_22
    ja      .update_size_22
    cmp     ax, [es:bp + FCB_FILE_SIZE]
    jbe     .done_22

.update_size_22:
    mov     [es:bp + FCB_FILE_SIZE], ax
    mov     [es:bp + FCB_FILE_SIZE + 2], dx

    ; Update directory entry
    push    ax
    push    dx
    push    cs
    pop     es
    mov     bx, disk_buffer
    push    ax
    mov     ax, [save_ds]
    mov     es, ax
    mov     ax, [es:bp + FCB_RESERVED + 2]
    push    cs
    pop     es
    call    fat_read_sector
    pop     ax
    jc      .error_22_pop2

    mov     es, [save_ds]
    mov     di, [es:bp + FCB_RESERVED + 4]
    push    cs
    pop     es
    shl     di, 5
    add     di, disk_buffer
    pop     dx
    pop     ax
    mov     [di + 28], ax
    mov     [di + 30], dx
    mov     es, [save_ds]
    mov     ax, [es:bp + FCB_RESERVED]
    push    cs
    pop     es
    mov     [di + 26], ax

    mov     bx, disk_buffer
    mov     es, [save_ds]
    mov     ax, [es:bp + FCB_RESERVED + 2]
    push    cs
    pop     es
    call    fat_write_sector
    jc      .error_22

.done_22:
    mov     byte [save_ax], 0
    pop     bp
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    ret

.error_22_pop2:
    add     sp, 4
.error_22_pop:
    add     sp, 2
.error_22:
    mov     byte [save_ax], 2
    pop     bp
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    ret

.disk_full_22_pop:
    add     sp, 4
.disk_full_22:
    mov     byte [save_ax], 1
    pop     bp
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    ret

; Local data for FCB Random Write
.wr22_offset        dd  0
.wr22_cluster_idx   dw  0
.wr22_cur_cluster   dw  0

; ---------------------------------------------------------------------------
; int21_23 - FCB Get File Size
; Input: DS:DX = FCB pointer
; Output: AL = 00h if successful, FFh if file not found
;         FCB random record field set to number of records
; ---------------------------------------------------------------------------
int21_23:
    push    es
    push    si
    push    di
    push    bx
    push    cx
    push    dx

    ; Get FCB pointer
    mov     es, [save_ds]
    mov     di, [save_dx]           ; ES:DI = FCB

    ; Copy FCB filename (bytes 1-11) to fcb_name_buffer
    push    di
    add     di, FCB_FILENAME
    mov     si, fcb_name_buffer
    mov     cx, 11
.copy_name_23:
    mov     al, [es:di]
    mov     [si], al
    inc     di
    inc     si
    loop    .copy_name_23
    pop     di

    ; Search for file in root directory
    mov     si, fcb_name_buffer
    call    fat_find_in_root
    jc      .not_found_23

    ; Found: dir entry in disk_buffer at offset returned in DI
    ; Get file size from directory entry (offset 28, 4 bytes)
    mov     ax, [di + 28]           ; File size low word
    mov     dx, [di + 30]           ; File size high word

    ; Get FCB pointer again
    mov     es, [save_ds]
    mov     di, [save_dx]

    ; Get record size from FCB
    mov     bx, [es:di + FCB_REC_SIZE]
    test    bx, bx
    jz      .use_default_rec_size
    jmp     .have_rec_size
.use_default_rec_size:
    mov     bx, 128                 ; Default record size
    mov     [es:di + FCB_REC_SIZE], bx
.have_rec_size:

    ; Calculate number of records: (file_size + record_size - 1) / record_size
    ; This gives ceiling division
    add     ax, bx
    adc     dx, 0
    sub     ax, 1
    sbb     dx, 0

    ; Now divide DX:AX by BX
    ; If DX >= BX, we'd overflow. Handle simply for small files.
    push    ax
    mov     ax, dx
    xor     dx, dx
    div     bx                      ; AX = high word of result
    mov     cx, ax                  ; Save high word
    pop     ax
    div     bx                      ; AX = low word of result
    ; CX:AX = number of records

    ; Store in FCB random record field (4 bytes at offset 21h)
    mov     [es:di + FCB_RAND_REC], ax
    mov     [es:di + FCB_RAND_REC + 2], cx

    ; Return success
    mov     byte [save_ax], 0

    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    ret

.not_found_23:
    mov     byte [save_ax], 0xFF
    pop     dx
    pop     cx
    pop     bx
    pop     di
    pop     si
    pop     es
    ret
