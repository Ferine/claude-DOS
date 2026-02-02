; ===========================================================================
; claudeDOS .EXE (MZ format) Program Loader
; ===========================================================================

; ---------------------------------------------------------------------------
; load_exe - Load an .EXE program into memory
; Input: DS:SI = 11-byte FCB filename
;        AX = load segment (segment after PSP, i.e. PSP+10h)
; Output: CF clear on success
;         exec_init_cs/ip/ss/sp filled in
;         CF set on error, AX = error code
; ---------------------------------------------------------------------------
load_exe:
    push    bx
    push    cx
    push    dx
    push    es
    push    di
    push    bp

    mov     [.load_seg], ax

    ; Find file in root directory
    call    fat_find_in_root
    jc      .not_found

    ; DI = directory entry in disk_buffer
    ; Get file size
    mov     ax, [di + 28]           ; File size low
    mov     dx, [di + 30]           ; File size high
    mov     [.total_size], ax
    mov     [.total_size + 2], dx

    ; Get starting cluster
    mov     ax, [di + 26]
    mov     [.start_cluster], ax

    ; Read first sector (MZ header) into disk_buffer
    push    cs
    pop     es
    mov     bx, disk_buffer
    mov     ax, [.start_cluster]
    call    fat_cluster_to_lba
    call    fat_read_sector
    jc      .read_error

    ; Validate MZ signature
    cmp     word [disk_buffer], 0x5A4D  ; 'MZ'
    jne     .bad_format

    ; Parse header fields
    mov     ax, [disk_buffer + MZ_HEADER_SIZE]
    mov     [.header_paras], ax

    mov     ax, [disk_buffer + MZ_PAGE_COUNT]
    mov     [.page_count], ax

    mov     ax, [disk_buffer + MZ_LAST_PAGE_SIZE]
    mov     [.last_page_bytes], ax

    mov     ax, [disk_buffer + MZ_RELOC_COUNT]
    mov     [.reloc_count], ax

    mov     ax, [disk_buffer + MZ_RELOC_OFFSET]
    mov     [.reloc_offset], ax

    mov     ax, [disk_buffer + MZ_INIT_SS]
    mov     [.init_ss], ax

    mov     ax, [disk_buffer + MZ_INIT_SP]
    mov     [.init_sp], ax

    mov     ax, [disk_buffer + MZ_INIT_CS]
    mov     [.init_cs], ax

    mov     ax, [disk_buffer + MZ_INIT_IP]
    mov     [.init_ip], ax

    ; Calculate header size in bytes = header_paras * 16
    mov     ax, [.header_paras]
    mov     cl, 4
    shl     ax, cl                  ; AX = header bytes
    mov     [.header_bytes], ax

    ; Calculate how many full sectors to skip and offset in first image sector
    ; skip_sectors = header_bytes / 512
    ; header_offset = header_bytes % 512 (offset into first image sector)
    mov     ax, [.header_bytes]
    xor     dx, dx
    mov     cx, 512
    div     cx                      ; AX = full sectors, DX = offset
    mov     [.skip_sectors], ax
    mov     [.header_offset], dx

    ; Calculate load image size from MZ header (NOT file size!)
    ; if last_page_bytes == 0: total = page_count * 512
    ; else: total = (page_count - 1) * 512 + last_page_bytes
    ; Then subtract header_bytes to get actual load size
    mov     ax, [.page_count]
    cmp     word [.last_page_bytes], 0
    je      .full_page_calc
    dec     ax                      ; (page_count - 1)
.full_page_calc:
    mov     cl, 9
    shl     ax, cl                  ; AX = pages * 512
    cmp     word [.last_page_bytes], 0
    je      .no_last_page_add
    add     ax, [.last_page_bytes]
.no_last_page_add:
    ; AX = total EXE image size in bytes (including header)
    sub     ax, [.header_bytes]     ; Subtract header to get load image size
    mov     [.bytes_to_load], ax
    mov     word [.bytes_loaded], 0 ; Initialize bytes loaded counter

    ; Load the file cluster by cluster
    ; - Skip .skip_sectors worth of sectors entirely
    ; - On the first sector after skip, start copying from .header_offset
    ; - Then copy full sectors thereafter

    mov     ax, [.start_cluster]
    mov     es, [.load_seg]
    xor     bx, bx                  ; Dest offset in load segment
    mov     [.old_bx], bx           ; Initialize wrap detection
    xor     dx, dx                  ; Sector counter
    mov     byte [.first_data_sector], 1  ; Flag: next non-skipped sector is first

.load_loop:
    cmp     ax, 0x0FF8
    jae     .load_done

    ; Check if we've already loaded enough data
    mov     cx, [.bytes_loaded]
    cmp     cx, [.bytes_to_load]
    jae     .load_done              ; Stop when we've loaded the required amount

    push    ax                      ; Save cluster number

    ; Read this cluster's sector into disk_buffer (kernel temp area)
    push    es
    push    bx
    push    cs
    pop     es
    mov     bx, disk_buffer
    call    fat_cluster_to_lba
    call    fat_read_sector
    pop     bx
    pop     es
    jc      .read_error_pop

    ; Should we skip this sector?
    cmp     dx, [.skip_sectors]
    jb      .skip_this_sector

    ; Copy data from disk_buffer to ES:BX
    push    si
    push    di
    push    cx
    push    dx

    mov     si, disk_buffer
    mov     di, bx                  ; ES:DI = destination
    mov     cx, 512                 ; Bytes to copy

    ; Is this the first data sector?
    cmp     byte [.first_data_sector], 1
    jne     .copy_full_sector

    ; First data sector: start from header_offset
    mov     byte [.first_data_sector], 0
    add     si, [.header_offset]
    sub     cx, [.header_offset]    ; Copy fewer bytes

.copy_full_sector:
    ; Save bytes to copy for tracking
    mov     [.last_copy_size], cx
    ; Save old BX to detect wrap
    mov     [.old_bx], bx

    ; Check if copy would cross segment boundary
    ; Calculate bytes until segment end: 0x10000 - DI
    ; If DI = 0, result is 0 but we have full 64KB (won't wrap with 512-byte copy)
    push    ax
    mov     ax, 0
    sub     ax, di                  ; AX = 0 - DI = bytes until wrap (or 0 if DI=0)
    jz      .no_split_cleanup       ; DI=0 means full segment available, no wrap possible

    ; If CX > bytes_until_wrap, we need to split the copy
    cmp     cx, ax
    jbe     .no_split_cleanup       ; CX <= bytes to boundary, no split needed

    ; Split copy: first copy bytes until boundary, then advance segment
    push    cx                      ; Save total bytes
    mov     cx, ax                  ; Copy only until boundary

    push    ds
    push    cs
    pop     ds
    rep     movsb                   ; First part: fill to end of segment
    pop     ds

    ; DI is now 0 (wrapped), advance ES
    mov     ax, es
    add     ax, 0x1000
    mov     es, ax
    xor     di, di                  ; DI = 0 (should already be 0 from wrap)

    pop     cx                      ; Restore total
    pop     ax                      ; Restore bytes_until_wrap
    sub     cx, ax                  ; Remaining bytes to copy

    ; Copy remaining bytes to new segment
    push    ds
    push    cs
    pop     ds
    rep     movsb
    pop     ds

    ; After split, update destination and skip the wrap check
    ; (we already advanced ES during the split)
    mov     bx, di
    ; Track bytes loaded
    mov     ax, [.last_copy_size]
    add     [.bytes_loaded], ax
    pop     dx
    pop     cx
    pop     di
    pop     si
    jmp     .sector_done

.no_split_cleanup:
    pop     ax                      ; Clean up AX from bytes_until_wrap calc

    ; Normal copy (no boundary crossing)
    push    ds
    push    cs
    pop     ds
    rep     movsb
    pop     ds

.copy_done:
    ; Update destination pointer
    mov     bx, di

    ; Track bytes loaded (CX was bytes copied, but it's 0 after rep movsb)
    ; We need to calculate from the difference in DI
    ; Actually, we saved CX earlier - use [.last_copy_size]
    mov     ax, [.last_copy_size]
    add     [.bytes_loaded], ax

    pop     dx
    pop     cx
    pop     di
    pop     si

    ; Check for segment overflow: if new BX < old BX, we wrapped
    ; (This handles the case where we advanced ES mid-copy)
    cmp     bx, [.old_bx]
    jae     .no_wrap

    ; BX wrapped - advance ES by 0x1000 (64KB)
    ; This case now only triggers if we didn't already advance during split
    push    ax
    mov     ax, es
    add     ax, 0x1000
    mov     es, ax
    pop     ax

.no_wrap:
    jmp     .sector_done

.skip_this_sector:
    ; Just skip, don't copy

.sector_done:
    inc     dx                      ; Sector count

    pop     ax                      ; Restore cluster number
    call    fat_get_next_cluster
    jmp     .load_loop

.read_error_pop:
    pop     ax
    jmp     .read_error

.load_done:
    ; Apply relocations
    mov     cx, [.reloc_count]
    test    cx, cx
    jz      .no_relocs

    ; Calculate which sector contains the relocation table
    ; reloc_offset could be > 512, so we may need to skip sectors
    mov     ax, [.reloc_offset]
    xor     dx, dx
    mov     bx, 512
    div     bx                      ; AX = sector offset, DX = byte offset within sector
    mov     [.reloc_sector_off], ax ; Sectors to skip from file start
    mov     [.reloc_byte_off], dx   ; Offset within that sector

    ; Walk cluster chain to find the sector containing relocations
    mov     ax, [.start_cluster]
    mov     bx, [.reloc_sector_off]
    test    bx, bx
    jz      .reloc_read_sector

.reloc_skip_cluster:
    push    bx
    call    fat_get_next_cluster
    pop     bx
    cmp     ax, 0x0FF8
    jae     .read_error             ; Unexpected EOF
    dec     bx
    jnz     .reloc_skip_cluster

.reloc_read_sector:
    mov     [.reloc_cur_cluster], ax

    ; Read this sector into disk_buffer
    push    cs
    pop     es
    push    cx                      ; Save reloc_count
    mov     bx, disk_buffer
    call    fat_cluster_to_lba
    call    fat_read_sector
    pop     cx
    jc      .read_error

    ; Set up SI to point to first relocation in buffer
    mov     si, disk_buffer
    add     si, [.reloc_byte_off]

.reloc_loop:
    test    cx, cx
    jz      .no_relocs

    ; Check if SI needs to advance to next sector
    cmp     si, disk_buffer + 512
    jb      .reloc_process_entry

    ; Need to read next sector - advance cluster
    push    cx
    mov     ax, [.reloc_cur_cluster]
    call    fat_get_next_cluster
    cmp     ax, 0x0FF8
    jae     .reloc_eof_pop          ; Unexpected EOF
    mov     [.reloc_cur_cluster], ax

    ; Read next sector
    push    cs
    pop     es
    mov     bx, disk_buffer
    call    fat_cluster_to_lba
    call    fat_read_sector
    pop     cx
    jc      .read_error

    mov     si, disk_buffer         ; Reset to start of buffer

.reloc_process_entry:
    ; Read relocation entry: offset (word), segment (word)
    mov     di, [si]                ; Offset
    mov     ax, [si + 2]            ; Segment (relative)

    ; Bounds check: verify relocation target is within loaded image
    ; Compute absolute segment: load_seg + reloc_seg
    add     ax, [.load_seg]

    ; Check segment is within loaded image bounds
    ; End segment = load_seg + (bytes_loaded >> 4) + 1
    push    dx
    mov     dx, [.bytes_loaded]
    shr     dx, 4                   ; Convert bytes to paragraphs
    add     dx, [.load_seg]
    inc     dx                      ; One past the end
    cmp     ax, [.load_seg]
    jb      .reloc_skip_invalid     ; Before start of image
    cmp     ax, dx
    jae     .reloc_skip_invalid     ; Past end of image
    pop     dx

    ; Also verify offset doesn't go past segment end (need room for word)
    cmp     di, 0xFFFE
    ja      .reloc_skip_entry       ; Offset too large for word fixup

    ; Fix up the word at that address
    push    es
    push    bx
    mov     es, ax
    mov     bx, [.load_seg]
    add     [es:di], bx             ; Add load_seg to the word there
    pop     bx
    pop     es

.reloc_next_entry:
    add     si, 4                   ; Next relocation entry
    dec     cx
    jmp     .reloc_loop

.reloc_skip_invalid:
    pop     dx                      ; Clean up from bounds check
.reloc_skip_entry:
    jmp     .reloc_next_entry       ; Skip this malformed entry

.reloc_eof_pop:
    pop     cx                      ; Clean up stack
    ; Fall through to no_relocs - partial relocation is better than crashing

.no_relocs:
    ; Set up return values
    mov     ax, [.init_cs]
    add     ax, [.load_seg]
    mov     [exec_init_cs], ax

    mov     ax, [.init_ip]
    mov     [exec_init_ip], ax

    mov     ax, [.init_ss]
    add     ax, [.load_seg]
    mov     [exec_init_ss], ax

    mov     ax, [.init_sp]
    mov     [exec_init_sp], ax

    clc
    pop     bp
    pop     di
    pop     es
    pop     dx
    pop     cx
    pop     bx
    ret

.not_found:
    mov     ax, ERR_FILE_NOT_FOUND
    stc
    pop     bp
    pop     di
    pop     es
    pop     dx
    pop     cx
    pop     bx
    ret

.bad_format:
    mov     ax, ERR_INVALID_FORMAT
    stc
    pop     bp
    pop     di
    pop     es
    pop     dx
    pop     cx
    pop     bx
    ret

.read_error:
    mov     ax, ERR_READ_FAULT
    stc
    pop     bp
    pop     di
    pop     es
    pop     dx
    pop     cx
    pop     bx
    ret

; Local workspace
.load_seg          dw  0
.total_size        dd  0
.start_cluster     dw  0
.old_bx            dw  0           ; For segment wrap detection
.header_paras      dw  0
.header_bytes      dw  0
.page_count        dw  0
.last_page_bytes   dw  0
.bytes_to_load     dw  0           ; Total bytes to load (from MZ header)
.bytes_loaded      dw  0           ; Bytes loaded so far
.last_copy_size    dw  0           ; Bytes copied in last operation
.reloc_count       dw  0
.reloc_offset      dw  0
.skip_sectors      dw  0
.header_offset     dw  0
.first_data_sector db  0
.init_ss           dw  0
.init_sp           dw  0
.init_cs           dw  0
.init_ip           dw  0
.reloc_sector_off  dw  0           ; Sectors to skip to reach reloc table
.reloc_byte_off    dw  0           ; Byte offset within reloc sector
.reloc_cur_cluster dw  0           ; Current cluster for reloc reading

; MZ Header offsets
MZ_SIGNATURE       equ     0x00    ; 'MZ' signature
MZ_LAST_PAGE_SIZE  equ     0x02    ; Bytes on last page
MZ_PAGE_COUNT      equ     0x04    ; Pages in file (512-byte pages)
MZ_RELOC_COUNT     equ     0x06    ; Relocation entries
MZ_HEADER_SIZE     equ     0x08    ; Header size in paragraphs
MZ_MIN_ALLOC       equ     0x0A    ; Minimum extra paragraphs
MZ_MAX_ALLOC       equ     0x0C    ; Maximum extra paragraphs
MZ_INIT_SS         equ     0x0E    ; Initial SS (relative)
MZ_INIT_SP         equ     0x10    ; Initial SP
MZ_CHECKSUM        equ     0x12    ; Checksum
MZ_INIT_IP         equ     0x14    ; Initial IP
MZ_INIT_CS         equ     0x16    ; Initial CS (relative)
MZ_RELOC_OFFSET    equ     0x18    ; Offset to relocation table
MZ_OVERLAY         equ     0x1A    ; Overlay number
