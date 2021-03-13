format ELF
public _IAprintf
public _IAprintf_flush

;===========================================
section ".IAprintf_data" writeable
_IA_printf_for_format    db '0123456789ABCDEF'
_IA_printf_flush_buf_cap equ 1024
_IA_printf_temp_buf_cap  equ 10

section ".IAprtintf_switch_table" writeable
_IA_printf_switch_table:
	times 2  dd _IA_printf_bin
			 dd _IA_printf_sym
	times 11 dd _IA_printf_dec
	times 4  dd _IA_printf_oct
	times 5  dd _IA_printf_str
	times 3  dd _IA_printf_hex

section ".IAprintf_buffers" writeable 
_IA_printf_flush_buf 		rb _IA_printf_flush_buf_cap
_IA_printf_temp_buf         rb _IA_printf_temp_buf_cap

_IA_printf_flush_buf_size 	dw 0
_IA_printf_temp_buf_size    db 0
;===========================================

;-------------------------------------------
;Flush printf bufer
;-------------------------------------------
section ".IAprintf_flush" executable
_IAprintf_flush:
		call _IA_printf_flush
		ret

;-------------------------------------------
;Format print function, cdecl
;-------------------------------------------
section ".IAprintf" executable
_IAprintf:
		push eax esi ebx edx ecx

		mov  esi, [esp+4+5*4]

		mov  ecx, 4 + (4+5*4)
		add  ecx, esp

		xor  ebx, ebx
		_IAprintf_loop:
			_IAprintf_null_byte:
				cmp  [esi+ebx], byte 0
				je   _IAprintf_loop_break

			_IAprintf_not_special:
				cmp  [esi+ebx], byte '%'
				je   _IAprintf_special

				mov  al, [esi+ebx]
				inc  ebx
				call _IA_printf_add_buf

				jmp  _IAprintf_loop

			_IAprintf_special:
				inc  ebx

				_IA_printf_procent:
					cmp  [esi+ebx], byte '%'
					jne  _IA_printf_other

					mov  al, [esi+ebx]
					inc  ebx
					call _IA_printf_add_buf

					jmp  _IAprintf_loop

				_IA_printf_other:
					xor  edx, edx
					mov  byte dl, [esi+ebx]

					sub  edx, 'a'
					mov  dword edx, [edx*4+_IA_printf_switch_table]

					call edx
					add  ecx, 4

					inc  ebx
					jmp  _IAprintf_loop

		_IAprintf_loop_break:
		pop  ecx edx ebx esi eax
		ret

;-------------------------------------------
;Flush printf bufer
;-------------------------------------------
section ".IA_printf_flush" executable
_IA_printf_flush:
		push eax ebx ecx edx

		mov  ecx, _IA_printf_flush_buf
		mov  eax, 4
		mov  ebx, 1
		xor  edx, edx
		mov  dx,  [_IA_printf_flush_buf_size]
		mov  [_IA_printf_flush_buf_size], word 0
		int  0x80

		pop  edx ecx ebx eax
		ret

;-------------------------------------------
;Add byte to printf bufer
;
;al - add byte
;-------------------------------------------
section ".IA_printf_add_buf" executable
_IA_printf_add_buf:
		push edx
		mov  edx, _IA_printf_flush_buf_cap

		sub  word dx, [_IA_printf_flush_buf_size]

		_IA_printf_need_flush:
			cmp  edx, 0
			jne  _IA_printf_add_buf_byte
			call _IA_printf_flush

		_IA_printf_add_buf_byte:

		push ebx
		xor  ebx, ebx
		mov  word bx, [_IA_printf_flush_buf_size]
		add  ebx, _IA_printf_flush_buf

		mov [ebx], al
		add [_IA_printf_flush_buf_size], 1

		pop  ebx edx
		ret

;-------------------------------------------
;Realisation function, for format output, add byte to temp buf
;
;al - add byte
;-------------------------------------------
section ".IA_printf_add_temp_buf" executable
_IA_printf_add_temp_buf:
		push ebx
		xor  ebx, ebx
		mov  byte bl, [_IA_printf_temp_buf_size]
		mov [_IA_printf_temp_buf+ebx], al
		add [_IA_printf_temp_buf_size], 1

		pop  ebx
		ret 

;-------------------------------------------
;Write temp bufer to printf bufer
;-------------------------------------------
section ".IA_printf_write_temp_buf" executable
_IA_printf_write_temp_buf:
		push ebx eax
		xor  ebx, ebx

		_IA_printf_write_temp_buf_loop:
			cmp  bl, [_IA_printf_temp_buf_size]
			je   _IA_printf_write_temp_buf_break
			mov  byte al, [_IA_printf_temp_buf+ebx]
			call _IA_printf_add_buf
			inc  bl
			jmp  _IA_printf_write_temp_buf_loop

		_IA_printf_write_temp_buf_break:
		pop  eax ebx

		mov  [_IA_printf_temp_buf_size], byte 0
		ret

;-------------------------------------------
;Reverse temp bufer
;-------------------------------------------
section ".IA_printf_reverse_temp_buf" executable
_IA_printf_reverse_temp_buf:
		push ebx eax edx ecx
		xor  eax, eax
		xor  ebx, ebx
		mov  byte bl, [_IA_printf_temp_buf_size]
		dec  bl

        _IA_printf_reverse_temp_buf_loop:
        	cmp  bl, al
        	jb   _IA_printf_reverse_temp_buf_break

        	mov  dl, [_IA_printf_temp_buf+eax]
        	mov  cl, [_IA_printf_temp_buf+ebx]
        	xchg cl, dl

        	mov  [_IA_printf_temp_buf+eax], dl
        	mov  [_IA_printf_temp_buf+ebx], cl

        	dec  bl
        	inc  al
        	jmp  _IA_printf_reverse_temp_buf_loop

        _IA_printf_reverse_temp_buf_break:
        	pop  ecx edx eax ebx
        	ret

;-------------------------------------------
;Write bytes to temp bufer, for digits %o %x %b
;
;bl - base
;-------------------------------------------
section ".IA_printf_format_ndec" executable
_IA_printf_format_ndec:
		push ecx eax ebx edx

		mov  dword eax, [ecx]
		mov  cl, bl

		_IA_printf_format_ndec_loop:
			mov  ebx, 1
			shl  ebx, cl
			dec  ebx

			mov  edx, eax
			and  edx, ebx

			push eax
			mov  al, [_IA_printf_for_format+edx]
			call _IA_printf_add_temp_buf
			pop  eax

			shr  eax, cl
			cmp  eax, 0
			je   _IA_printf_format_ndec_break
			jmp  _IA_printf_format_ndec_loop

		_IA_printf_format_ndec_break:

		pop  edx ebx eax ecx

		call _IA_printf_reverse_temp_buf
		call _IA_printf_write_temp_buf
		ret 

;-------------------------------------------
;Printf %b
;-------------------------------------------
section ".IA_printf_bin" executable
_IA_printf_bin:
		push ebx

		mov  bl, 1
		call _IA_printf_format_ndec

		pop  ebx
		ret

;-------------------------------------------
;Printf %c
;-------------------------------------------
section ".IA_printf_sym" executable
_IA_printf_sym:
		push eax

		mov  al, [ecx]
		call _IA_printf_add_buf

		pop  eax
		ret

;-------------------------------------------
;Printf %d
;-------------------------------------------
section ".IA_printf_dec" executable
_IA_printf_dec:
		push edx ebx eax
		mov  ebx, 10
		mov  dword eax, [ecx]
		
		xor  edx, edx

		push ebx
		mov  ebx, 1
		shl  ebx, 31
		and  eax, ebx
		pop  ebx

		_IA_printf_dec_minus:
			cmp  eax, 0
			je   _IA_printf_dec_digit
			mov  al, '-'
			call _IA_printf_add_buf

			mov  dword eax, [ecx]
			push ebx
			mov  ebx, -1
			imul ebx
			pop  ebx

			jmp  _IA_printf_dec_loop

		_IA_printf_dec_digit:
		mov  dword eax, [ecx] 

		_IA_printf_dec_loop:
			push edx
			xor  edx, edx
			div  ebx

			push eax
			mov  al, dl
			add  al, '0'
			call _IA_printf_add_temp_buf
			pop  eax edx

			inc  edx
			cmp  eax, 0
			je  _IA_printf_dec_break
			jmp _IA_printf_dec_loop

		_IA_printf_dec_break:

		call _IA_printf_reverse_temp_buf
		call _IA_printf_write_temp_buf

		pop  eax ebx edx
		ret 

;-------------------------------------------
;Printf %o
;-------------------------------------------
section ".IA_print_oct" executable
_IA_printf_oct:
		push ebx

		mov  bl, 3
		call _IA_printf_format_ndec

		pop  ebx
		ret

;-------------------------------------------
;Printf %s
;-------------------------------------------
section ".IA_printf_str" executable
_IA_printf_str:
		push ecx eax
		mov  ecx, [ecx]

		_IA_printf_str_loop:
			cmp  [ecx], byte 0
			je   _IA_printf_str_break

			mov  al, [ecx]
			call _IA_printf_add_buf

			inc  ecx
			jmp  _IA_printf_str_loop

		_IA_printf_str_break:
		pop  eax ecx
		ret

;-------------------------------------------
;Printf %x
;-------------------------------------------
section ".IA_printf_hex" executable
_IA_printf_hex:
		push ebx

		mov  bl, 4
		call _IA_printf_format_ndec

		pop  ebx
		ret

