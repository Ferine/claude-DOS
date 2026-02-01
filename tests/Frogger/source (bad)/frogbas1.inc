.INCLUDE graph1.inc
.INCLUDE frogsys1.inc

.TYPE  ( FilaPantalla = 200     , ColumnaPantalla=320
         ByteColor    = 1       )

.TYPE  ( RectanguloLongInt      =   20, PosicionX0RL            =    4
         PosicionY0RL           =    8, PosicionX1RL            =   12
         PosicionY1RL           =   16  )

.TYPE  ( BitImageTransparente   =    1, BitImageAnd             =    2
         BitImageOr             =    4, BitImageXor             =    8
         TotalInversoColor      =  215 )

.PUBLIC .DATA
  ColorTransparente  dd  0              ; identificador color transparente

.CODE
PROC PonerPantalla                      ; numero identificacion 023
.CODE
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, CeroLocales             ; espacio para locales
                                        ; utiliza una MatrizVariable
                                        ; para dibujar pantalla
                                        ; debe de ser de tamano y tipo
                                        ; correcto (calzar exactamente)
                                        ; ParametroA =
                                        ;       puntero a MatrizVariable
                                        ; Nota : Requiere modo grafico

      mov  edi, [ EBP+ParametroA ]      ; puntero a MatrizVariable
      add  edi, MemoriaVector           ; desplaza a datos edi = Datos
      mov  ecx, 0                       ; ecx = Xinicial
      mov  edx, 0                       ; edx = YInicial
      mov  esi, ColumnaPantalla         ; esi = SizeX
      mov  ebx, FilaPantalla            ; ebx = SizeY
      call PutImage                     ; pone la pantalla

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  UnParametro                  ; retorno liberacion de parametros
ENDP PonerPantalla

.CODE
PROC CorregirRectanguloObjetivo         ; numero identificacion 024
.CODE
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, CeroLocales             ; espacio para locales
                                        ; su objetivo es ajustar
                                        ; ParametroB^ para calzar
                                        ; con dimensiones de ParametroA^
                                        ; ParametroA =
                                        ;       puntero a pantalla
                                        ; ParametroB =
                                        ;       puntero a RectanguloLongInt
                                        ; OUT eax = Boolean si FALSE
                                        ;       rectangulo fuera de rango
                                        ;       en tal caso anula
                                        ;       internamente el registro
                                        ;       excepto el CampoBase

      mov  eax, [ EBP+ParametroB ]      ; ubica el RectanguloLongInt
      RL( PosicionX0RL )                ; lee PosicionX0RL
      cmp  eax, 1                       ; lo compara con posicion 1
      jge  IgnorarAUnitario024          ; si es mayor o igual a 1 ignora
      mov  eax, [ EBP+ParametroB ]      ; contrario corrige
      RG( PosicionX0RL, 1 )             ; asignando un 1
IgnorarAUnitario024:
      mov  eax, [ EBP+ParametroB ]      ; nuevamente el rectangulo
      RL( PosicionY0RL )                ; ahora en PosicionY0RL
      cmp  eax, 1                       ; lo compara con posicion 1
      jge  IgnorarBUnitario024          ; si es mayor o igual a 1 ignora
      mov  eax, [ EBP+ParametroB ]      ; contrario corrige
      RG( PosicionY0RL, 1 )             ; asignando un 1
IgnorarBUnitario024:
      mov  eax, [ EBP+ParametroA ]      ; lee el puntero a pantalla
      RL( TotalFilas )                  ; leyento el TotalFilas
      mov  edx, eax                     ; y coloca en edx
      mov  eax, [ EBP+ParametroB ]      ; compara con Rectangulo
      RL( PosicionX1RL )                ; en PosicionX1RL
      cmp  eax, edx                     ; si es menor o igual
      jle  IgnorarFila024               ; a TotalFilas entonces ignora
      mov  eax, [ EBP+ParametroB ]      ; guardando TotalFilas
      RG( PosicionX1RL, edx )           ; en PosicionX1RL
IgnorarFila024:
      mov  eax, [ EBP+ParametroA ]      ; ahora es el turno a
      RL( TotalColumnas )               ; ParametroA.TotalColumnas
      mov  edx, eax                     ; coloca en edx
      mov  eax, [ EBP+ParametroB ]      ; compara con Rectangulo
      RL( PosicionY1RL )                ; en PosicionY1RL
      cmp  eax, edx                     ; se verifica
      jle  IgnorarColumna024            ; menor o igual a TotalColumnas
      mov  eax, [ EBP+ParametroB ]      ; caso contrario
      RG( PosicionY1RL, edx )           ; PosicionY1RL=TotalColumnas
IgnorarColumna024:
      mov  eax, [ EBP+ParametroB ]      ; ahora lee
      RL( PosicionX1RL )                ; Rectangulo.PosicionX1RL
      mov  edx, eax                     ; colocando en edx
      mov  eax, [ EBP+ParametroB ]      ; para compararlo con
      RL( PosicionX0RL )                ; Rectangulo.PosicionX0RL
      cmp  eax, edx                     ; PosicionX0RL<=PosicionX1RL
      jg   AnularRectangulo024          ; si no cumple anula Rectangulo
      mov  eax, [ EBP+ParametroB ]      ; ahora lee
      RL( PosicionY1RL )                ; Rectangulo.PosicionY1RL
      mov  edx, eax                     ; y coloca en edx
      mov  eax, [ EBP+ParametroB ]      ; para compararlo con
      RL( PosicionY0RL )                ; Rectangulo.PosicionY0RL
      cmp  eax, edx                     ; PosicionY0RL<=PosicionY1RL
      jg   AnularRectangulo024          ; si no cumple anula Rectangulo
      mov  eax, TRUE                    ; proceso exitoso devuelve TRUE
      jmp  Final024                     ; para finalizar proceso
AnularRectangulo024:
      mov  eax, [ EBP+ParametroB ]      ; puntero a RectanguloLongInt
      push 4                            ; conserva CampoBase
      push eax                          ; coloca puntero en Stack
      call BlanquearRegistro            ; anula el Registro menos CampoBase
      mov  eax, FALSE                   ; FALSE indica mal rectangulo
Final024:

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  DosParametros                ; retorno liberacion de parametros
ENDP CorregirRectanguloObjetivo

.CODE
PROC RellenarRectanguloMatriz           ; numero identificacion 026
.CODE
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, SieteLocales            ; espacio para locales
                                        ; ParametroA =
                                        ;       puntero a MatrizVariable
                                        ; ParametroB =
                                        ;       puntero a RectanguloLongInt
                                        ; ParametroC =
                                        ;       dato o puntero a dato
                                        ;       criterio
                                        ;       ParametroA^.EspacioElemento
                                        ;       si <= 4 entonces dato
                                        ;       caso contrario puntero
                                        ; LocalA = FilaInicial
                                        ; LocalB = TotalFilas a recorrer
                                        ; LocalC = ColumnaInicial
                                        ; LocalD = TotalColumnas a recorrer
                                        ; LocalE = puntero a casilla
                                        ; LocalF = CuentaColumna
                                        ; LocalG = EspacioElemento

      push es                           ; se reubica es a ds
      xor  eax, eax                     ; utilizando ax como pivote
      mov  ax, ds                       ; y colocando es en el Stack
      mov  es, ax                       ; que se reestablecer  al final
      mov  eax, [ EBP+ParametroB ]      ; RectanguloLongInt
      push eax                          ; quese coloca en Stack
      mov  eax, [ EBP+ParametroA ]      ; MatrizVariable
      push eax                          ; tambien en Stack
      call CorregirRectanguloObjetivo   ; que se corrige a bordes
      cmp  eax, FALSE                   ; si no queda nada imprimible
      je   FinalRelleno026              ; se termina el proceso
      mov  eax, [ EBP+ParametroB ]      ; otra vez RectanguloLongInt
      RL( PosicionX0RL )                ; se lee PosicionX0RL
      mov  [ EBP+LocalA ], eax          ; que pasa a ser FilaInicial
      mov  edx, eax                     ; se coloca en edx
      mov  eax, [ EBP+ParametroB ]      ; otra vez RectanguloLongInt
      RL( PosicionX1RL )                ; dato PosicionX1RL
      sub  eax, edx                     ; PosicionX1RL-PosicionX0RL+1
      inc  eax                          ; realiza el incremento en 1
      mov  [ EBP+LocalB ], eax          ; esto es TotalFilas
      mov  eax, [ EBP+ParametroB ]      ; repitiendo para columnas
      RL( PosicionY0RL )                ; primero Y0RL
      mov  [ EBP+LocalC ], eax          ; que es ColumnaInicial
      mov  edx, eax                     ; y se recuerda en edx
      mov  eax, [ EBP+ParametroB ]      ; luego el dato PosicionY1RL
      RL( PosicionY1RL )                ; para calcular
      sub  eax, edx                     ; PosicionY1RL-PosicionY0RL+1
      inc  eax                          ; ultimo incremento en 1
      mov  [ EBP+LocalD ], eax          ; que se guarda en TotalColumnas
      mov  eax, [ EBP+ParametroA ]      ; se lee ahora
      RL( EspacioElemento )             ; Pantalla.EspacioElemento
      mov  [ EBP+LocalG ], eax          ; que se guarda en LocalG
RepiteRecorreFila026:
      mov  eax, [ EBP+LocalC ]          ; ColumnaActual en eax
      push eax                          ; y luego al stack
      mov  eax, [ EBP+LocalA ]          ; FilaActual en eax
      push eax                          ; y luego al stack
      mov  eax, [ EBP+ParametroA ]      ; puntero a Matriz
      push eax                          ; al stack
      call ApuntarCasillaMatriz         ; se ubica dicha casilla en eax
      mov  [ EBP+LocalE ], eax          ; que se guarda en LocalE
      mov  eax, [ EBP+LocalG ]          ; leyendo EspacioElemento
      cmp  eax, 1                       ; CASE EspacioElemento
      jne  SaltoACase026                ; si no es 1 salta
      cld                               ; incremento en edi
      mov  eax, [ EBP+LocalE ]          ; si es 1 STOSB
      mov  edi, eax                     ; puntero a casilla en edi
      mov  ecx, [ EBP+LocalD ]          ; TotalColumnas en ecx
      mov  eax, [ EBP+ParametroC ]      ; dato byte en eax
      rep  STOSB                        ; copia al, ecx veces en edi
      jmp  FinalCase026                 ; salto a fin de CASE
SaltoACase026:
      cmp  eax, 2                       ; CASE EspacioElemento
      jne  SaltoBCase026                ; si no es 2 salta
      cld                               ; incremento en edi
      mov  eax, [ EBP+LocalE ]          ; si es 2 STOSW
      mov  edi, eax                     ; puntero a casilla en edi
      mov  ecx, [ EBP+LocalD ]          ; TotalColumnas en ecx
      mov  eax, [ EBP+ParametroC ]      ; dato word en eax
      rep  STOSW                        ; copia ax, ecx veces en edi
      jmp  FinalCase026                 ; salto a fin de CASE
SaltoBCase026:
      cmp  eax, 4                       ; CASE EspacioElemento
      jne  SaltoCCase026                ; si no es 4 salta
      cld                               ; incremento en edi
      mov  eax, [ EBP+LocalE ]          ; si es 4 STOSD
      mov  edi, eax                     ; puntero a casilla en edi
      mov  ecx, [ EBP+LocalD ]          ; TotalColumnas en ecx
      mov  eax, [ EBP+ParametroC ]      ; dato ParametroC en eax
      rep  STOSD                        ; copia eax, ecx veces en edi
      jmp  FinalCase026                 ; salto a fin de CASE
SaltoCCase026:
      cmp  eax, 3                       ; si no es 3 el CASE
      jne  SaltoDCase026                ; asume puntero a dato
      mov  eax, [ EBP+ParametroC ]      ; CASE 3 se transforma dato
      mov  BufferLongInt, eax           ; en puntero a BufferLongInt
      mov  eax, OFFSET BufferLongInt    ; el dato se guarda all¡
      mov  [ EBP+ParametroC ], eax      ; puntero en ParametroC
SaltoDCase026:
      mov  eax, [ EBP+LocalD ]          ; TotalColumnas se pasa a
      mov  [ EBP+LocalF ], eax          ; CuentaColumna
RepiteRecorreColumna026:
      mov  ecx, [ EBP+LocalG ]          ; recupera el tamano  ecx
                                        ; EspacioElemento
      mov  esi, [ EBP+ParametroC ]      ; recupera la fuente  esi
                                        ; puntero a Dato a copiar
      mov  edi, [ EBP+LocalE ]          ; recupera el destino edi
                                        ; puntero a casilla
      cld                               ; incremento de edi-esi
      rep  movsb                        ; transferencia de datos
      mov  eax, [ EBP+LocalE ]          ; puntero a Casilla
      mov  ecx, [ EBP+LocalG ]          ; para sumar el EspacioElemento
      add  eax, ecx                     ; y tener nuevo puntero a casilla
      mov  [ EBP+LocalE ], eax          ; que se guarda en LocalE
      mov  eax, [ EBP+LocalF ]          ; CuentaColumna
      dec  eax                          ; se decrementa en 1
      mov  [ EBP+LocalF ], eax          ; actualizando su valor
      cmp  eax, 0                       ; una y otra vez
      jne  RepiteRecorreColumna026      ; copiando el dato hasta Total
FinalCase026:
      mov  eax, [ EBP+LocalA ]          ; se incrementa en 1
      inc  eax                          ; el valor de Fila
      mov  [ EBP+LocalA ], eax          ; que se mantiene actualizado
      mov  eax, [ EBP+LocalB ]          ; se disminuye en 1
      dec  eax                          ; el valor de TotalFilas
      mov  [ EBP+LocalB ], eax          ; actualizado
      cmp  eax, 0                       ; para controlar el conteo a 0
      jne  RepiteRecorreFila026         ; o repetir Ciclo para fila
FinalRelleno026:
      pop  es                           ; se reestablece es

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  TresParametros               ; retorno liberacion de parametros
ENDP RellenarRectanguloMatriz

.CODE
PROC RellenarHomogeneoMatriz            ; numero identificacion 027
.CODE
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, DosLocales              ; espacio para locales
                                        ; ParametroA =
                                        ;       puntero a MatrizVariable
                                        ; ParametroB =
                                        ;       dato o puntero a dato
                                        ;       criterio
                                        ;       ParametroA^.EspacioElemento
                                        ;       si <= 4 entonces dato
                                        ;       caso contrario puntero
                                        ; LocalA     = AnchoFilaObjetivo
                                        ; LocalB     = AnchoColumnaObjetivo

      mov  BufferParametroA, RectanguloLongInt
                                        ; Usa BufferParametroA para
      mov  eax, OFFSET BufferParametroA ; preparar parametro
      RG( PosicionX0RL, 1 )             ; para PROC RellenarRectanguloMatriz
      mov  eax, OFFSET BufferParametroA ; se crea un RectanguloLongInt
      RG( PosicionY0RL, 1 )             ; del maximo tamano aplicable
      mov  eax, [ EBP+ParametroA ]      ; esto es
      RL( TotalFilas )                  ; (1,1,TotalFilas,TotalColumnas)
      mov  edx, eax                     ; para ello
      mov  eax, OFFSET BufferParametroA ; lee varias veces el OFFSET
      RG( PosicionX1RL, edx )           ; para ubicar el  puntero
      mov  eax, [ EBP+ParametroA ]      ; carga el puntero en ParametroA
      RL( TotalColumnas )               ; para le lectura de los campos
      mov  edx, eax                     ; TotalFilas y TotalColumnas
      mov  eax, OFFSET BufferParametroA ; ahora Rectangulo.PosicionY1RL
      RG( PosicionY1RL, edx )           ; con dato ParametroA.TotalColumnas
      mov  eax, [ EBP+ParametroB ]      ; finalmente se colocan
      push eax                          ; parametros en Stack puntero a dato
      push OFFSET BufferParametroA      ; puntero a Rectangulo
      mov  eax, [ EBP+ParametroA ]      ; y el puntero a pantalla
      push eax                          ; en orden inverso
      call RellenarRectanguloMatriz     ; finalmente llamado al PROC

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  DosParametros                ; retorno liberacion de parametros
ENDP RellenarHomogeneoMatriz

.CODE
PROC Mover                              ; numero identificacion 028
                                        ; PROC transfiere datos entre
                                        ; bloques
.CODE 
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, CeroLocales             ; espacio para locales
                                        ; ParametroA =
                                        ;       puntero a Dato Origen
                                        ; ParametroB =
                                        ;       puntero a Dato Destino
                                        ; ParametroC =
                                        ;       tamano transferencia

      push es                           ; edi trabaja en ES con "rep movsb"
      xor  eax, eax                     ; pero se necesita
      mov  ax, ds                       ; que sea en DS
      mov  es, ax                       ; asi que le cambiamos el valor
      mov  ecx, [ EBP+ParametroC ]      ; recupera el tamano  ecx
      cmp  ecx, 0                       ; verifica que no sea 0
      jle  IgnorarMover028              ; ni negativo
      mov  esi, [ EBP+ParametroA ]      ; recupera la fuente  esi
      cmp  esi, NIL                     ; verifica que no sea NIL
      je   IgnorarMover028              ; si se NIL salta a fin
      mov  edi, [ EBP+ParametroB ]      ; recupera el destino edi
      cmp  edi, NIL                     ; verifica que no es NIL
      je   IgnorarMover028              ; si es NIL salta a fin
      cld                               ; incremento de edi-esi
      rep  movsb                        ; transferencia de datos
      pop  es                           ; reestablece ES modificado
IgnorarMover028: 

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  TresParametros               ; retorno liberacion de parametros
ENDP Mover              

.CODE
PROC PutImageVirtual                    ; numero identificacion 029
                                        ; transferencia de zonas
                                        ; rectangulares entre
                                        ; tipos pantallas virtuales
                                        ; esto es 
                                        ; MatrizVariable.EspacioElemento=1
.DATA
  PivoteRectangulo029   dd      RectanguloLongInt       DUP(0)
                                        ; para crear si necesario
                                        ; un Rectangulo por "defecto"
                                        ; caso ParametroC = NIL
.CODE 
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, NueveLocales            ; espacio para locales
                                        ; ParametroA =
                                        ;       puntero a pantalla origen
                                        ; ParametroB =
                                        ;       puntero a pantalla destino
                                        ; ParametroC =
                                        ;       puntero a RectanguloLongInt
                                        ; ParametroD =
                                        ;       FilaDestino
                                        ; ParametroE =
                                        ;       ColumnaDestino
                                        ; ParametroF =
                                        ;       Conjunto modo Put
                                        ; BitsSelectores en ParametroF
                                        ; BitImageTransparente  =
                                        ;       Activa
                                        ;       aparicion de 
                                        ;       ColorTransparente
                                        ;       ( .DATA ) se ignora
                                        ;       transcripci¢n
                                        ; Grupo de Tres bits
                                        ; BitImageAnd = Alt1
                                        ; BitImageOr  = Alt2
                                        ; BirImageXor = Alt3
                                        ; Activo = A, Inactivo = I
                                        ; Alt1   Alt2   Alt3
                                        ;  I      I      I      = Simple
                                        ;  A      A      A      = NOT
                                        ;  A      I      I      = AND
                                        ;  I      A      A      = NAND
                                        ;  I      A      I      = OR
                                        ;  A      I      A      = NOR
                                        ;  I      I      A      = XOR
                                        ;  A      A      I      = NXOR
                                        ; LocalA = TotalRecorreFila
                                        ; LocalB = TotalRecorreColumna
                                        ; LocalC = BanderaTransparente
                                        ; LocalD = FilaPivote
                                        ; LocalE = ColumnaPivote
                                        ; LocalF = PunteroOrigen
                                        ; LocalG = PunteroDestino
                                        ; LocalH = DatoOrigen
                                        ; LocalI = DatoDestino

      mov  eax, [ EBP+ParametroA ]      ; primero revisa los punteros
      cmp  eax, NIL                     ; a pantalla que si son NIL
      je   Salida029                    ; el proceso no hace nada
      mov  eax, [ EBP+ParametroB ]      ; revisa ambos ParametroA
      cmp  eax, NIL                     ; y parametroB
      je   Salida029                    ; verificando que no sea NIL
      mov  eax, [ EBP+ParametroC ]      ; si el ParametroC es NIL
      cmp  eax, NIL                     ; se asume maximo marco de origen
      jne  CorregirMarco029             ; sino es NIL pasa a Corregir
      mov  PivoteRectangulo029, RectanguloLongInt
                                        ; si NIL el maximo rectangulo origen
      mov  edx, OFFSET PivoteRectangulo 029
                                        ; que se guarda en ParametroC
      mov  [ EBP+ParametroC ], edx      ; utilizando BufferParametroA
      mov  eax, edx                     ; BufferParametroA.PosicionX0RL
      RG( PosicionX0RL, 1 )             ; se asigna un 1
      mov  eax, edx                     ; BufferParametroA.PosicionY0RL
      RG( PosicionY0RL, 1 )             ; se asigna un 1
      mov  eax, [ EBP+ParametroA ]      ; BufferParametroA.PosicionX1RL
      RL( TotalFilas )                  ; se asigna ParametroA.TotalFilas
      mov  [ EDX+PosicionX1RL ], eax    ; BufferParametroA.PosicionY1RL
      mov  eax, [ EBP+ParametroA ]      ; se asigna ParametroA.TotalColumnas
      RL( TotalColumnas )               ; dejando por supuesto
      mov  [ EDX+PosicionY1RL ], eax    ; @BufferParametroA en ParametroC
CorregirMarco029:
      mov  eax, [ EBP+ParametroC ]      ; la revision del marco
      RL( PosicionX0RL )                ; comienza verificando que
      cmp  eax, 1                       ; Rectangulo.PosicionX0RL >= 1
      jge  IgnorarCorregirX0RL029       ; si esta bien no corrige
      mov  edx, eax                     ; pero si hay que corregir
      mov  eax, [ EBP+ParametroD ]      ; se desplaza ParametroD
      sub  eax, edx                     ; en forma simultanea
      inc  eax                          ; a un nuevo valor
      mov  [ EBP+ParametroD ], eax      ; ParametroD-PosicionX0RL+1
      mov  eax, [ EBP+ParametroC ]      ; se asigna
      RG( PosicionX0RL, 1 )             ; Rectangulo.PosicionX0RL = 1
IgnorarCorregirX0RL029:
      mov  eax, [ EBP+ParametroD ]      ; tambien se verifica
      cmp  eax, 1                       ; ParameteroD >= 1
      jge  IgnorarAFilaDestino029       ; si esta bien ignora
      mov  edx, eax                     ; caso contrario
      mov  eax, [ EBP+ParametroC ]      ; desplaza simultaneamente
      RL( PosicionX0RL )                ; Rectangulo.PosicionX0RL
      sub  eax, edx                     ; restando ParametroD
      inc  eax                          ; e incrementando en 1
      mov  edx, eax                     ; el valor corrige
      mov  eax, [ EBP+ParametroC ]      ; el original
      RG( PosicionX0RL, edx )           ; Rectangulo.PosicionX0RL
      mov  eax, 1                       ; y se asigna un 1
      mov  [ EBP+ParametroD ], eax      ; a ParametroD
IgnorarAFilaDestino029:
      mov  eax, [ EBP+ParametroC ]      ; se realiza una revision del marco
      RL( PosicionY0RL )                ; para las columnas
      cmp  eax, 1                       ; Rectangulo.PosicionY0RL >= 1
      jge  IgnorarCorregirY0RL029       ; si esta bien ignora
      mov  edx, eax                     ; caso contrario
      mov  eax, [ EBP+ParametroE ]      ; corrige ParametroE segun
      sub  eax, edx                     ; ParametroE-PosicionY0RL+1
      inc  eax                          ; reescribiendo su valor
      mov  [ EBP+ParametroE ], eax      ; ademas asigna un 1        
      mov  eax, [ EBP+ParametroC ]      ; a Rectangulo.PosicionY0RL
      RG( PosicionY0RL, 1 )             ; con desplazamientos iguales
IgnorarCorregirY0RL029:
      mov  eax, [ EBP+ParametroE ]      ; revisas tambien que ParametroE
      cmp  eax, 1                       ; sea mayor o igual a 1
      jge  IgnorarAColumnaDestino029    ; si esta bien ignora
      mov  edx, eax                     ; caso contrario
      mov  eax, [ EBP+ParametroC ]      ; realiza desplazamiento simultaneo
      RL( PosicionY0RL )                ; corrigiento PosicionY0RL
      sub  eax, edx                     ; con PosicionY0RL-ParametroE+1
      inc  eax                          ; el nuevo valor corrige
      mov  edx, eax                     ; el anterior
      mov  eax, [ EBP+ParametroC ]      ; para lo cual se utiliza el macro
      RG( PosicionY0RL, edx )           ; RG con ParametroC en eax
      mov  eax, 1                       ; ademas asignaria el 1
      mov  [ EBP+ParametroE ], eax      ; correcto a ParametroE
IgnorarAColumnaDestino029:
      mov  eax, [ EBP+ParametroC ]      ; sigue ahora calcular
      mov  edx, eax                     ; LocalA = PosicionX1RL-PosicionX0RL
      RL( PosicionX1RL )                ; como primera estimacion
      mov  ecx, eax                     ; de RecorreFila
      mov  eax, edx                     ; en edx se guardo ParametroC
      RL( PosicionX0RL )                ; y en ecx PosicionX1RL
      sub  ecx, eax                     ; para luego pasar ecx
      mov  [ EBP+LocalA ], ecx          ; como valor provisional de LocalA
      mov  edx, [ EBP+ParametroD ]      ; pero es necesario verifical
      add  edx, ecx                     ; que FilaInicial+LocalA
      mov  eax, [ EBP+ParametroB ]      ; no supere a ParametroB.TotalFilas
      RL( TotalFilas )                  ; para ello se hace
      cmp  eax, edx                     ; la comparacion
      jge  ProbarSignoFila029           ; si no hay problema se ignora
      mov  ebx, [ EBP+ParametroD ]      ; caso contrario
      sub  eax, ebx                     ; se calcula TotalFilas-PosIniY
      mov  [ EBP+LocalA ], eax          ; se guarda en LocalA provisional        
ProbarSignoFila029:
      mov  eax, [ EBP+LocalA ]          ; pero se requiere sumar 1 a LocalA
      inc  eax                          ; para tomar en cuenta casilla
      cmp  eax, 1                       ; inicial y verificar que vale
      jle  Salida029                    ; al menos 1 en caso contrario FIN
      mov  [ EBP+LocalA ], eax          ; si todo bien se guarda el valor
      mov  eax, [ EBP+ParametroC ]      ; ahora le toca el turno
      mov  edx, eax                     ; a LocalB estimada inicialmente
      RL( PosicionY1RL )                ; como PosicionY1RL-PosicionY0RL
      mov  ecx, eax                     ; utilizando ecx para PosicionY1RL
      mov  eax, edx                     ; y edx para Rectangulo
      RL( PosicionY0RL )                ; se obtiene la resta en ecx
      sub  ecx, eax                     ; que luego se pasa a LocalB
      mov  [ EBP+LocalB ], ecx          ; es sin embargo necesario
      mov  edx, [ EBP+ParametroE ]      ; sumarlo a ColumnaInicial
      add  edx, ecx                     ; para verificar que es menor
      mov  eax, [ EBP+ParametroB ]      ; a TotalColumnas en objetivo
      RL( TotalColumnas )               ; para ello se hace
      cmp  eax, edx                     ; la comparacion
      jge  ProbarSignoColumna029        ; si no hay problema se ignora
      mov  ebx, [ EBP+ParametroE ]      ; caso contrario se asigna
      sub  eax, ebx                     ; a LocalB (TotalColumnas-PosIniX )
      mov  [ EBP+LocalB ], eax          ; mediante una doble resta
ProbarSignoColumna029:
      mov  eax, [ EBP+LocalB ]          ; es necesario
      inc  eax                          ; sumarle 1 por casilla inicial
      cmp  eax, 1                       ; y verificar que el resultado
      jle  Salida029                    ; es mayor a 1 si no FIN
      mov  [ EBP+LocalB ], eax          ; ahora se hacen las asignaciones
      mov  eax, [ EBP+ParametroC ]      ; LocalD = Rectangulo.PosicionX0RL
      RL( PosicionX0RL )                ; LocalE = Rectangulo.PosicionY0RL
      mov [ EBP+LocalD ], eax           ; que se utilizan para recorrer la
      mov  eax, [ EBP+ParametroC ]      ; fila y columna inicial
      RL( PosicionY0RL )                ; en la pantalla origen
      mov [ EBP+LocalE ], eax           ; se utiliza eax como pivote
      mov  eax, [ EBP+ParametroF ]      ; a travez de la macro RL
      cmp  eax, 0                       ; el modo ParametroF = 0
      jne  ModoPutEspecial029           ; es modo Put corriente
RecorreFilaNormal029:
      mov  eax, [ EBP+LocalB ]          ; ParametroC = Bytes a PROC Mover
      push eax                          ; se coloca en stack (paciencia)
      mov  eax, [ EBP+ParametroE ]      ; ParametroC de PROC ApuntarCasi...
      push eax                          ; que es ColumnaInicial
      mov  eax, [ EBP+ParametroD ]      ; ApuntarCasi.. ParametroC
      push eax                          ; que es FilaInicial
      mov  eax, [ EBP+ParametroB ]      ; en pantalla destino
      push eax                          ; como ParametroA de ApuntarCasi..
      call ApuntarCasillaMatriz         ; ubica el puntero destino como
      push eax                          ; ParametroB = destino a PROC Mover
      mov  eax, [ EBP+LocalE ]          ; el puntero origen se ubica
      push eax                          ; con ParametroA(LocalD,LocalE)
      mov  eax, [ EBP+LocalD ]          ; con ApuntarCasi...
      push eax                          ; colocando parametros en orden
      mov  eax, [ EBP+ParametroA ]      ; inverso en Stack        
      push eax                          ; y luego obtiene el puntero a
      call ApuntarCasillaMatriz         ; casilla que se para como
      push eax                          ; ParametroA = origen PROC Mover
      call Mover                        ; transferencia de columna completa
      mov  eax, [ EBP+ParametroD ]      ; se corrige ColumnaInicial
      inc  eax                          ; sumando 1 a su valor
      mov [ EBP+ParametroD ], eax       ; y reescribiendolo
      mov  eax, [ EBP+LocalD ]          ; se corrige ColumnaPivote
      inc  eax                          ; sumando 1 a su valor
      mov  [ EBP+LocalD ], eax          ; y reescribiendolo
      mov  eax, [ EBP+LocalA ]          ; se le resta 1 a TotalRecorreFila
      dec  eax                          ; en cuenta regresiva
      mov  [ EBP+LocalA ], eax          ; reescribiendo y verificando
      cmp  eax, 0                       ; cuando se llega a 0
      jne  RecorreFilaNormal029         ; si no es 0 repite el ciclo
      jmp  Salida029                    ; se acabo ahora FIN
ModoPutEspecial029:
      mov  edx, eax                     ; ParametroF en edx
      mov  ebx, FALSE                   ; FALSE con ebx como pivote
      and  eax, BitImageTransparente    ; Bit de ParametroF
      cmp  eax, BitImageTransparente    ; si no se encuentra el Bit
      jne  IgnorarTRUETransparente029   ; ebx se mantiene en FALSE
      mov  ebx, TRUE                    ; si no ebx se corrige a TRUE
IgnorarTRUETransparente029:
      mov  [ EBP+LocalC ], ebx          ; y se asigna a bandera LocalC
      mov  eax, edx                     ; nuevamente ParametroF en eax
      and  eax, BitImageAND+BitImageOR+BitImageXOR
                                        ; revisando Bits logicos
      mov  [ EBP+ParametroF ], eax      ; resultado depurado en ParametroF
RecorreFilaEspecial029:
      mov  eax, [ EBP+ParametroE ]      ; ParametroC de PROC ApuntarCasi...
      push eax                          ; que es ColumnaInicial
      mov  eax, [ EBP+ParametroD ]      ; ApuntarCasi.. ParametroC
      push eax                          ; que es FilaInicial
      mov  eax, [ EBP+ParametroB ]      ; en pantalla destino
      push eax                          ; como ParametroA de ApuntarCasi..
      call ApuntarCasillaMatriz         ; ubica el puntero destino como
      mov  edi, eax                     ; edi = puntero a destino
      mov  eax, [ EBP+LocalE ]          ; el puntero origen se ubica
      push eax                          ; con ParametroA(LocalD,LocalE)
      mov  eax, [ EBP+LocalD ]          ; con ApuntarCasi...
      push eax                          ; colocando parametros en orden
      mov  eax, [ EBP+ParametroA ]      ; inverso en Stack
      push eax                          ; y luego obtiene el puntero a
      call ApuntarCasillaMatriz         ; casilla que se para como
      mov  esi, eax                     ; esi = puntero a origen
      mov  edx, [ EBP+ParametroF ]      ; parametros logicos
      mov  ecx, [ EBP+LocalB ]          ; ecx contador de columna
RecorreColumnaEspecial029:
      mov  ebx, esi                     ; procede a leer el dato
      xor  eax, eax                     ; en origen
      mov  al, [ ebx ]                  ; y se guarda en eax
      mov  ebx, edx                     ; si ParametroF = 0
      cmp  ebx, 0                       ; solo se revisa ColorTransparente
      jne  IgnorarSimpleTransparente029 ; caso contrario necesita mas
      cmp  eax, ColorTransparente       ; si es igual al ColorTransparente
      je   SalidaVerificacionColor029   ; salta sin hacer nada
      mov  ebx, edi                     ; si no es escribe normalmente
      mov  [ ebx ], al                  ; pues ParametroF es 0
      jmp  SalidaVerificacionColor029   ; y pasa a siguiente casilla
IgnorarSimpleTransparente029:
      mov  ebx, [ EBP+LocalC ]          ; si ParametroF no es 0
      cmp  ebx, TRUE                    ; revisa bandera LocalC
      jne  IgnorarColorTransparente029  ; si es TRUE
      cmp  eax, ColorTransparente       ; revisa ColorTransparente
      je   SalidaVerificacionColor029   ; para ignorar casilla si es el caso
IgnorarColorTransparente029:
      mov  [ EBP+LocalH ], eax          ; guarda el dato origen en LocalH
      mov  ebx, edi                     ; y guarda el dato destino
      xor  eax, eax                     ; en eax para luego
      mov  al, [ ebx ]                  ; transferirlo a LocalI
      mov  [ EBP+LocalI ], eax          ; utilizando en ebx la direccion
      mov  ebx, edx                     ; nuevamente ParametroF (edx)
      cmp  ebx, BitImageAND             ; CASE BitImageAND
      jne  IgnorarAND029                ; si no ver siguiente
      mov  eax, [ EBP+LocalH ]          ; carga LocalH y LocalI
      mov  ebx, [ EBP+LocalI ]          ; para operar con un and
      and  eax, ebx                     ; el resultado se guarda
      mov  ebx, edi                     ; en edi, utilizando
      mov  [ ebx ], al                  ; [ ebx ] como pivote
      jmp  SalidaVerificacionColor029   ; siguiente casilla
IgnorarAND029:
      mov  ebx, edx                     ; nuevamente ParametroF
      cmp  ebx, BitImageOR              ; CASE BitImageOR
      jne  IgnorarOR029                 ; si no siguiente CASE
      mov  eax, [ EBP+LocalH ]          ; carga LocalH y LocalI
      mov  ebx, [ EBP+LocalI ]          ; y realiza la operacion
      or   eax, ebx                     ; resultado en eax
      mov  ebx, edi                     ; direccion destion en ebx
      mov  [ ebx ], al                  ; se guarda el dato
      jmp  SalidaVerificacionColor029   ; y se pasa a la siguiente casilla
IgnorarOR029:
      mov  ebx, edx                     ; nuevamente el ParametroF
      cmp  ebx, BitImageXOR             ; CASE BitImageXOR
      jne  IgnorarXOR029                ; si no siguiente CASE
      mov  eax, [ EBP+LocalH ]          ; se carga LocalH y LocalI
      mov  ebx, [ EBP+LocalI ]          ; y se aplica el xor
      xor  eax, ebx                     ; con resultado en eax
      mov  ebx, edi                     ; y direccion destino en ebx
      mov  [ ebx ], al                  ; se guarda el dato
      jmp  SalidaVerificacionColor029   ; pasa a siguiente casilla
IgnorarXOR029:
      mov  ebx, edx                     ; nuevamente parametroF
      cmp  ebx, BitImageOR+BitImageXOR  ; CASE NOT ( ... AND ... )
      jne  IgnorarNAND029               ; si no siguiente CASE
      mov  eax, [ EBP+LocalH ]          ; primero cargar los datos
      mov  ebx, [ EBP+LocalI ]          ; LocalH y LocalI
      and  ebx, eax                     ; luego aplica el AND
      mov  eax, TotalInversoColor       ; se carga TotalInversoColor
      sub  eax, ebx                     ; para el NOT
      mov  ebx, edi                     ; en ebx direccion destino
      mov  [ ebx ], al                  ; se guarda resultado
      jmp  SalidaVerificacionColor029   ; se pasa a siguiente casilla
IgnorarNAND029:
      mov  ebx, edx                     ; nuevamente parametroF
      cmp  ebx, BitImageAND+BitImageXOR ; CASE NOT ( ... OR ... )
      jne  IgnorarNOR029                ; si no siguiente CASE
      mov  eax, [ EBP+LocalH ]          ; carga LocalH y LocalI
      mov  ebx, [ EBP+LocalI ]          ; para aplicar or
      or   ebx, eax                     ; y luego el NOT
      mov  eax, TotalInversoColor       ; con respecto a TotalInversoColor
      sub  eax, ebx                     ; mediante diferencia
      mov  ebx, edi                     ; el resultado se guarda en edi
      mov  [ ebx ], al                  ; con [ ebx ] como pivote
      jmp  SalidaVerificacionColor029   ; se pasa a siguiente casilla
IgnorarNOR029:
      mov  ebx, edx                     ; nuevamente ParametroF
      cmp  ebx, BitImageAND+BitImageOR  ; CASE NOT ( ... XOR ... )
      jne  IgnorarNXOR029               ; si no siguiente
      mov  eax, [ EBP+LocalH ]          ; se aplica la operacion
      mov  ebx, [ EBP+LocalI ]          ; LocalH XOR LocalI
      xor  ebx, eax                     ; y por resta
      mov  eax, TotalInversoColor       ; con TotalInversoColor
      sub  eax, ebx                     ; se obtiene el NOT
      mov  ebx, edi                     ; NOTA: el resultado es probablemente
      mov  [ ebx ], al                  ; diferente del resultado logico
      jmp  SalidaVerificacionColor029   ; se pasa a siguiente casilla
IgnorarNXOR029:
      mov  ebx, [ EBP+LocalH ]          ; CASE NOT
      mov  eax, TotalInversoColor       ; se calcula el complemento
      sub  eax, ebx                     ; de TotalInversoColor y LocalH
      mov  ebx, edi                     ; se guarda el resultado en edi
      mov  [ ebx ], al                  ; utilizando [ ebx ] como pivote
SalidaVerificacionColor029:
      inc  edi                          ; siguiente casilla destino
      inc  esi                          ; siguiente casilla origen
      dec  ecx                          ; decrementa contador regresivo
      cmp  ecx, 0                       ; si llega a 0 final
      jne  RecorreColumnaEspecial029    ; ecx contador de columna
      mov  eax, [ EBP+ParametroD ]      ; se corrige ColumnaInicial
      inc  eax                          ; sumando 1 a su valor
      mov [ EBP+ParametroD ], eax       ; y reescribiendolo
      mov  eax, [ EBP+LocalD ]          ; se corrige ColumnaPivote
      inc  eax                          ; sumando 1 a su valor
      mov  [ EBP+LocalD ], eax          ; y reescribiendolo
      mov  eax, [ EBP+LocalA ]          ; se le resta 1 a TotalRecorreFila
      dec  eax                          ; en cuenta regresiva
      mov  [ EBP+LocalA ], eax          ; reescribiendo y verificando
      cmp  eax, 0                       ; cuando se llega a 0
      jne  RecorreFilaEspecial029       ; si no es 0 repite el ciclo
Salida029:

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  SeisParametros               ; retorno liberacion de parametros
ENDP PutImageVirtual

