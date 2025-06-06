BITS 16
ORG 0x7C00

start:
    mov ax, 3
    int 0x10           ; Limpa a tela e define modo de vídeo texto
    finit              ; Inicializa a FPU

menu:
    mov si, menu_msg
    call print
    call getkey
    mov [op], al
    call printc        ; Ecoa a tecla pressionada
    
    cmp byte [op], '1'
    je op_add
    cmp byte [op], '2'
    je op_sub
    cmp byte [op], '3'
    je op_mul
    cmp byte [op], '4'
    je op_div
    jmp menu           ; Se não for opção válida, volta ao menu

op_add:
    call getnums
    faddp st1, st0     ; st1 = st1 + st0, pop st0
    jmp showres

op_sub:
    call getnums
    fsubp st1, st0     ; st1 = st1 - st0, pop st0
    jmp showres

op_mul:
    call getnums
    fmulp st1, st0     ; st1 = st1 * st0, pop st0
    jmp showres

op_div:
    call getnums
    ftst               ; Testa se st0 (divisor) é zero
    fstsw ax
    sahf
    je div_err
    fdivrp st1, st0    ; st1 = st1 / st0, pop st0 (num1 / num2)
    jmp showres

div_err:
    mov si, err_msg
    call print
    call waitkey
    jmp start

getnums:
    mov si, num1_msg
    call print
    call getnum        ; Lê primeiro número para st0
    fstp qword [num1]  ; Armazena na memória e remove da FPU
    
    mov si, num2_msg
    call print
    call getnum        ; Lê segundo número para st0
    fstp qword [num2]  ; Armazena na memória e remove da FPU
    
    ; Carrega os números na ordem correta para as operações:
    ; st0 = num2 (segundo número digitado)
    ; st1 = num1 (primeiro número digitado)
    fld qword [num2]   ; st0 = num2
    fld qword [num1]   ; st0 = num1, st1 = num2
    ret

showres:
    mov si, res_msg
    call print
    
    ; Formata o resultado com 2 casas decimais
    fld st0            ; Duplica o resultado para manipulação
    
    ; Extrai parte inteira
    frndint            ; Arredonda para inteiro
    fistp word [intp]  ; Armazena parte inteira
    
    ; Extrai parte decimal (resultado - parte inteira)
    fld st0            ; Duplica resultado original novamente
    fild word [intp]   ; Carrega parte inteira
    fsubp st1, st0     ; st0 = parte decimal
    
    ; Multiplica por 100 para obter 2 dígitos decimais
    fimul word [hundred]
    frndint            ; Arredonda para inteiro
    fistp word [decp]  ; Armazena parte decimal (0-99)
    
    ; Mostra parte inteira
    mov ax, [intp]
    call showint
    
    ; Mostra ponto decimal
    mov al, '.'
    call printc
    
    ; Mostra parte decimal (sempre 2 dígitos)
    mov ax, [decp]
    cmp ax, 10
    jge .twodigits
    push ax
    mov al, '0'        ; Adiciona zero à esquerda se necessário
    call printc
    pop ax
.twodigits:
    call showuint
    
    fstp st0           ; Remove o resultado original da FPU
    call waitkey
    jmp start

showint:
    test ax, ax
    jns showuint       ; Se positivo, mostra como unsigned
    push ax
    mov al, '-'        ; Mostra sinal negativo
    call printc
    pop ax
    neg ax             ; Converte para positivo

showuint:
    xor cx, cx         ; Contador de dígitos
    mov bx, 10
.loop:
    xor dx, dx
    div bx             ; Divide AX por 10
    push dx            ; Resto (dígito) na pilha
    inc cx
    test ax, ax
    jnz .loop          ; Continua até AX = 0
.print:
    pop dx
    add dl, '0'        ; Converte para ASCII
    mov al, dl
    call printc
    loop .print
    ret

print:
    lodsb              ; Carrega byte de [SI] em AL, incrementa SI
    test al, al
    jz .done           ; Se zero, fim da string
    call printc
    jmp print
.done:
    ret

printc:
    mov ah, 0x0E       ; Função BIOS para imprimir caractere
    xor bx, bx         ; Página 0
    int 0x10
    ret

getkey:
    xor ah, ah
    int 0x16           ; Espera por tecla
    ret

waitkey:
    call getkey
    cmp al, 13         ; Enter
    jne .done
    call printc        ; Ecoa o Enter se pressionado
.done:
    ret

getnum:
    fldz               ; Carrega zero (acumulador)
    mov byte [negflag], 0
    mov word [decimal_places], 0
    
.read:
    call getkey
    cmp al, 13         ; Enter - finaliza
    je .done
    cmp al, '-'        ; Sinal negativo
    je .neg
    cmp al, '.'        ; Ponto decimal
    je .dec
    cmp al, '0'
    jb .read           ; Ignora caracteres inválidos
    cmp al, '9'
    ja .read
    
    call printc        ; Ecoa o dígito
    sub al, '0'        ; Converte para valor numérico
    mov [digit], al
    
    cmp word [decimal_places], 0
    jne .decimal_part  ; Se já está na parte decimal
    
    ; Parte inteira: acumulador = acumulador * 10 + dígito
    fimul word [ten]
    fiadd word [digit]
    jmp .read

.decimal_part:
    ; Parte decimal: acumulador += dígito / (10^decimal_places)
    mov cx, [decimal_places]
    mov ax, 1
    mov bx, 10
.calc_divisor:
    mul bx             ; AX = AX * 10
    loop .calc_divisor
    
    fild word [digit]
    mov [temp], ax
    fidiv word [temp]  ; st0 = dígito / divisor
    faddp st1, st0     ; Adiciona ao acumulador
    inc word [decimal_places] ; Incrementa contador de casas decimais
    jmp .read

.neg:
    call printc
    not byte [negflag] ; Alterna flag de negativo
    jmp .read

.dec:
    call printc
    mov word [decimal_places], 1 ; Inicia contagem de casas decimais
    jmp .read

.done:
    cmp byte [negflag], 0
    je .pos
    fchs               ; Aplica sinal negativo se necessário
.pos:
    ret

; Constantes
ten dw 10
hundred dw 100

; Variáveis
digit dw 0
negflag db 0
decimal_places dw 0
temp dw 0
intp dw 0
decp dw 0
num1 dq 0.0
num2 dq 0.0
op db 0

; Mensagens
menu_msg db 13,10,"1-Add",13,10,"2-Sub",13,10,"3-Mul",13,10,"4-Div",13,10,">",0
num1_msg db 13,10,"N1:",0
num2_msg db 13,10,"N2:",0
res_msg db 13,10,"=",0
err_msg db 13,10,"Err: Div/0",0

times 510-($-$$) db 0
dw 0xAA55