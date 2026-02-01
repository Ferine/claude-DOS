.INCLUDE io.inc
.INCLUDE system.inc

.TYPE  ( NIL            =  0, TRUE              = -1, FALSE         =  0 )

.TYPE  ( CampoBase      =  0, Campo1            =  4, Campo2        =  8
         Campo3         = 12, Campo4            = 16, Campo5        = 20
         Campo6         = 24, Campo7            = 28, Campo8        = 32
         Campo9         = 36, Campo10           = 40, Campo11       = 44
         Campo12        = 48, Campo13           = 52, Campo14       = 56 )        

.TYPE  ( ParametroEBP   =  0, ParametroEIP      =  4, ParametroA    =  8
         ParametroB     = 12, ParametroC        = 16, ParametroD    = 20
         ParametroE     = 24, ParametroF        = 28, ParametroG    = 32
         ParametroH     = 36, ParametroI        = 40, ParametroJ    = 44
         LocalA         = -4, LocalB            = -8, LocalC        =-12
         LocalD         =-16, LocalE            =-20, LocalF        =-24
         LocalG         =-28, LocalH            =-32, LocalI        =-36
         LocalJ         =-40  )

.TYPE  ( CeroParametros         =   0, UnParametro              =   4
         DosParametros          =   8, TresParametros           =  12
         CuatroParametros       =  16, CincoParametros          =  20
         SeisParametros         =  24, SieteParametros          =  28
         OchoParametros         =  32, NueveParametros          =  36
         DiezParametros         =  40, CeroLocales              =   0
         UnLocal                =   4, DosLocales               =   8
         TresLocales            =  12, CuatroLocales            =  16
         CincoLocales           =  20, SeisLocales              =  24
         SieteLocales           =  28, OchoLocales              =  32
         NueveLocales           =  36, DiezLocales              =  40  )

.TYPE  ( ArrayVariable  = 28, TamanoPunteroAV   =  0, TamanoVector  =  4 
         Ocupado        =  8, EspacioElemento   = 12, Campo1AV      = 16
         Campo2AV       = 20, ReservadoAV       = 24, MemoriaVector = 28 )

.TYPE  ( MatrizVariable = 28, TotalFilas        = 16, TotalColumnas = 20 )

.TYPE  ( ConjuntoVacio  =   000000000h, ConjuntoTotal   = 0FFFFFFFFh
         Variante1      =   000000001h, Variante2       = 000000002h
         Variante3      =   000000004h, Variante4       = 000000008h
         Variante5      =   000000010h, Variante6       = 000000020h
         Variante7      =   000000040h, Variante8       = 000000080h
         Variante9      =   000000100h, Variante10      = 000000200h
         Variante11     =   000000400h, Variante12      = 000000800h
         Variante13     =   000001000h, Variante14      = 000002000h
         Variante15     =   000004000h, Variante16      = 000008000h
         Variante17     =   000010000h, Variante18      = 000020000h
         Variante19     =   000040000h, Variante20      = 000080000h
         Variante21     =   000100000h, Variante22      = 000200000h
         Variante23     =   000400000h, Variante24      = 000800000h
         Variante25     =   001000000h, Variante26      = 002000000h
         Variante27     =   004000000h, Variante28      = 008000000h
         Variante29     =   010000000h, Variante30      = 020000000h
         Variante31     =   040000000h, Variante32      = 080000000h  )

.TYPE  ( CadenaEnlazada = 16, TamanoPunteroCE   =  0, IdentificadorCE =  4
         SiguienteCE    =  8, PunteroDatoCE     = 12, Campo1CE        = 16
         Campo2CE       = 20, Campo3CE          = 24, Campo4CE        = 28
         Campo5CE       = 32, Campo6CE          = 36, Campo7CE        = 40
         Campo8CE       = 44, Campo9CE          = 48, Campo10CE       = 52
         Campo11CE      = 56, Campo12CE         = 60, Campo13CE       = 64 )

.TYPE  ( TamanoBufferParametro                  = 256*4   )

.PUBLIC .DATA
  BufferWriteLn      db 512 DUP(0)   ; como intermediario de WriteLn
  BufferReadLn       db 512 DUP(0)   ; como intermediario de ReadLn                                                   
  BufferLongInt      dd 0            ; para escribir numeros en pantalla
  BufferParametroA   dd 256 DUP(0)   ; para RECORD flotantes
  BufferParametroB   dd 256 DUP(0)   ; para RECORD flotantes
  BufferParametroC   dd 256 DUP(0)   ; para RECORD flotantes
  BufferParametroD   dd 256 DUP(0)   ; para RECORD flotantes
  BufferParametroE   dd 256 DUP(0)   ; para RECORD flotantes
  MensajeError1      db  'Error en Lectura Archivo',0
  MensajeErrorGeneral
                     db  'Se detect¢ un error de proceso...',0
  MensajeEnter       db  'Presione ENTER para continuar...',0
  NombrePrograma     db  'JULIO08.EXE',0
                                     ; nombre programa actual    
  ErrorArchivo       dd  0           ; reporta errores en manejo Archivo

.MACRO RL( Desplazamiento )
                                     ; input  eax : puntero a Record
                                     ; output eax : Dato LongInt en campo
       add  eax, Desplazamiento      ; agrega el desplazamiento al puntero   
       mov  eax, [eax]               ; realiza la lectura LongInt del dato   
ENDMACRO

.MACRO RG( DesplazamientoO, DatoMacro )
                                     ; guarda dato en un Record (eax)
                                     ; input  eax : puntero a Record
                                     ; DesplazamientoO : Campo en el Record
                                     ; Dato : LongInt a guardar alli
                                     ; output eax : Puntero al campo
                                     ;        ebx : Dato    
       add  eax, DesplazamientoO     ; agrega el desplazamiento al RECORD
       mov  ebx, DatoMacro           ; coloca dato en ebx   
       mov  [eax], ebx               ; guarda el dato en Campo   
ENDMACRO

.MACRO AP( Apuntado )                
                                     ; devuelve direccion de un dato en el
                                     ; ArrayVariable
                                     ; input  eax : puntero a ArrayVariable
                                     ; Apuntado   : numero de casilla
                                     ;       de 1 a TamanoVector
                                     ; output eax : puntero a casilla
                                     ; pierde ebx ecx edx
       mov ecx, Apuntado             ; coloca Apuntado en ecx
       mov ebx, eax                  ; coloca puntero ebx para suma final
       dec ecx                       ; le resta 1 para ajustar posicion   
       mov eax, [ EAX+EspacioElemento ]
                                     ; coloca EspacioElemento en eax
       mul ecx                       ; corrimiento de datos
       add eax, MemoriaVector        ; ajustado con corrimiento inicial
                                     ; cabecera+EspacioElemento*(Apuntado-1)   
       add eax, ebx                  ; agregar posicion de puntero
ENDMACRO

.MACRO DefinirPuntero( TamanoPedido, Puntero, TamanoLogrado )
       mov  eax,TamanoPedido         ; en eax el futuro tamano de puntero
       call SystemGetMem             ; reserva en memoria el puntero
       mov  Puntero,edx              ; guarda en memoria la direccion
       sub  eax,4                    ; [Puntero-4] tiene el tamano con btr 0
       mov  ecx,[eax]                ; carga el [Puntero-4]
       btr  ecx,0                    ; bit 0 es bandera de ocupado
       mov  TamanoLogrado,ecx        ; guarda el tamano
ENDMACRO

.MACRO EliminarPuntero( Puntero, TamanoReservado )
       mov  edx, Puntero             ; direccion de memoria a eliminar edx
       mov  eax, TamanoReservado     ; tamano asignado al puntero eax
       call SystemFreeMem            ; procedimiento que libera memoria
ENDMACRO

.MACRO Escribir( Rotulo )
.DATA
  .LOCAL MiRotulo  DB Rotulo,0      ; crea un .LOCAL para etiquetar el numero
.CODE
      mov  edi,OFFSET .LOCAL MiRotulo 
      call systemWriteLn               ; imprime la etiqueta Rotulo
ENDMACRO

.MACRO EscribirNumero( Rotulo, Numero )
.DATA
  .LOCAL MiRotulo  DB Rotulo,0      ; crea un .LOCAL para etiquetar el numero
.CODE
      mov  eax, Numero                 ; guarda el Numero en eax 
      mov  BufferLongInt, eax          ; lo guarda en BufferLongInt
                                       ; problemas si pone comentarios en
                                       ; renglon siguiente 
      mov  edi,OFFSET .LOCAL MiRotulo 
      call systemWriteLn               ; imprime la etiqueta Rotulo
      mov  eax, BufferLongInt          ; lee el numero
      mov  edi,OFFSET BufferWriteLn    ; el numero se traduce directo a Write
      call MathToString                ; traduce el numero
      mov  edi,OFFSET BufferWriteLn    ; guarda la siguente llamada a Write
      call systemWriteLn               ; escribe el numero
ENDMACRO

.MACRO EscribirEnter
.CODE
      mov  edi, OFFSET MensajeEnter    ; mensaje de presione Enter... 
      call SystemWriteLn               ; escribe el mensaje 
      mov  edi, OFFSET BufferReadLn    ; buffer de ReadLn
      call SystemReadLn                ; espera el Enter para continuar 
ENDMACRO

.CODE
PROC ProcedimientoGeneral               ; numero identificacion 001
.DATA
  MiRotulo001              db 'ParametroB (e=2000) : ',0
.CODE 
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, DosLocales              ; espacio para locales
                                        ; tiene tres parametros
                                        ; unicamente ParametroB se usa
                                        ; para un simple despliegue

      mov  edi,OFFSET MiRotulo001       ; rotulo interno de PROC
      call systemWriteLn                ; lo despliega en pantalla 
      mov  eax, [ EBP+ParametroB ]      ; lee el ParametroB
      mov  edi,OFFSET BufferWriteLn     ; el numero se traduce 
                                        ; directo a Write
      call MathToString                 ; traduce el numero
      mov  edi,OFFSET BufferWriteLn     ; guarda la siguente llamada a Write
      call systemWriteLn                ; escribe el numero

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  TresParametros               ; retorno liberacion de parametros
ENDP ProcedimientoGeneral

.CODE
PROC BlanquearRegistro                  ; numero identificacion 014
.CODE 
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, CeroLocales             ; espacio para locales
                                        ; ParametroA =
                                        ;       puntero a Registro
                                        ; ParametroB =
                                        ;       desplazamiento inicial
                                        ;       para anular mayor a 4

      push es                           ; hay que reubicar es a ds
      xor  eax, eax                     ; pues STOSB trabaja con es
      mov  ax, ds                       ; se utiliza ax
      mov  es, ax                       ; como pivote
      mov  eax, [ EBP+ParametroA ]      ; puntero a Registro
      RL( CampoBase )                   ; lee el tamano
      mov  ecx, eax                     ; y coloca en contador ecx
      mov  eax, [ EBP+ParametroB ]      ; lee el desplazamiento inicial
      cmp  eax, 4                       ; debe ser al menos 4
      jl   Error014                     ; si no, no blanquea
      cmp  ecx, eax                     ; y menor al tamano
      jl   Error014                     ; si no, no blanquea
      sub  ecx, eax                     ; total de bytes a anular
      add  eax, [ EBP+ParametroA ]      ; posicion en RAM desplazada        
      mov  edi, eax                     ; se ubica en edi
      xor  eax, eax                     ; se rellena con ceros
      cld                               ; REP incrementa edi
      REP  STOSB                        ; instruccion de escritura de al
Error014:
      pop  es                           ; reestablece es cambiado al inicio

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  DosParametros                ; retorno liberacion de parametros
ENDP BlanquearRegistro   

PROC NewRegistro                        ; numero identificacion 002
.CODE 
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, UnLocal                 ; espacio para locales
                                        ; ParametroA = TamanoPuntero
                                        ; OUT eax = direccion de  registro

      mov  eax, [ EBP+ParametroA ]      ; obtiene el tamano en eax
      call SystemGetMem                 ; crea el puntero
      sub  eax, 4                       ; eax y edx tienen el puntero
      mov  ecx, [eax]                   ; 4 bytes antes el tamano
      btr  ecx, 0                       ; con marca de bit al final
      mov  [ edx+CampoBase ], ecx       ; guardamos tamano en REGISTRO
      mov  [ EBP+LocalA ], edx          ; LocalA guarda puntero
      push 4                            ; protege los primeros 4 bytes
      push edx                          ; el resto se rellena de ceros
      call BlanquearRegistro            ; blanqueador de Registro
      mov  eax, [ EBP+LocalA ]          ; OUT el puntero en eax

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  UnParametro                  ; retorno liberacion de parametros
ENDP NewRegistro          

PROC DisposeRegistro                    ; numero identificacion 003
.CODE 
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, CeroLocales             ; espacio para locales
                                        ; ParametroA = 
                                        ;   ByRef DireccionPuntero
                                        ; no OUT

      mov  eax, [ EBP+ParametroA ]      ; en eax la direccion del puntero
      cmp  eax, NIL                     ; si es NIL nada
      je   SalidaNIL003                 ; salida rapida si NIL
      mov  edx, [ eax ]                 ; el puntero es ByRef
      mov  ecx, NIL                     ; NIL en ecx como intermediario
      mov  [ eax ], ecx                 ; guarda NIL en el ByRef
      cmp  edx, NIL                     ; no hace nada si NIL
      je   SalidaNIL003                 ; salida rapida si NIL
      mov  eax, [ edx+CampoBase ]       ; en eax el tamano
      call SystemFreeMem                ; libera memoria

SalidaNIL003:
      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  UnParametro                  ; retorno liberacion de parametros
ENDP DisposeRegistro          

PROC NewArrayVariable                   ; numero identificacion 004
.CODE 
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, CeroLocales             ; espacio para locales
                                        ; ParametroA = TamanoVector
                                        ; ParametroB = EspacioElemento
                                        ; OUT eax = direccion de Array

      mov  eax, [ EBP+ParametroA ]      ; obtiene el tamano en eax
      mov  ecx, [ EBP+ParametroB ]      ; obtiene Espacio elemento en eax
      mul  ecx                          ; tamano en Bytes de datos
      add  eax, MemoriaVector           ; mas la cabecera
      push eax                          ; tamano Array a NewRegitro
      call NewRegistro                  ; crea el espacio en memoria RAM
      mov  ecx, [ EBP+ParametroA ]      ; obtiene el tamano en ecx
      mov  [ EAX+TamanoVector    ], ecx ; guarda TamanoVector
      mov  ecx, [ EBP+ParametroB ]      ; obtiene el EspacioElemento en ecx
      mov  [ EAX+EspacioElemento ], ecx ; guarda en EspacioElemento
      mov  ecx, 0                       ; dato inmediato
      mov  [ EAX+Ocupado         ], ecx ; 0 en Ocupado
      mov  [ EAX+ReservadoAV     ], ecx ; 0 en ReservadoAV
 
      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  DosParametros                ; retorno liberacion de parametros
ENDP NewArrayVariable 

PROC DisposeArrayVariable               ; numero identificacion 005
                                        ; liberar de memoria
                                        ; un VectorVariable
.CODE 
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, CeroLocales             ; espacio para locales
                                        ; ParametroA = 
                                        ;   ByRef DireccionPuntero
                                        ; no OUT

      mov  eax, [ EBP+ParametroA ]      ; en eax la direccion del puntero
      push eax                          ; prepara parametro para call
      call DisposeRegistro              ; mismo metodo de Dispose

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  UnParametro                  ; retorno liberacion de parametros
ENDP DisposeArrayVariable 

PROC NewCadenaEnlazada                  ; numero identificacion 006
.CODE 
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, CeroLocales             ; espacio para locales
                                        ; ParametroA = Tamano CadenaEnlazada
                                        ; ParametroB = puntero a Siguiente
                                        ; ParametroC = puntero a Dato
                                        ; OUT eax = 
                                        ;     direccion de CadenaEnlazada

      mov  eax, [ EBP+ParametroA ]      ; lee el Tamano
      push eax                          ; lo pone en Stack
      call NewRegistro                  ; para llamar a NewRegistro
      mov  ebx, [ EBP+ParametroB ]      ; carga ParametroB
      mov  [ EAX+SiguienteCE ], ebx     ; y lo asigna a SiguienteCE
                                        ; note que esto podria crear
                                        ; una secuencia enlazada
      mov  ebx, [ EBP+ParametroC ]      ; carga ParametroC
      mov  [ EAX+PunteroDatoCE ], ebx   ; y lo asigna a PunteroDato
                                        ; se asume tipo Registro compatible
      mov  ebx, 0                       ; prepara asignar 0
      mov  [ EAX+IdentificadorCE ], ebx ; a Identificador CE     

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  TresParametros               ; retorno liberacion de parametros
ENDP NewCadenaEnlazada   

PROC DisposeCadenaEnlazada              ; numero identificacion 007
                                        ; destruye la cadena enlazada
                                        ; sus descendientes y datos
                                        ; se asumen datos tipo Registro
.CODE 
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, UnLocal                 ; espacio para locales
                                        ; ParametroA = 
                                        ;    ByRef DireccionPuntero

      mov  ebx, [ EBP+ParametroA ]      ; carga direccion Puntero
      cmp  ebx, NIL                     ; verifica NIL
      je   SalidaNIL007                 ; si NIL no hay que hacer nada
      mov  eax, [ ebx ]                 ; carga el puntero
      cmp  eax, NIL                     ; tambien revisa NIL de contenido
      je   SalidaNIL007                 ; en ese caso ignora
      mov  [ EBP+LocalA ], eax          ; lo guarda en LocalA
      add  eax, SiguienteCE             ; busca el campo SiguienteCE
      mov  ebx, [ eax ]                 ; y lo lee en ebx
      cmp  ebx, NIL                     ; verifica NIL
      je   NoDisposeSiguiente007        ; si es NIL se ignora
      push eax                          ; si no se libera de memoria
      call DisposeCadenaEnlazada        ; pasando ByRef 
                                        ; note la recursividad para liberar
                                        ; la cadena completa

NoDisposeSiguiente007:
      mov  eax, [ EBP+LocalA ]          ; LocalA es punterocabeza
      add  eax, PunteroDatoCE           ; campo PunteroDatoCE
      mov  ebx, [ eax ]                 ; se lee el campo
      cmp  ebx, NIL                     ; verifica si NIL
      je   NoDisposeDato007             ; si NIL ignora
      push eax                          ; ByRef puntero a liberar
      call DisposeRegistro              ; se libera asumiento Registro
NoDisposeDato007:
      mov  eax, [ EBP+ParametroA ]      ; ByRef punteroCabeza
      push eax                          ; prepara su eliminacion
      call DisposeRegistro              ; se libera como Registro
                                        ; pues ya se liberaron sus punteros
      
SalidaNIL007:
      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  UnParametro                  ; retorno liberacion de parametros
ENDP DisposeCadenaEnlazada

PROC BuscarIdentificadorCE              ; numero identificacion 008
.CODE 
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, CeroLocales             ; espacio para locales

      mov  eax, NIL                     ; Inicializa la busqueda en NIL
      mov  ebx, [ EBP+ParametroB ]      ; revisa el IdentificadorCE
      cmp  ebx, 0                       ; verifica no nulo
      je   SalidaCiclo008               ; si es nulo eax es NIL
      mov  eax, [ EBP+ParametroA ]      ; lee el primer puntero de cadena
CicloBusqueda008:
      cmp  eax, NIL                     ; verifica NIL
      je   SalidaCiclo008               ; si es NIL termina la busqueda
      mov  edx, [ EAX+IdentificadorCE ] ; lee el IdentificadorCE en edx
      cmp  edx, ebx                     ; compara con ParametroB
      je   SalidaCiclo008               ; si es igual entonces Exito
      mov  eax, [ EAX+SiguienteCE ]     ; lectura de siguiente puntero
      jmp CicloBusqueda008              ; repite ciclo
SalidaCiclo008:

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  DosParametros                ; retorno liberacion de parametros
ENDP BuscarIdentificadorCE

.CODE
PROC EscribirRegistroFile               ; numero identificacion 009
.CODE 
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, CeroLocales             ; espacio para locales
                                        ; ParametroA = Handle de File
                                        ; ParametroB = Puntero a RECORD      
                                        ; Nota: el file debe estar
                                        ; abierto para escritura
                                        ; en la posicion deseada

      mov  esi, [ EBP+ParametroB ]      ; en esi mem source
      mov  eax, esi                     ; lectura de tamano
      RL( CampoBase )                   ; en ParametroA^.CampoBase
      mov  ecx, eax                     ; tamano en ecx
      mov  ebx, [ EBP+ParametroA ]      ; ebx con Handle
      call BlockWrite                   ; lectura de archivo
      jnc  Exito009                     ; jc es ERROR
      mov  ErrorArchivo, TRUE           ; Bandera de errores de Archivo
Exito009:

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  DosParametros                ; retorno liberacion de parametros
ENDP EscribirRegistroFile

.CODE
PROC LeerRegistroFile                   ; numero identificacion 010
.DATA
      Intermedio010             dd 0
      PunteroPivote010          dd 0
.CODE 
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, CeroLocales             ; espacio para locales
                                        ; ParametroA = Handle de File
                                        ; OUT eax    =
                                        ;       Puntero a nuevo RECORD
                                        ; nota : File abierto para lectura
                                        ; en la posicion adecuada                                    

      mov  edi, OFFSET Intermedio010    ; edi mem dest para lectura de File
      mov  ecx, 4                       ; ecx tamano de lectura 
      mov  ebx, [ EBP+ParametroA ]      ; ebx con Handle
      call BlockRead                    ; lectura de archivo
      jc   Error010                     ; jc es ERROR
      push Intermedio010                ; tamano de REGISTRO leido de File
      call NewRegistro                  ; crea un puntero a RECORD
      mov  PunteroPivote010, eax        ; guarda el puntero en DATA
      mov  edi, eax                     ; en edi mem dest
      add  edi, 4                       ; los primeros 4 bytes ya se leyeron
      mov  ecx, Intermedio010           ; tamano de lectura en File
      sub  ecx, 4                       ; menos el CampoBase que ya se leyo
      mov  ebx, [ EBP+ParametroA ]      ; en ebx el Handle
      call BlockRead                    ; lectura del archivo
      jnc  Fin010                       ; jc es ERROR
      push OFFSET PunteroPivote010      ; VAR para liberacion de Memoria
      call DisposeRegistro              ; lo elimina por error en File
Error010:
      mov  ErrorArchivo, TRUE           ; Bandera de Error en File
      mov  PunteroPivote010, NIL        ; si Error entonces NIL        
Fin010:
      mov  eax, PunteroPivote010        ; en eax el puntero a nuevo RECORD

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  UnParametro                  ; retorno liberacion de parametros
ENDP LeerRegistroFile    

.CODE
PROC EscribirCadenaEnlazadaFile         ; numero identificacion 011
.CODE 
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, CeroLocales             ; espacio para locales
                                        ; ParametroA = Handle de File
                                        ; ParametroB = 
                                        ;       Puntero a CadenaEnlazada      
                                        ; Nota: el file debe estar
                                        ; abierto para escritura
                                        ; en la posicion deseada

      mov  eax, [ EBP+ParametroB ]      ; comienza leyendo como un registro
      push eax                          ; puntero a inicio
      mov  eax, [ EBP+ParametroA ]      ; Handle 
      push eax                          ; dos parametros en total
      call EscribirRegistroFile         ; llamada a lectura de RECORD
      cmp  ErrorArchivo, TRUE           ; verificar ERROR
      je   Error011                     ; si error fin
      mov  eax, [ EBP+ParametroB ]      ; puntero a Cadena
      RL( PunteroDatoCE )               ; lee PunteroDatoCE en Cadena
      cmp  eax, NIL                     ; si es NIL no hace nada 
      je   IgnorarDato011               ; orden de salto si NIL  
      push eax                          ; PunteroDatoCE
      mov  eax, [ EBP+ParametroA ]      ; Handle
      push eax                          ; total dos parametros
      call EscribirRegistroFile         ; PunteroDatoCE se lee como RECORD
      cmp  ErrorArchivo, TRUE           ; verifica error
      je   Error011                     ; salto si error
IgnorarDato011:
      mov  eax, [ EBP+ParametroB ]      ; puntero a Cadena
      RL( SiguienteCE )                 ; lee SiguienteCE
      cmp  eax, NIL                     ; si NIL
      je   IgnorarRecursivo011          ; termina recursividad
      push eax                          ; SiguienteCE al stack
      mov  eax, [ EBP+ParametroA ]      ; tambien Handle
      push eax                          ; dos parametros en total
      call EscribirCadenaEnlazadaFile   ; lectura recursiva
Error011:
IgnorarRecursivo011:

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  DosParametros                ; retorno liberacion de parametros
ENDP EscribirCadenaEnlazadaFile

.CODE
PROC LeerCadenaEnlazadaFile             ; numero identificacion 012
.DATA
  Interno012                    dd 0    ; variable DATA no recursivo
                                        ; para PROC dispose de datos
                                        ; requiere OFFSET 4 bytes
.CODE 
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, UnLocal                 ; espacio para locales
                                        ; ParametroA = Handle de File
                                        ; Nota: el file debe estar
                                        ; abierto para lectura
                                        ; en la posicion deseada

      mov  eax, NIL                     ; inicializa respuesta en NIL
      mov  [ EBP+LocalA ], eax          ; la respuesta en LocalA
      mov  eax, [ EBP+ParametroA ]      ; Handle
      push eax                          ; preparacion lectura
      call LeerRegistroFile             ; se lee como RECORD
      mov  [ EBP+LocalA ], eax          ; puntero se guarda en LocalA
      cmp  ErrorArchivo, TRUE           ; verifica error
      je   ErrorA012                    ; si error es fin
      RL( PunteroDatoCE )               ; lee PunteroDatoCE
      cmp  eax, NIL                     ; NIL unico dato con sentido
      je   IgnorarDato012               ; otro caso se ignora
      mov  eax, [ EBP+ParametroA ]      ; recurriendo a lectura
      push eax                          ; secuencial primero        
      call LeerRegistroFile             ; primero de PunteroDatoCE
      mov  edx, eax                     ; cuyo puntero se guarda en edx
      cmp  ErrorArchivo, TRUE           ; se verifica error
      je   ErrorB012                    ; si error se libera en RAM cadena
      mov  eax, [ EBP+LocalA ]          ; Puntero a Cadena
      RG( PunteroDatoCE, edx )          ; se guarda edx en PunteroDatoCE
IgnorarDato012:
      mov  eax, [ EBP+LocalA ]          ; Puntero a Cadena
      RL( SiguienteCE )                 ; se lee SiguienteCE 
      cmp  eax, NIL                     ; si es NIL
      je   Fin012                       ; fin recursividad
      mov  eax, [ EBP+ParametroA ]      ; si no lo es su valor actual
      push eax                          ; se ignora y con HANDLE
      call LeerCadenaEnlazadaFile       ; se lee secuencial y recursivo
      mov  edx, eax                     ; puntero al nuevo en edx
      cmp  ErrorArchivo, TRUE           ; verifica error
      je   ErrorC012                    ; si error destruye dato y self
      mov  eax, [ EBP+LocalA ]          ; puntero a Cadena
      RG( SiguienteCE, edx )            ; guarda edx en SiguienteCE
      jmp   Fin012                      ; fin de proceso        
ErrorC012:
      mov  eax, [ EBP+LocalA ]          ; para destruir PunteroDatoCE
      RL( PunteroDatoCE )               ; se lee
      cmp  eax, NIL                     ; se verifica NIL
      je   ErrorB012                    ; en ese caso Dato se ignora
      mov  Interno012, eax              ; si no se utiliza 
      push OFFSET Interno012            ; Interno012 como pivote para
      call DisposeRegistro              ; liberar de RAM el dato
ErrorB012:
      mov  eax, [ EBP+LocalA ]          ; ahora puntero a cadena
      mov  Interno012, eax              ; nuevamente Interno012
      push OFFSET Interno012            ; como pivote para
      call DisposeRegistro              ; liberar de RAM cadena
ErrorA012:
      mov  eax, NIL                     ; y como es error asigna NIL
      mov  [ EBP+LocalA ], eax          ; a la respuesta
Fin012:
      mov  eax, [ EBP+LocalA ]          ; al final se para respuesta a eax

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  UnParametro                  ; retorno liberacion de parametros
ENDP LeerCadenaEnlazadaFile    

.CODE
PROC IdentificadorMayorCadenaEnlazada   ; numero identificacion 013
.CODE 
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, CeroLocales             ; espacio para locales
                                        ; ParametroA = 
                                        ;       puntero a CadenaEnlazada
                                        ; OUT eax    = IdentificadorMayor
                                        ;       0 si ParametroA es NIL

      xor  edx, edx                     ; edx guarda resultado inicial 0
      mov  eax, [ EBP+ParametroA ]      ; eax con Puntero a Cadena
RepiteCiclo013:
      cmp  eax, NIL                     ; si se llega a NIL
      je   FinCiclo013                  ; fin de ciclo
      RL( IdentificadorCE )             ; se lee IdentificadorCE
      cmp  eax, edx                     ; se compara con resultado actual
      jl   IgnorarMayor013              ; si es menor se ignora
      mov  edx, eax                     ; si es mayor se guarda
IgnorarMayor013:
      mov  eax, [ EBP+ParametroA ]      ; puntero a cadena
      RL( SiguienteCE )                 ; se busca el SiguienteCE
      mov  [ EBP+ParametroA ], eax      ; y se guarda en ParametroA
      jmp  RepiteCiclo013               ; repite el ciclo
FinCiclo013:
      mov  eax, edx                     ; resultado en eax

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  UnParametro                  ; retorno liberacion de parametros
ENDP IdentificadorMayorCadenaEnlazada

.CODE
PROC GemeloRegistro                     ; numero identificacion 015
.CODE 
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, DosLocales              ; espacio para locales
                                        ; ParametroA =
                                        ;       puntero a Registro
                                        ; OUT eax    =
                                        ;       puntero a gemelo
                                        ; Nota: NIL devuelve NIL

      mov  eax, [ EBP+ParametroA ]      ; carga puntero a Registro
      cmp  eax, NIL                     ; si es NIL no hace nada
      je   IgnorarGemelo015             ; salto a fin de PROC
      RL( CampoBase )                   ; lee el tamano del Registro
      mov  [ EBP+LocalA ], eax          ; lo guarda en LocalA
      push eax                          ; prepara el stack
      call NewRegistro                  ; para crear una copia
      mov  [ EBP+LocalB ], eax          ; guarda el nuevo Registro
      push es                           ; edi trabaja en ES con "rep movsb"
      xor  eax, eax                     ; pero se necesita
      mov  ax, ds                       ; que sea en DS
      mov  es, ax                       ; asi que le cambiamos el valor
      mov  ecx, [ EBP+LocalA ]          ; recupera el tamano  ecx
      mov  esi, [ EBP+ParametroA ]      ; recupera la fuente  esi
      mov  edi, [ EBP+LocalB ]          ; recupera el destino edi
      cld                               ; incremento de edi-esi
      rep  movsb                        ; transferencia de datos
      pop  es                           ; reestablece ES modificado
      mov  eax, [ EBP+LocalB ]          ; salida nuevo puntero en eax
IgnorarGemelo015:

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  UnParametro                  ; retorno liberacion de parametros
ENDP GemeloRegistro     

.CODE
PROC GemeloCadenaEnlazada               ; numero identificacion 016
.CODE 
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, UnLocal                 ; espacio para locales
                                        ; ParametroA =
                                        ;       puntero a CadenaEnlazada
                                        ; OUT eax    =
                                        ;       puntero a Gemelo

                                        ; VAR LocalA = 
                                        ;       preparacion de respuesta

      mov  eax, NIL                     ; valor NIL si ParametroA es NIL
      mov  [ EBP+LocalA ], eax          ; NIL inicial en LocalA
      mov  eax, [ EBP+ParametroA ]      ; lee el ParametroA
      cmp  eax, NIL                     ; si es NIL termina
      je   FinGemelo016                 ; NIL como salida
      push eax                          ; coloca el puntero en Stack
      call GemeloRegistro               ; primero lo copia como Registro
      mov  [ EBP+LocalA ], eax          ; guarda copia en LocalA
      RL( PunteroDatoCE )               ; lee el PunteroDatoCE
      cmp  eax, NIL                     ; si es NIL
      je   IgnorarDato016               ; no es necesario copiarlo
      push eax                          ; si no se pone en Stack
      call GemeloRegistro               ; y se copia
      mov  edx, eax                     ; antes de guardar
      mov  eax, [ EBP+LocalA ]          ; se recupera LocalA
      RG( PunteroDatoCE, edx )          ; para ubicar PunteroDatoCE
IgnorarDato016:
      mov  eax, [ EBP+LocalA ]          ; se lee otra vez la nueva copia
      RL( SiguienteCE )                 ; el campo SiguienteCE
      cmp  eax, NIL                     ; si es NIL no hay siguiente
      je   FinGemelo016                 ; Cadena y se termina
      push eax                          ; otro caso se coloca en Stack
      call GemeloCadenaEnlazada         ; y recursivamente se copia
      mov  edx, eax                     ; antes de guardar
      mov  eax, [ EBP+LocalA ]          ; se recupera LocalA
      RG( SiguienteCE, edx )            ; para ubicar en SiguienteCE
FinGemelo016:
      mov  eax, [ EBP+LocalA ]          ; LocalA se pasa a respuesta final

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  UnParametro                  ; retorno liberacion de parametros
ENDP GemeloCadenaEnlazada

PROC NewMatrizVariable                  ; numero identificacion 017
.CODE 
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, UnLocal                 ; espacio para locales
                                        ; ParametroA = TotalFilas
                                        ; ParametroB = TotalColumnas
                                        ; ParametroC = EspacioElemento
                                        ; OUT eax    = direccion de Matriz

      mov  eax, [ EBP+ParametroC ]      ; y lee EspacioElemento
      push eax                          ; lo pone en Stack
      mov  eax, [ EBP+ParametroA ]      ; lee el TotalFilas
      mov  ebx, [ EBP+ParametroB ]      ; lee el TotalColumnas
      mul  ebx                          ; TotalFilas*TotalColumnas
      push eax                          ; es TamanoVector
      call NewArrayVariable             ; y crea como Array
      mov  [ EBP+LocalA ], eax          ; y lo guarda en LocalA
      mov  ebx, [ EBP+ParametroA ]      ; TotalFilas se guarda
      RG( TotalFilas, ebx )             ; en RECORD
      mov  eax, [ EBP+LocalA ]          ; puntero a Matriz
      mov  ebx, [ EBP+ParametroB ]      ; TotalColumnas
      RG( TotalColumnas, ebx )          ; se guarda en RECORD
      mov  eax, [ EBP+LocalA ]          ; devuelve puntero          
 
      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  TresParametros               ; retorno liberacion de parametros
ENDP NewMatrizVariable

PROC DisposeMatrizVariable              ; numero identificacion 018
                                        ; liberar de memoria
                                        ; una MatrizVariable
.CODE 
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, CeroLocales             ; espacio para locales
                                        ; ParametroA = 
                                        ;   ByRef DireccionPuntero
                                        ; no OUT

      mov  eax, [ EBP+ParametroA ]      ; en eax la direccion del puntero
      push eax                          ; prepara parametro para call
      call DisposeRegistro              ; mismo metodo de Dispose

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  UnParametro                  ; retorno liberacion de parametros
ENDP DisposeMatrizVariable

PROC ProcMP                             ; numero de identificacion 019
                                        ; eax           =
                                        ;       puntero a MatrizVariable
                                        ; ebx           = Numero Fila
                                        ; ecx           = Numero Columna
                                        ; OUT eax       =
                                        ;       puntero a la casilla

      push eax                          ; coloca puntero a Matriz en Stack
      mov  eax, [ EAX+TotalColumnas ]   ; lee el TotalColumnas
      dec  ebx                          ; corrige a comienzo 0
      mul  ebx                          ; NumeroColumnas*TotalFilas
      add  eax, ecx                     ; suma Numero Columna
      dec  eax                          ; disminuye en 1
      pop  ebx                          ; recupera puntero a MatrizVariable
      mov  ecx, [ EBX+EspacioElemento ] ; lee el EspacioElemento
      mul  ecx                          ; EspacioElemento*Posicion
      add  eax, ebx                     ; suma el puntero a MatrizVariable
      add  eax, MemoriaVector           ; luego suma MemoriaVector
      ret                               ; y regresa        
ENDP ProcMP

PROC ApuntarCasillaMatriz               ; numero de identificacion 020
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, UnLocal                 ; espacio para locales
                                        ; ParametroA =
                                        ;       puntero a MatrizVariable
                                        ; ParametroB =
                                        ;       Numero Fila
                                        ; ParametroC =
                                        ;       Numero Columna
                                        ; OUT eax    =
                                        ;       puntero a la casilla

                                        ; VAR LocalA =
                                        ;       intermediario de calculo
                                        ;       direccion final

      mov  eax, [ EBP+ParametroA ]      ; puntero a Matriz
      RL( TotalColumnas )               ; el Matriz.TotalColumnas
      mov  ebx, [ EBP+ParametroB ]      ; lee NumeroFila
      dec  ebx                          ; NumeroFila-1        
      mul  ebx                          ; TotalColumnas*( NumeroFila-1 )
      add  eax, [ EBP+ParametroC ]      ; suma Columna
      dec  eax                          ; y resta 1
      mov  [ EBP+LocalA ], eax          ; guarda calculo provisional LocalA
      mov  eax, [ EBP+ParametroA ]      ; lee puntero a Matriz
      RL( EspacioElemento )             ; Matriz.EspacioElemento
      mov  ebx, [ EBP+LocalA ]          ; Posicion (referencia 0)
      mul  ebx                          ; EspacioElemento*Posicion
      add  eax, [ EBP+ParametroA ]      ; suma el puntero a Matriz
      add  eax, MemoriaVector           ; y corrige por MemoriaVector

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  TresParametros               ; retorno liberacion de parametros        
ENDP ApuntarCasillaMatriz
