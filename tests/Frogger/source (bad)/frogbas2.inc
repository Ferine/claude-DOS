.COMMENT
 ****************************************************************************
 FROGBAS2.INC    Para preparar el juego de FROGGER
 ============================================================================
 ****************************************************************************
.MODEL FLAT
.MEM   8192     ; 8 MByte de memoria RAM
.UCU
.NM

.INCLUDE io.inc
.INCLUDE system.inc
.INCLUDE graph1.inc
.INCLUDE frogsys1.inc
.INCLUDE frogbas1.inc

.TYPE   ( MargenPantalla        =  50                                   )

.TYPE  ( FichaEnlazada  = 32, TamanoPunteroFE   =  0, IdentificadorFE =  4
         SiguienteFE    =  8, PunteroDatoFE     = 12, DescriptorFE    = 16
         FilaFE         = 20, ColumnaFE         = 24, ReferenciaFE    = 28 )

.TYPE  ( ReferenciaCiclico      = 32, CampoBaseRC                     =  0
         VelocidadRC            =  4, LimiteActualizableRC            =  8
         ValorMinimoRC          = 12, ValorMaximoRC                   = 16
         SeparacionMinimaRC     = 20, SeparacionMaximaRC              = 24
         IdentificadorLimiteRC  = 28  )

.TYPE  ( ArranqueVehiculo       = 16, CampoBaseAV                     =  0
         IdentificadorAV        =  4, ColumnaAV                       =  8
         DescriptorAV           = 12    )

.TYPE   ( ActivoPAQ        =  000000001h, VisiblePAQ       =  000000002h
          PantallaPAQ      =  000000004h, FichaPAQ         =  000000008h
          CiclicoPAQ       =  000000010h, TroncoPAQ        =  000000020h
          SoportePAQ       =  000000040h, TortugaPAQ       =  000000080h
          SumergiblePAQ    =  000000100h, EstadoAPAQ       =  000000200h
          EstadoBPAQ       =  000000400h, EstadoCPAQ       =  000000800h
          EstadoDPAQ       =  000001000h, EstadoEPAQ       =  000002000h
          SumergibleActivoPAQ           =  000004000h
          ReinicioMarinoPAQ             =  000008000h
          FijoFinPAQ                    =  000010000h
          CocodriloPAQ     =  000020000h, MoscaPAQ         =  000040000h
          AnfibioPAQ       =  000080000h, ArribaPAQ        =  000100000h
          AbajoPAQ         =  000200000h, DerechaPAQ       =  000400000h
          IzquierdaPAQ     =  000800000h, SolidarioPAQ     =  001000000h
          SaltoPAQ         =  002000000h, DerrotadoPAQ     =  004000000h )

.PUBLIC .DATA
  BanderaTecla       dd  FALSE       ; para indicar tecla de usuario activa
  BanderaTeclaEspecial
                     dd  FALSE       ; para indicar una tecla especial
  TeclaOpcion        db  0           ; reporta la opcionde usuario

.PUBLIC .DATA
  NivelPaquete       dd  1           ; numero de pantalla
  PunteroPaquete     dd  NIL         ; contiene el paquete de fichas
  PunteroCentral     dd  NIL         ; contiene la imagen central
  PunteroPantalla    dd  0           ; puntero a pantalla principal
  ActivaPantalla     dd  FALSE       ; programa modalidad grafica o texto
  BanderaPantalla    dd  0           ; activa y desactiva pantalla
  FinPrograma        db  'Gracias por comprar un producto tan caro,'
                     db  ' yo no lo hubiera hecho',0
                                    ; mensaje final de salida

.CODE
PROC CicloTemporalGeneral               ; numero identificacion 032
.DATA
  TiempoArranquePrincipal032            dd      0
                                        ; permite una espera para el
                                        ; proceso principal ciclico
  TiempoSeparacionPrincipal032          dd      50
                                        ; espacio de tiempo TOM en el
                                        ; proceso principal repetitivo
  TiempoUltimoPrincipal032              dd      0
                                        ; para mantener el ultimo tiempo
                                        ; en trozos completos es decir
                                        ; T0+ARRANQUE+n*Separacion
  TiempoArranqueUsuario032              dd      0
                                        ; permite un desfase en la
                                        ; primera lectura de usuario
  TiempoSeparacionUsuario032            dd      150
                                        ; tiempo de separacion de
                                        ; consultas de usuario
  TiempoUltimoUsuario032                dd      0
                                        ; para mantener el ultimo tiempo
                                        ; de consulta en trozos completos
                                        ; es decir T0+ARRANQUE+n*Separacion
  BanderaSalida032                      dd      FALSE
                                        ; para consultar posible salida

.CODE
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, UnLocal                 ; espacio para locales
                                        ; LocalA : TiempoActual
                              
      call Tiempo                       ; llama al tiempo TOM
      mov  [ EBP+LocalA ], eax          ; y lo guarda en LocalA
      mov  BanderaSalida032, FALSE      ; FALSE a bandera de salida
ReprogramarInicios032:
      mov  eax, [ EBP+LocalA ]          ; carga LocalA como T0
      mov  TiempoUltimoPrincipal032, eax
                                        ; en TiempoUltimoPrincipal032
      mov  TiempoUltimoUsuario032, eax
                                        ; y en TiempoUltimoUsuario032
RepiteCicloPrincipal032:
      call Tiempo                       ; cada ciclo llama el tiempo
      mov  ebx, [ EBP+LocalA ]          ; y reactualiza LocalA
      mov  [ EBP+LocalA ], eax          ; verifica el cambio de dia
      cmp  eax, ebx                     ; en ese caso se requiere
      jl   ReprogramarInicios032        ; resetear el T0
      mov  eax, [ EBP+LocalA ]          ; nuevamente TiempoActual
      mov  ebx, TiempoUltimoPrincipal032
                                        ; menor TiempoUltimoPrincipal032
      sub  eax, ebx                     ; para ver el DeltaT
      mov  ebx, TiempoArranquePrincipal032
                                        ; se lee TiempoArranquePrincipal032
      cmp  ebx, 0                       ; si es 0 se ignora
      je   IgnorarArranque032           ; pero si no lo es
      cmp  eax, ebx                     ; debe esperarse el Arranque
      jl   IgnorarPrincipal032          ; que se verifica com cmp
      add  TiempoUltimoPrincipal032,ebx ; si arranque se actualiza
      mov  TiempoArranquePrincipal032,0 ; TiempoUltimoPrincipal032
      mov  eax, [ EBP+LocalA ]          ; y 0 de Arranque para desactivarlo
      push eax                          ; se para TiempoActual
      call ProcedimientoPrincipalCiclo  ; a ProcedimientoPrincipalCiclo
      jmp  IgnorarPrincipal032          ; para a revision de siguiente
IgnorarArranque032:
      mov  ebx, TiempoSeparacionPrincipal032
                                        ; despues del arranque
      cmp  eax, ebx                     ; se verifica separacion de tiempo
      jl   IgnorarPrincipal032          ; si es muy pequena se salta
      add  TiempoUltimoPrincipal032, ebx
                                        ; si paso separacion se acumula
      mov  eax, [ EBP+LocalA ]          ; en TiempoUltimoPrincipal032
      push eax                          ; se para TiempoActual
      call ProcedimientoPrincipalCiclo  ; a ProcedimientoPrincipal032
      mov  BanderaSalida032, eax        ; que devuelve en eax BanderaSalida
IgnorarPrincipal032:
      mov  eax, [ EBP+LocalA ]          ; ahora sigue el usuario
      mov  ebx, TiempoUltimoUsuario032  ; por resta con TiempoUltimoUsuario
      sub  eax, ebx                     ; se obtiene DeltaT para usuario
      mov  ebx, TiempoArranqueUsuario032
                                        ; y se le compra con el arranque
      cmp  ebx, 0                       ; si es 0 se ignora
      je   IgnorarArranqueUsuario032    ; caso contrario se
      cmp  eax, ebx                     ; verifica que se haya
      jl   SaltarFinalizar032           ; llegano o no al momento de
      add  TiempoUltimoUsuario032,ebx   ; arranque, en tal caso
      mov  TiempoArranqueUsuario032,0   ; se actualiza TiempoUltimo
      mov  eax, [ EBP+LocalA ]          ; y se desactiva el arranque con 0
      push eax                          ; se pasa TiempoActual a
      call ProcedimientoUsuarioCiclo    ; PROC ProcedimientoUsuarioCiclo
      jmp  SaltarFinalizar032           ; y se pasa a repetir ciclo
IgnorarArranqueUsuario032:
      mov  ebx, TiempoSeparacionUsuario032
                                        ; despues del arranque vienen
      cmp  eax, ebx                     ; los llamados cada Separacion
      jl   SaltarFinalizar032           ; si no es suficiente repite
      add  TiempoUltimoUsuario032, ebx  ; si paso Separacion se actualiza
      mov  eax, [ EBP+LocalA ]          ; TiempoUltimoUsuario032 y
      push eax                          ; se pasa TiempoActual
      call ProcedimientoUsuarioCiclo    ; a ProcedimientoUsuarioCiclo
      cmp  eax, TRUE                    ; este puede forzar salida (ESC)
      jne  SaltarFinalizar032           ; pasando TRUE a eax
      mov  BanderaSalida032, TRUE       ; y luego BanderaSalida
SaltarFinalizar032:
      cmp  BanderaSalida032, FALSE      ; si BanderaSalida es FALSE
      je   RepiteCicloPrincipal032      ; se repite ciclo otra vez

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  CeroParametros               ; retorno liberacion de parametros
ENDP CicloTemporalGeneral

.CODE
PROC SalidaError                        ; numero identificacion 030
.CODE
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, CeroLocales             ; espacio para locales
                                        ; ParametroA :
                                        ;       puntero a mensaje de error

      cmp  BanderaPantalla, TRUE        ; verificando la pantalla activa
      jne  IgnorarSetText030            ; si no esta activa ignorar
      call SetTextMode                  ; para desactivar el modo texto
      mov  BanderaPantalla, FALSE       ; coloca FALSE en BanderaPantalla
IgnorarSetText030:
      mov  edi, [ EBP+ParametroA ]      ; ParametroA tiene un mensaje
      cmp  edi, 0                       ; si es 0 se usa texto defecto
      jne  IgnorarMensajeGeneral030     ; caso contrario se mantiene edi
      mov  edi, OFFSET MensajeErrorGeneral
                                        ; caso error general
IgnorarMensajeGeneral030:
      call SystemWriteLn                ; escribe mensaje de error
      EscribirEnter                     ; espera enter de usuario
      mov  edi, OFFSET FinPrograma      ; mensaje despedida
      call SystemWriteLn                ; impreso en pantalla
      mov  ah,4ch                       ; orden de salida
      int  21h                          ; interrupcion de salida
ENDP SalidaError

.CODE
PROC Tiempo                             ; numero identificacion 031
.CODE
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, DosLocales              ; espacio para locales
                                        ; LocalA  : Cientos de segundos
                                        ; LocalB  : Segundos
                                        ; OUT EAX :
                                        ;       Tiempo Tom total desde
                                        ;       cero o medianoche

      xor  eax, eax                     ; anula eax para orden DOS
      mov  ah, 2CH                      ; orden de obtener tiempo
      int  21H                          ; con interrupcion 21H del DOS
      xor  eax, eax                     ; CH horas, CL minutos
      mov  al, dl                       ; DH segundos, DL centesimos
      mov  [ EBP+LocalA ], eax          ; asigna LocalA = centesimos
      mov  al, dh                       ; asigna LocalB = segundos
      mov  [ EBP+LocalB ], eax          ; asigna EAX    = horas
      mov  al, ch                       ; asigna EBX    = minutos
      xor  ebx, ebx                     ; para esto ultimo anula ebx
      mov  bl, cl                       ; y luego carga
      mov  ecx, 60                      ; eax = eax*60+ebx
      mul  ecx                          ; para obtener los minutos
      add  eax, ebx                     ; completos
      mov  ecx, 60                      ; luego eax = eax*60+LocalB
      mul  ecx                          ; para calcular los segundos
      mov  ebx, [ EBP+LocalB ]          ; completos
      add  eax, ebx                     ; cada segundo tiene 814 Tomes
      mov  ecx, 814                     ; por lo que se multiplica
      mul  ecx                          ; dicho factor
      mov  ebx, eax                     ; ademas hay que corregir        
      mov  eax, [ EBP+LocalA ]          ; los centesimos
      mov  ecx, 814                     ; centesimos*814 DIV 100
      mul  ecx                          ; para obtener el equivalente
      mov  ecx, 100                     ; en tiempo TOM
      div  ecx                          ; y sumarlo al resultado
      add  eax, ebx                     ; resultado final en EAX

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  CeroParametros               ; retorno liberacion de parametros
ENDP Tiempo

.CODE
PROC ProcedimientoPrincipalCiclo        ; numero identificacion 033
.DATA
      BanderaPrimero033                  dd TRUE

.CODE
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, CeroLocales             ; espacio para locales
                                        ; ParametroA    : TiempoActual

      cmp  BanderaPrimero033, TRUE      ; detecta si es primera vez
      jne  IgnorarPrimero033            ; si no lo es ignora
      mov  BanderaPrimero033, FALSE     ; ya no es primera vez
IgnorarPrimero033:
      cmp  BanderaPantalla, TRUE        ; verifica modo grafico
      jne  ModoTexto033                 ; si no lo es pasa a ModoTexto033
      mov  eax, [ EBP+LocalA ]          ; lee el TiempoActual
      push eax                          ; y lo pasa de parametro al
      call ActualizarPunteroCentral     ; PROC ActualizarPunteroCentral
      push 0                            ; ahora coloca el PunteroCentral
      push MargenPantalla+1             ; centrado en PunteroPantalla
      push 1                            ; segun el .TYPE MargenPantalla
      push NIL                          ; mediante un llamado a 
      push PunteroPantalla              ; PutImageVirtual que tiene
      push PunteroCentral               ; seis parametros
      call PutImageVirtual              ; llamado al PROC respectivo
      push PunteroPantalla              ; ahora despliega la pantalla
      call PonerPantalla                ; con poner pantalla
      jmp  FinModoTexto033              ; fin de rutina grafica en ciclo
ModoTexto033:
FinModoTexto033:
      mov  eax, FALSE                   ; devuelve FALSE todavia no sale

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  UnParametro                  ; retorno liberacion de parametros
ENDP ProcedimientoPrincipalCiclo

.CODE
PROC LeerTeclaActiva                    ; numero identificacion 035
.CODE
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, CeroLocales             ; espacio para locales
                                        ; OUT ( variables globales )
                                        ; BanderaTecla  : Tecla apretada
                                        ; BanderaTeclaEspecial
                                        ;               : es tecla extendida
                                        ; TeclaOpcion   : caracter de tecla

      mov  BanderaTecla, FALSE          ; se supone sin tecla pendiente
      mov  BanderaTeclaEspecial, FALSE  ; y que no es especial
      call SystemKeyPressed             ; SystemKeyPressed detecta tecla
      jz   FinProc035                   ; si no la detecta termina
      mov  BanderaTecla, TRUE           ; tecla detectada
      call SystemGetKey                 ; lectura de tecla
      cmp  al, 0                        ; verifica codigo especial
      jne  IgnorarTeclaEspecial035      ; si no especial la guarda
      mov  BanderaTeclaEspecial, TRUE   ; caso tecla extendida
      call SystemGetKey                 ; tecla extendida se lee dos veces
IgnorarTeclaEspecial035:
      mov  TeclaOpcion, al              ; guarda la tecla leida
FinProc035:

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  CeroParametros               ; retorno liberacion de parametros
ENDP LeerTeclaActiva

.CODE
PROC LeerFichaArchivo                   ; numero identificacion 037
.CODE
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, DosLocales              ; espacio para locales
                                        ; ParametroA    : ByRef
                                        ;       OFFSET NombreArchivo
                                        ; OUT   eax     : puntero a
                                        ;       registro leido de ficha
                                        ; Variables Locales
                                        ; LocalA        : Handle
                                        ; LocalB        : puntero a Ficha

      mov  edi, [ EBP+ParametroA ]      ; carga el nombre del archivo
      call OpenFileToRead               ; abre el archivo
      jc   ErrorLecturaArchivo037       ; bandera carry se activa si error
      mov  [ EBP+LocalA ], ebx          ; Handle en ebx que se pasa a
      push ebx                          ; LocalA y como parametro
      call LeerRegistroFile             ; de leer Registro
      cmp  ErrorArchivo, TRUE           ; verifica error de lectura
      je   ErrorLecturaArchivo037       ; si error devuelve NIL
      mov  [ EBP+LocalB ], eax          ; eax contiene puntero al registro
      mov  ebx, [ EBP+LocalA ]          ; que se guarda en LocalB
      call CloseFile                    ; con LocalA se aplica CloseFile
      jmp  Salida037                    ; rumbo a fin y Out Eax
ErrorLecturaArchivo037:
      mov  ErrorArchivo, TRUE           ; informa de Error con un TRUE
      mov  eax, NIL                     ; ademas pasa NIL como salida eax
      mov  [ EBP+LocalB ], eax          ; el NIL se pasa a LocalB
Salida037:
      mov  eax, [ EBP+LocalB ]          ; LocalB contiene direccion ficha

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  UnParametro                  ; retorno liberacion de parametros
ENDP LeerFichaArchivo

.CODE
PROC ProcesarFichaCiclica               ; numero identificacion 038
.CODE
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, SeisLocales             ; espacio para locales
                                        ; ParametroA    : puntero a
                                        ;       CadenaEnlazada de ficha
                                        ; ParametroB    : TiempoActual
                                        ; OUT EAX       : boolean
                                        ;       TRUE indica reinicio de ciclo
                                        ; Variables Locales
                                        ; LocalA        : Direccion Boolean
                                        ; LocalB        : Nueva Columna
                                        ; LocalC        : Puntero Referencia
                                        ; LocalD        : Velocidad
                                        ; LocalE        :
                                        ;       Boolean Nuevo Limite
                                        ; LocalF        :
                                        ;       Salida que indica
                                        ;       reinicio de ciclo

      mov  eax, FALSE                   ; FALSE a eax
      mov  [ EBP+LocalF ], eax          ; asume que no hay que reiniciar
      mov  eax, [ EBP+ParametroA ]      ; primero cargar
      RL( ReferenciaFE )                ; LocalC = ParametroA.ReferenciaFE
      mov  [ EBP+LocalC ], eax          ; que es un puntero tipo
      RL( VelocidadRC )                 ; ReferenciaCicliclo
      mov  ebx, TRUE                    ; LocalA = Boolean de
      cmp  eax, 0                       ;  = Signo( LocalC.VelocidadRC )
      jns  VelocidadPositiva038         ; la asignacion se hace con
      mov  ebx, FALSE                   ; un TRUE or FALSE en ebx
VelocidadPositiva038:
      mov  [ EBP+LocalA ], ebx          ; y se asigna a LocalA
      mov  edx, eax                     ; LocalC.VelocidadRC en edx
      mov  eax, [ EBP+ParametroA ]      ; y se carga EAX =
      RL( ColumnaFE )                   ; ParametroA.ColumnaFE
      add  eax, edx                     ; VelocidadRC+ColumnaFE
      mov  [ EBP+LocalB ], eax          ; la nueva columna en LocalB
      mov  ebx, [ EBP+LocalA ]          ; pero hay que verificar limites
      cmp  ebx, TRUE                    ; el limite elegido depende
      jne  PruebaNegativa038            ; del signo (ver LocalA)
      mov  ebx, eax                     ; si es positivo se compara
      mov  eax, [ EBP+LocalC ]          ; LocalB <= ValorMaximoRC
      RL( ValorMaximoRC )               ; si esto es cierto es pasa
      cmp  ebx, eax                     ; a FinPruebaNegativo038
      jle  FinPruebaNegativa038         ; que verifica los limites
      mov  eax, TRUE                    ; eax es pivote para LocalF
      mov  [ EBP+LocalF ], eax          ; LocalF indica salida TRUE
      mov  eax, [ EBP+LocalC ]          ; si LocalB > ValorMaximoRC
      RL( SeparacionMaximaRC )          ; hay que reiniciar el ciclo
      push eax                          ; primero se obtiene un aleatorio
      mov  eax, [ EBP+LocalC ]          ; con RandomLineal entre
      RL( SeparacionMinimaRC )          ; SeparacionMaximaRC..
      push eax                          ; SeparacionMinimaRC (con limites)
      call RandomLineal                 ; este Random se resta
      mov  edx, eax                     ; del LimiteActualizableRC
      mov  eax, [ EBP+LocalC ]          ; esto garantiza que no haya
      RL( LimiteActualizableRC )        ; choque de fichas
      sub  eax, edx                     ; el nuevo valor se guarda
      mov  [ EBP+LocalB ], eax          ; en LocalB, ademas hay que
      jmp  ActualizarLimite038          ; actualizar los limites
PruebaNegativa038:
      mov  ebx, eax                     ; EBX = LocalB
      mov  eax, [ EBP+LocalC ]          ; la idea es comparar
      RL( ValorMinimoRC )               ; LocalB >= ValorMinimoRC
      cmp  ebx, eax                     ; esto produce asignacion rutina
      jge  FinPruebaNegativa038         ; caso contrario la ficha
      mov  eax, TRUE                    ; eax es pivote para LocalF
      mov  [ EBP+LocalF ], eax          ; LocalF contiene salida
      mov  eax, [ EBP+LocalC ]          ; reinicia ciclo
      RL( SeparacionMaximaRC )          ; para ello se genera un aleatorio
      push eax                          ; entre SeparacionMinimaRC..
      mov  eax, [ EBP+LocalC ]          ; SeparcionMaximaRC (con limites)
      RL( SeparacionMinimaRC )          ; utilizando RandomLineal
      push eax                          ; al random se le suma
      call RandomLineal                 ; LimiteActualizableRC
      mov  edx, eax                     ; se utiliza edx como pivote
      mov  eax, [ EBP+LocalC ]          ; para guardar el Random
      RL( LimiteActualizableRC )        ; finalmente se guarda el
      add  eax, edx                     ; resultado en LocalB
      mov  [ EBP+LocalB ], eax          ; que sera al extremo derecho
ActualizarLimite038:
      mov  ebx, [ EBP+LocalB ]          ; en este momento se esta seguro
      mov  eax, [ EBP+LocalC ]          ; que LocalB es un valor extremo
      RG( LimiteActualizableRC, ebx )   ; LimiteActualizableRC = LocalB
      mov  eax, [ EBP+ParametroA ]      ; ademas hay que reactualiza
      RL( IdentificadorFE )             ; IdentificadorLimiteRC
      mov  ebx, eax                     ; que identifica la ficha
      mov  eax, [ EBP+LocalC ]          ; que tiene el LimiteActualizableRC
      RG( IdentificadorLimiteRC, ebx )  ; luego de hecho esto
      jmp  Salida038                    ; se procede al final
FinPruebaNegativa038:
      mov  eax, [ EBP+LocalC ]          ; el carro simplemente avanza
      RL( IdentificadorLimiteRC )       ; pero si se trata de la ficha
      mov  ebx, eax                     ; ultimo de carril
      mov  eax, [ EBP+ParametroA ]      ; IdentificadorFE =
      RL( IdentificadorFE )             ;       IdentificadorLimiteRC
      cmp  eax, ebx                     ; es necesario, probablemente
      jne  Salida038                    ; reactualizar el limite
      mov  eax, [ EBP+LocalC ]          ; primero se guarda simplemente
      mov  edx, [ EBP+LocalB ]          ; LimiteActualizableRC = LocalB
      RG( LimiteActualizableRC, edx )   ; pero es necesario cerciorarse
      mov  eax, [ EBP+LocalA ]          ; que no se ha sobrepasado
      cmp  eax, TRUE                    ; la barrera, pues si se sobrepasa
      jne  LimiteNegativo038            ; la barrera es LimiteActualizableRC
      mov  eax, [ EBP+LocalC ]          ; el signo en LimiteA nos dice
      RL( ValorMinimoRC )               ; si se compara con ValorMinimoRC
      cmp  eax, edx                     ; caso TRUE se prueba
      jge  Salida038                    ; ValorMinimoRC >= LocalB
      mov  ebx, eax                     ; si no es asi ValorMinimoRC
      mov  eax, [ EBP+LocalC ]          ; es el verdadero
      RG( LimiteActualizableRC, ebx )   ; LimiteActualizableRC
      mov  eax, [ EBP+LocalC ]          ; que no corresponde a ninguna ficha
      RG( IdentificadorLimiteRC, 0 )    ; IdentificadorLimiteRC = 0
      jmp  Salida038                    ; se procede a asignacion final
LimiteNegativo038:
      mov  eax, [ EBP+LocalC ]          ; la velocidad es negativa
      RL( ValorMaximoRC )               ; hay que cersiorarse que
      cmp  eax, edx                     ; VelocidadMaximoRC <=
      jle  Salida038                    ;       LimiteActualizableRC
      mov  ebx, eax                     ; caso contrario ValorMaximoRC
      mov  eax, [ EBP+LocalC ]          ; es el verdadero valor
      RG( LimiteActualizableRC, ebx )   ; de LimiteActualizableRC
      mov  eax, [ EBP+LocalC ]          ; que no corresponde a ninguna ficha
      RG( IdentificadorLimiteRC, 0 )    ; IdentificadorLimiteRC
Salida038:
      mov  ebx, [ EBP+LocalB ]          ; la asignacion final
      mov  eax, [ EBP+ParametroA ]      ; es el objetivo basico de PROC
      RG( ColumnaFE, ebx )              ; ColumnaFE = LocalB
      mov  eax, [ EBP+LocalF ]          ; salida boolean de reinicio

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  DosParametros                ; retorno liberacion de parametros
ENDP ProcesarFichaCiclica

.CODE
PROC RandomLineal                       ; numero identificacion 039
                                        ; calcula un numero aleatorio
                                        ; entre dos WORD
                                        ; en cualquier orden incluyendo
                                        ; los valores extremos
.CODE
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, UnLocal                 ; espacio para locales
                                        ; ParametroA    : Valor Minimo
                                        ; ParametroB    : Valor Maximo
                                        ; Variables Locales
                                        ; LocalA        : Bandera de signo

      mov  eax, TRUE                    ; supuesto ParametroB > ParametroA
      mov  [ EBP+LocalA ], eax          ; LocalA es bandera de signo
      mov  eax, [ EBP+ParametroB ]      ; ValorMaximo-ValorMinimo
      mov  ebx, [ EBP+ParametroA ]      ; se utiliza primero
      sub  eax, ebx                     ; para determinar cual es menor
      jns  IgnorarNegativo039           ; si no hay signo bien
      neg  eax                          ; caso contrario
      mov  ebx, FALSE                   ; corrige a FALSE
      mov  [ EBP+LocalA ], ebx          ; el valor de LocalA
IgnorarNegativo039:
      inc  eax                          ; ABS( ValorMaximo-ValorMinimo )+1
      call GetRandom                    ; permite elegir los valores
      mov  ebx, [ EBP+LocalA ]          ; extremos ademas
      cmp  ebx, TRUE                    ; consulta signo
      je   IgnorarCambioSigno039        ; para ver si tiene que cambiarle
      neg  eax                          ; signo al Random
IgnorarCambioSigno039:
      mov  ebx, [ EBP+ParametroA ]      ; se calcula entonces
      add  eax, ebx                     ; EAX=ParametroA+Signo*Random

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  DosParametros                ; retorno liberacion de parametros
ENDP RandomLineal

; Copia textual no original del PROC del ensamblador PASS32 InitRandom
; Se agradece a: Dieter Pawelczak
InitRandom PROC
.DATA
  Rand1         dd      ?
  Rand2         dd      ?
  Rand3         dd      ?
  BIOSSEL       dw      ?
.CODE
  push gs
  mov bx,0040h
  mov ax,0002h
  int 31h                       ; Get Selector For BIOS DATA 0040:0000
  mov BiosSel,ax
  mov GS,AX
  mov EAX,GS:[6ch]              ; Get Bios Timer
  mov Rand1,EAX                 ; Init First Random Var
  or DX,01101101b
  mul dx
  mov Rand2,EAX                 ; Init Second Random Var
  rol EAX,11
  add dx,ax
  mov edx,RAND1
  xor EAX,EDX
  mov Rand3,EAX                 ; Init Third Random Var
  pop gs                        ; restore Zero Selector
  ret
ENDP InitRandom
; Copia textual no original del PROC del ensamblador PASS32 InitRandom
; Se agradece a: Dieter Pawelczak

; Copia textual no original del PROC del ensamblador PASS32 GetRandom
; Se agradece a: Dieter Pawelczak
; Se genera Ramdom en AX en el intervalo 0..(AX-1)
GetRandom PROC                  ; AX = Random Area 0..AX
  push gs
  push bx
  push dx
  push cx
  push ax
  mov ax,BiosSel
  mov GS,AX
  mov EAX,GS:[6ch]              ; Get Bios Timer
  mov Cl,Byte PTR Rand1
  shl eax,Cl
  or al,cl
  or EAX,Rand1
  mov DX,Word PTR Rand2
  mul DX
  SHL Eax,8
  add EAX,Rand2
  XOR EAX,Rand3
  add Eax,Rand1
  push EAX
  mov EAX,Rand2
  mov Rand1,EAX
  mov Eax,Rand3
  mov Rand2,Eax
  pop Eax
  Xadd Rand3,Eax                ; EAX is New Random Var
  pop BX                        ; max size of Randomvar
  mov ECX,EAX                   ; store EAX in ECX
  mov eax,0ffffh
  mul bx                        ; get max Size for division in DX:AX
  shl edx,16
  add eax,edx                   ; EAX is max divident
PrepareForDivision:
  cmp ecx,eax
  jb OkForDivision
  shr ecx,1
  jmp PrepareForDivision

  OkForDivision:
  mov EDX,ECX
  shr EDX,16
  mov AX,CX
  cmp AX,0                     ; dividend zero
  je ZeroDivide
  cmp BX,0                     ; dividend zero
  je ZeroDivide
  div bx                                ; DX:AX  div  BX
ZeroDivide:
  movzx EAX,DX
  pop cx
  pop dx
  pop bx
  pop gs
  ret
ENDP GetRandom
; Copia textual no original del PROC del ensamblador PASS32 GetRandom
; Se agradece a: Dieter Pawelczak

.CODE
PROC AppendCadenaEnlazada               ; numero identificacion 040
.CODE
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, CeroLocales             ; espacio para locales
                                        ; ParametroA    : puntero a
                                        ;       CadenaEnlazada "inicial"
                                        ; ParametroB    : puntero a
                                        ;       CadenaEnlazada "final"
                                        ; OUT EAX       : puntero a
                                        ;       Cadena extendida


      mov  eax, [ EBP+ParametroA ]      ; primero se descarta
      cmp  eax, NIL                     ; que ParametroA = NIL
      je   SalidaNILA040                ; en ese caso salta
CicloUltimoA040:
      mov  ebx, eax                     ; el ciclo avanza en 
      RL( SiguienteFE )                 ; EAX.SiguienteFE
      cmp  eax, NIL                     ; que guarda en ebx candidato
      jne  CicloUltimoA040              ; a ser el ultimo de ParametroA
      mov  edx, [ EBP+ParametroB ]      ; entonces asigna
      mov  [ EBX+SiguienteFE ], edx     ; EBX.SiguienteFE = ParametroB
      mov  eax, [ EBP+ParametroA ]      ; devuelve en EAX = ParametroA
      jmp  Salida040                    ; fin de PROC
SalidaNILA040:
      mov  eax, [ EBP+ParametroB ]      ; devuelve en EAX = ParametroB
Salida040:

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  DosParametros                ; retorno liberacion de parametros
ENDP AppendCadenaEnlazada

.CODE
PROC AppendGemeloCiclico                ; numero identificacion 041
                                        ; genera un gemelo de la primera
                                        ; posicion de una CadenaEnlazada
                                        ; lo coloca al final
                                        ; y cambia IdentificadorFE a
                                        ; IdentificadorFE( ultimodato )+1
                                        ; OUT EAX = ultimo dato para
                                        ; modificar mas
.CODE
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, DosLocales              ; espacio para locales
                                        ; ParametroA    :
                                        ;       puntero a CadenaEnlazada
                                        ; OUT EAX       :
                                        ;       puntero a nuevo en la
                                        ;       posicion ultima de cadena
                                        ; Variables Locales
                                        ; LocalA        : SiguienteFE
                                        ;       de primer dato
                                        ; LocalB        : copia de primer
                                        ;       dato de cadena        

      mov  eax, [ EBP+ParametroA ]      ; eax es inicio de cadena
      cmp  eax, NIL                     ; si es NIL no hace nada
      je   Salida041                    ; caso NIL
      RL( SiguienteFE )                 ; para hacer copia del primero
      mov  [ EBP+LocalA ], eax          ; dato de cadena modificamos
      mov  eax, [ EBP+ParametroA ]      ; SiguienteFE a NIL, guardando
      RG( SiguienteFE, NIL )            ; el verdadero en LocalA
      mov  eax, [ EBP+ParametroA ]      ; esto pues GemeloCadenaEnlazada
      push eax                          ; hace copias de cadenas completas
      call GemeloCadenaEnlazada         ; gemelo en eax
      mov  [ EBP+LocalB ], eax          ; que se guarda en LocalB
      mov  ebx, [ EBP+LocalA ]          ; se reestablece SiguienteFE
      mov  eax, [ EBP+ParametroA ]      ; Primero.SiguienteFE = LocalA        
      RG( SiguienteFE, ebx )            ; y la copia del Primero en LocalB
      mov  eax, [ EBP+ParametroA ]      ; en eax Primer dato de cadena
CicloUltimo041:
      mov  edx, eax                     ; en edx ultimo dato del ciclo
      RL( SiguienteFE )                 ; eax.SiguienteFE
      cmp  eax, NIL                     ; si no es NIL
      jne  CicloUltimo041               ; no hemos llegado al ultimo
      mov  eax, edx                     ; edx contiene el ultimo
      RL( IdentificadorFE )             ; se calcula edx.IdentificadorFE+1
      inc  eax                          ; que va a ser el nuevo
      mov  ecx, eax                     ; identificador de la copia, dicho
      mov  eax, edx                     ; numero se guarda en ecx
      mov  ebx, [ EBP+LocalB ]          ; ebx=LocalB copia del primer dato
      RG( SiguienteFE, ebx )            ; UltimoAnterio.SiguienteFE=LocalB
      mov  eax, [ EBP+LocalB ]          ; LocalB.IdentificadorFE = ecx
      RG( IdentificadorFE, ecx )        ; como se calculo antes        
      mov  eax, [ EBP+LocalB ]          ; OUT eax = nuevo ultimo dato
Salida041:

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  UnParametro                  ; retorno liberacion de parametros
ENDP AppendGemeloCiclico

.CODE
PROC GenerarCiclico                     ; numero identificacion 042
                                        ; genera una lista de fichas
                                        ; tipo FichaEnlazada o mayor tamano
                                        ; el exceso se rellena con ceros
                                        ; PunteroDatoFE una matriz
                                        ; en archivo disco
                                        ; un total de ParametroD fichas
                                        ; iguales numeradas a partir
                                        ; del numero ParametroB
.CODE
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, UnLocal                 ; espacio para locales
                                        ; ParametroA    : ByRef
                                        ;       OFFSET NombreArchivo
                                        ; ParametroB    :
                                        ;       IdentificadorInicial
                                        ; ParametroC    : Tamano de dato
                                        ;       correcto, minimo FichaEnlazada
                                        ; ParametroD    :
                                        ;       Total Copias
                                        ; ParametroE    : descriptor
                                        ; Variables Locales
                                        ; LocalA        : puntero
                                        ;       a cadena en formacion

      mov  eax, [ EBP+ParametroA ]      ; lee el OFFSET a NombreArchivo
      push eax                          ; y coloca en Stack
      call LeerFichaArchivo             ; EAX devuelve puntero a
      push eax                          ; MatrizVariable que sera
      push NIL                          ; PunteroDatoCE en CadenaEnlazada
      mov  eax, [ EBP+ParametroC ]      ; el tamano en ParametroC
      push eax                          ; el tipo es minimo FichaEnlazada
      call NewCadenaEnlazada            ; se genera la CadenaEnlazada
      mov  [ EBP+LocalA ], eax          ; y el dato se coloca en LocalA
      mov  ebx, [ EBP+ParametroB ]      ; primer Identificador se
      RG( IdentificadorFE, ebx )        ; guarda en LocalA.IdentificadorFE
      mov  ebx, [ EBP+ParametroE ]      ; para asignar el descriptor
      mov  eax, [ EBP+LocalA ]          ; a la casilla
      RG( DescriptorFE, ebx )           ; en formacion
RepiteAppend042:
      mov  ecx, [ EBP+ParametroD ]      ; el conteo descuenta 1
      dec  ecx                          ; por vez y reestablece
      mov  [ EBP+ParametroD ], ecx      ; ParametroC, en total
      cmp  ecx, 0                       ; inicial ParametroC fichas
      jle  SalidaAppend042              ; salida si conteo llega a 0
      mov  eax, [ EBP+LocalA ]          ; LocalA a stack
      push eax                          ; para alargar la cadena
      call AppendGemeloCiclico          ; con AppendGemeloCiclico
      jmp  RepiteAppend042              ; repite el ciclo nuevamente
SalidaAppend042:
      mov  eax, [ EBP+LocalA ]          ; OUT eax: la lista de fichas

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  CincoParametros              ; retorno liberacion de parametros
ENDP GenerarCiclico

.CODE
PROC InicializarCiclicoFila             ; numero identificacion 043
                                        ; con el nivel actual en ParametroD
                                        ; inicializa un paquete de fichas
                                        ; tipo vehiculo en ParametroA
                                        ; ademas permite inicializar
                                        ; fichas derivadas por el metodo
                                        ; de la copia simple del exceso
                                        ; de datos esto es
                                        ; Mover (exceso de ArranqueVehiculo,
                                        ; hacia exceso de FichaEnlazada
                                        ; un total de exceso
                                        ; ArranqueVehiculoAV )
.CODE 
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, CuatroLocales           ; espacio para locales
                                        ; ParametroA    :
                                        ;       paquete de fichas
                                        ; ParametroB    : OFFSET
                                        ;       Array InicioCiclicoFila
                                        ; ParametroC    : OFFSET
                                        ;       Matriz InicioFila
                                        ; ParametroD    :
                                        ;       version de inicializacion
                                        ; Variables Locales
                                        ; LocalA        : Recorre Columnas
                                        ;       en matriz CiclicoFila
                                        ; LocalB        : puntero a
                                        ;       ArranqueVehiculo
                                        ; LocalC        : puntero a
                                        ;       elemento FichaEnlazada
                                        ; LocalD        : puntero a
                                        ;       ReferenciaCiclico

      mov  eax, [ EBP+ParametroC ]      ; revisa si ParametroC es NIL
      cmp  eax, NIL                     ; en dicho caso no hace nada
      je   Fin043                       ; salto a fin
      RL( TotalFilas )                  ; Matriz.TotalFilas
      mov  ebx, [ EBP+ParametroD ]      ; si ParametroD > TotalFilas
      cmp  eax, ebx                     ; entonces ParametroD = TotalFilas
      jge  IgnorarCambioD043            ; caso contrario no se modifica
      mov  [ EBP+ParametroD ], eax      ; guarda valor de ParametroD
IgnorarCambioD043:
      mov  eax, [ EBP+ParametroC ]      ; carga ParametroC.TotalColumnas
      RL( TotalColumnas )               ; para inicial el ciclo
      mov  [ EBP+LocalA ], eax          ; LocalA es el contador
      mov  eax, [ EBP+ParametroB ]      ; prepara ParametroB[ ParametroD ]
      mov  ebx, [ EBP+ParametroD ]      ; que es un paquete de control
      AP( ebx )                         ; AP es Macro apuntador en ARRAY
      mov  [ EBP+LocalD ], eax          ; LocalD guarda la casilla ARRAY
CicloColumna043:
      mov  eax, [ EBP+LocalA ]          ; contador de Columna
      push eax                          ; que se coloca en Stack
      mov  eax, [ EBP+ParametroD ]      ; Numero de fila pues la Matriz
      push eax                          ; es Matriz[ Nivel, Columna ]
      mov  eax, [ EBP+ParametroC ]      ; la casilla se ubica
      push eax                          ; con PROC ApuntarCasillaMatriz
      call ApuntarCasillaMatriz         ; que devuelve puntero en EAX
      mov  [ EBP+LocalB ], eax          ; LocalB guarda la casilla Matriz
      RL( IdentificadorAV )             ; IdentificadorAV identifica la
      cmp  eax, 0                       ; ficha en ParametroA, 
      je   SalidaModificacion043        ; caso 0 significa ignorar 
      push eax                          ; Hay que buscar con IdentificadorAV
      mov  eax, [ EBP+ParametroA ]      ; la FichaEnlazada respectiva
      push eax                          ; en ParametroA para ello se
      call BuscarIdentificadorCE        ; usa PROC BuscarIdentificadorCE
      mov  [ EBP+LocalC ], eax          ; resultado EAX que se guarda en
      mov  eax, [ EBP+ParametroB ]      ; LocalC, ahora viene la 
      RL( Campo1AV )                    ; transferencia de datos
      mov  ebx, eax                     ; LocalC.FilaFE =
      mov  eax, [ EBP+LocalC ]          ;       ParametroB.Campo1AV
      RG( FilaFE, ebx )                 ; recordar que Campo1AV no existe
      mov  eax, [ EBP+LocalB ]          ; en matrices, pero si en ARRAY
      RL( DescriptorAV )                ; LocalC.DescriptorFE =
      mov  ebx, eax                     ;       LocalB.DescriptorAV
      mov  eax, [ EBP+LocalC ]          ; es un tipo conjunto de control
      RG( DescriptorFE, ebx )           ; LocalC.ColumnaFE    =
      mov  eax, [ EBP+LocalB ]          ;       LocalB.ColumnaAV
      RL( ColumnaAV )                   ; esto tiene el inconveniente
      mov  ebx, eax                     ; que la columna inicial es fija
      mov  eax, [ EBP+LocalC ]          ; entre juegos luego varia
      RG( ColumnaFE, ebx )              ; LocalC.ReferenciaFE = LocalD
      mov  ebx, [ EBP+LocalD ]          ; asignacion de un puntero
      mov  eax, [ EBP+LocalC ]          ; descriptor de movimiento
      RG( ReferenciaFE, ebx )           ; valido probablemente para
      mov  eax, [ EBP+LocalB ]          ; varias fichas a la vez
      RL( CampoBaseAV )                 ; LocalB.CampoBaseAV es el 
      sub  eax, ArranqueVehiculo        ; "verdadero" Tamano actual
      cmp  eax, 0                       ; de la casilla en Matriz
      jle  SalidaModificacion043        ; si CampoBaseAV-ArranqueVehiculo
      push eax                          ; no es 0 se asume transferencia
      mov  eax, [ EBP+LocalC ]          ; simple total entre
      add  eax, FichaEnlazada           ; el exceso LocalB+ArranqueVehiculo
      push eax                          ; hacia LocalC+FichaEnlazada, el
      mov  eax, [ EBP+LocalB ]          ; CampoBaseAV (origen) es el 
      add  eax, ArranqueVehiculo        ; limitante de tamano bytes        
      push eax                          ; para hacer PROC self un poco
      call Mover                        ; mas versatil        
SalidaModificacion043:
      mov  ecx, [ EBP+LocalA ]          ; utilizamos LocalA como
      dec  ecx                          ; contador decreciente
      mov  [ EBP+LocalA ], ecx          ; hasta 0, con ECX de pivote
      cmp  ecx, 0                       ; mientras se repite
      jne  CicloColumna043              ; el ciclo hasta completar
Fin043:

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  CuatroParametros             ; retorno liberacion de parametros
ENDP InicializarCiclicoFila

