.COMMENT
 ****************************************************************************
 FROGGER.ASM    Juego de FROGGER
 ============================================================================
 ****************************************************************************
.MODEL FLAT
.MEM   18192     ; 8 MByte de memoria RAM
.UCU
.NM

.INCLUDE io.inc
.INCLUDE system.inc
.INCLUDE graph1.inc
.INCLUDE frogsys1.inc
.INCLUDE frogbas1.inc
.INCLUDE frogbas2.inc

.TYPE  ( LargoXBasicoFicha      =  14, LargoYBasicoFicha        =  16   )

.TYPE  ( MarinoEnlazado = 48, TamanoPunteroME   =  0, IdentificadorME  =  4
         SiguienteME    =  8, PunteroDatoME     = 12, DescriptorME     = 16
         FilaME         = 20, ColumnaME         = 24, ReferenciaME     = 28
         AdyacentesME   = 32, ContadorME        = 36, ContadorActivoME = 40
         FichaVinculadoME                       = 44  )


.TYPE  ( ReferenciaMarino       = 52, CampoBaseRM                     =  0
         VelocidadRM            =  4, LimiteActualizableRM            =  8
         ValorMinimoRM          = 12, ValorMaximoRM                   = 16
         SeparacionMinimaRM     = 20, SeparacionMaximaRM              = 24
         IdentificadorLimiteRM  = 28, TamanoBasicoRM                  = 32
         ProbabilidadARM        = 36, ProbabilidadBRM                 = 40
         ContadorInternoRM      = 44, ContadorActivoRM                = 48  )

.TYPE  ( ArranqueMarino         = 28, CampoBaseAM                     =  0
         IdentificadorAM        =  4, ColumnaAM                       =  8
         DescriptorAM           = 12, AdyacentesAM                    = 16
         ContadorInternoAM      = 20, ContadorActivoAM                = 24 )

.TYPE   ( CodigoESC             =  27, CodigoFlechaArriba       =  72
          CodigoFlechaAbajo     =  80, CodigoFlechaIzquierda    =  75
          CodigoFlechaDerecha   =  77, CodigoAvPag              =  81   )

.TYPE   ( BitsExtraCiclico      =   4, PixelExtraCiclico        =  16
          PrimerCarrilFila      = 169, SegundoCarrilFila        =  155
          TercerCarrilFila      = 141, CuartoCarrilFila         =  127
          QuintoCarrilFila      = 113, SextoCarrilFila          =   85
          SeptimoCarrilFila     =  71, OctavoCarrilFila         =   57
          NovenoCarrilFila      =  43, DecimoCarrilFila         =   29
          PrimerFranjaFila      = 183, SegundaFranjaFila        =   99
          TerceraFranjaFila     =  15, PrimerColumnaFinal       =   30
          SegundaColumnaFinal   =  70, TercerColumnaFinal       =  110
          CuartaColumnaFinal    = 150, QuintaColumnaFinal       =  190
          LargoYCocodrilo       =   7  )

.TYPE   ( SaltoSapoFila         =   5, SaltoCorregidoFila       =   -1
          SaltoSapoColumna      =  80, SaltoCorregidoColumna    =   16 )

.TYPE   ( IdentificadorPantalla =   1
          IdentificadorCar1DerA =  10, TotalCar1Der             =   4
          IdentificadorCar1IzqA =  20, TotalCar1Izq             =   4
          IdentificadorCar2DerA =  30, TotalCar2Der             =   4
          IdentificadorCar2IzqA =  40, TotalCar2Izq             =   4
          IdentificadorCar3DerA =  50, TotalCar3Der             =   4
          IdentificadorCar3IzqA =  60, TotalCar3Izq             =   4
          IdentificadorCar4DerA =  70, TotalCar4Der             =   4
          IdentificadorCar4IzqA =  80, TotalCar4Izq             =   4
          IdentificadorCam1DerA =  90, TotalCam1Der             =   4
          IdentificadorCam1IzqA = 100, TotalCam1Izq             =   4
          IdentificadorCam2DerA = 110, TotalCam2Der             =   4
          IdentificadorCam2IzqA = 120, TotalCam2Izq             =   4
          IdentificadorTronco6  = 130, TotalTronco6             =   3
          IdentificadorTronco8  = 140, TotalTronco8             =   3
          IdentificadorTronco10 = 150, TotalTronco10            =   3
          IdentificadorTortuga7Der         = 160
          TotalTortuga7Der      =   3
          IdentificadorTortuga7Izq         = 170
          TotalTortuga7Izq      =   3
          IdentificadorTortuga9Der         = 180
          TotalTortuga9Der      =   3
          IdentificadorTortuga9Izq         = 190
          TotalTortuga9Izq      =   3
          IdentificadorLagartoFijo       = 200
          TotalCocodriloFijo    =   2, TotalMoscaFijo           =   1
          IdentificadorMoscaFijo           = 210
          IntentosMoscaFijo                =   2
          IdentificadorAnfibio             = 220
          VersionesColumna1     =   4, VersionesFila1           =   5
          VersionesColumna2     =   4, VersionesFila2           =   5
          VersionesColumna3     =   4, VersionesFila3           =   5
          VersionesColumna4     =   4, VersionesFila4           =   5
          VersionesColumna5     =   4, VersionesFila5           =   5
          VersionesColumna6     =   3, VersionesFila6           =   5
          VersionesColumna8     =   3, VersionesFila8           =   5
          VersionesColumna10    =   3, VersionesFila10          =   5
          VersionesColumna7     =   3, VersionesFila7           =   5
          VersionesColumna9     =   3, VersionesFila9           =   5
          VersionesColumnaCA    =   2, VersionesFilaCA          =   5
          VersionesColumnaMA    =   1, VersionesFilaMA          =   5 )

.TYPE   ( TamanoLongInt         =   4, TotalFinales             =   5  )

.DATA
  RegistroPrueba01   dd  3 DUP( 0 )  ; Registro con tres campos
  MiPunteroPrueba    dd  0           ; Puntero para pruebas
  MiOtroPuntero      dd  0           ; Otro  puntero para pruebas
  MiPunteroGemelo    dd  0           ; Para crear gemelos en pruebas
  FinalOcupado       dd  ArrayVariable+TamanoLongInt*TotalFinales
                     dd  TotalFinales, TotalFinales, TamanoLongInt, 0, 0, 0
                     dd  FALSE, FALSE, FALSE, FALSE, FALSE
  FinalBloqueado     dd  ArrayVariable+TamanoLongInt*TotalFinales
                     dd  TotalFinales, TotalFinales, TamanoLongInt, 0, 0, 0
                     dd  FALSE, FALSE, FALSE, FALSE, FALSE
  ColumnaFinal       dd  ArrayVariable+TamanoLongInt*TotalFinales
                     dd  TotalFinales, TotalFinales, TamanoLongInt, 0, 0, 0
                     dd  PrimerColumnaFinal, SegundaColumnaFinal
                     dd  TercerColumnaFinal, CuartaColumnaFinal
                     dd  QuintaColumnaFinal
  NombreArchivo1     db  'FROG.REF',0
                                     ; Nombre de archivo 1 en programa
  HandleArchivo1     dd  0           ; Handle1 clave para su manejo
  NombreCar1Der      db  'DATOS/CAR1DER.REF',0
                                     ; Nombre de archivo de Car1Der
  NombreCar1Izq      db  'DATOS/CAR1IZQ.REF',0
                                     ; Nombre de archivo de Car1Izq
  NombreCar2Der      db  'DATOS/CAR2DER.REF',0
                                     ; Nombre de archivo de Car2Der
  NombreCar2Izq      db  'DATOS/CAR2IZQ.REF',0
                                     ; Nombre de archivo de Car2Izq
  NombreCar3Der      db  'DATOS/CAR3DER.REF',0
                                     ; Nombre de archivo de Car3Der
  NombreCar3Izq      db  'DATOS/CAR3IZQ.REF',0
                                     ; Nombre de archivo de Car3Izq
  NombreCar4Der      db  'DATOS/CAR4DER.REF',0
                                     ; Nombre de archivo de Car4Der
  NombreCar4Izq      db  'DATOS/CAR4IZQ.REF',0
                                     ; Nombre de archivo de Car4Izq
  NombreCam1Der      db  'DATOS/CAM1DER.REF',0
                                     ; Nombre de archivo de Cam1Der
  NombreCam1Izq      db  'DATOS/CAM1IZQ.REF',0
                                     ; Nombre de archivo de Cam1Izq
  NombreCam2Der      db  'DATOS/CAM2DER.REF',0
                                     ; Nombre de archivo de Cam2Der
  NombreCam2Izq      db  'DATOS/CAM2IZQ.REF',0
                                     ; Nombre de archivo de Cam2Izq
  NombreTronco       db  'DATOS/TRONCO.REF',0
                                     ; Nombre de archivo de tronco
  NombreTortuDer     db  'DATOS/TORTUDER.REF',0
                                     ; Nombre de archivo de tortuga derecha
  NombreTortuIzq     db  'DATOS/TORTUIZQ.REF',0
                                     ; Nombre de archivo de tortuga izquierda
  NombreCocodrilo    db  'DATOS/COCODRIL.REF',0
                                     ; Nombre de archivo de cocodrilo
  NombreMosca        db  'DATOS/MOSCA.REF',0
                                     ; Nombre de archivo de mosca
  NombreAnfibio      db  'DATOS/RANA.REF',0
                                     ; Nombre de archivo de rana
  NombreArchivo2     db  'FROG2.REF',0
                                     ; Nombre de archivo 2 en programa
  HandleArchivo2     dd  0           ; Handle2 clave para su manejo
  NombrePantalla     db  'FROGPANT.REF',0
                                     ; Nombre de archivo de pantalla
  HandlePantalla     dd  0           ; Handle para pantalla
  CambioGrafico      db  'Digite 1-ModoGrafico, 2-ModoTexto...',0
                                    ; mensaje de cambio texto o grafico
  InicioCiclicoFila1 dd  ArrayVariable+ReferenciaCiclico*VersionesFila1
                     dd  VersionesFila1, VersionesFila1, ReferenciaCiclico
                     dd  PrimerCarrilFila, 0, 0
                                    ; InicioCiclicoFila[1]
                     dd  ReferenciaCiclico, -2*PixelExtraCiclico
                     dd  230*PixelExtraCiclico, -20*PixelExtraCiclico
                     dd  230*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  80*PixelExtraCiclico, 0
                                    ; InicioCiclicoFila[2]
                     dd  ReferenciaCiclico, PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                                    ; InicioCiclicoFila[3]
                     dd  ReferenciaCiclico, -PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                                    ; InicioCiclicoFila[4]
                     dd  ReferenciaCiclico, PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                                    ; InicioCiclicoFila[5]
                     dd  ReferenciaCiclico, PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                                    ; Bloque de control de Fila1
                                    ; con punteros descriptores de movimiento
  InicioFila1        dd  MatrizVariable+ArranqueVehiculo*VersionesColumna1*VersionesFila1
                     dd  VersionesColumna1*VersionesFila1
                     dd  VersionesColumna1*VersionesFila1, ArranqueVehiculo
                     dd  VersionesFila1, VersionesColumna1, 0
                                    ; InicioFila1[1,1]
                     dd  ArranqueVehiculo, IdentificadorCar1IzqA  ,  50*PixelExtraCiclico
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar1IzqA+1, 100*PixelExtraCiclico
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar1IzqA+2, 150*PixelExtraCiclico
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, 0                      , 0
                     dd  ActivoPAQ           +FichaPAQ+CiclicoPAQ
                                    ; InicioFila1[2,1]
                     dd  ArranqueVehiculo, IdentificadorCar1DerA  , 800
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar1DerA+1, 1200
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar1DerA+2, 1600
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar1DerA+3, 2000
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                                    ; InicioFila1[3,1]
                     dd  ArranqueVehiculo, IdentificadorCar1IzqA  , 800
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar1IzqA+1, 1200
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar1IzqA+2, 1600
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar1IzqA+3, 2000
                     dd  ActivoPAQ           +FichaPAQ+CiclicoPAQ
                                    ; InicioFila1[4,1]
                     dd  ArranqueVehiculo, IdentificadorCar1DerA  , 800
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar1DerA+1, 1200
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar1DerA+2, 1600
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar1DerA+3, 2000
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                                    ; InicioFila1[5,1]
                     dd  ArranqueVehiculo, IdentificadorCar1DerA  , 800
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar1DerA+1, 1200
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar1DerA+2, 1600
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar1DerA+3, 2000
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                                    ; desciptor de arranque de Fila1
  InicioCiclicoFila2 dd  ArrayVariable+ReferenciaCiclico*VersionesFila2
                     dd  VersionesFila2, VersionesFila2, ReferenciaCiclico
                     dd  SegundoCarrilFila, 0, 0
                                    ; InicioCiclicoFila[1]
                     dd  ReferenciaCiclico, -PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                                    ; InicioCiclicoFila[2]
                     dd  ReferenciaCiclico, PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                                    ; InicioCiclicoFila[3]
                     dd  ReferenciaCiclico, -PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                                    ; InicioCiclicoFila[4]
                     dd  ReferenciaCiclico, PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                                    ; InicioCiclicoFila[5]
                     dd  ReferenciaCiclico, PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                                    ; Bloque de control de Fila2
                                    ; con punteros descriptores de movimiento
  InicioFila2        dd  MatrizVariable+ArranqueVehiculo*VersionesColumna2*VersionesFila2
                     dd  VersionesColumna2*VersionesFila2
                     dd  VersionesColumna2*VersionesFila2, ArranqueVehiculo
                     dd  VersionesFila2, VersionesColumna2, 0
                                    ; InicioFila2[1,1]
                     dd  ArranqueVehiculo, IdentificadorCar2IzqA  , 800
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar2IzqA+1, 1200
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar2IzqA+2, 1600
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar2IzqA+3, 2000
                     dd  ActivoPAQ           +FichaPAQ+CiclicoPAQ
                                    ; InicioFila2[2,1]
                     dd  ArranqueVehiculo, IdentificadorCar2DerA  , 800
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar2DerA+1, 1200
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar2DerA+2, 1600
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar2DerA+3, 2000
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                                    ; InicioFila2[3,1]
                     dd  ArranqueVehiculo, IdentificadorCar2IzqA  , 800
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar2IzqA+1, 1200
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar2IzqA+2, 1600
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar2IzqA+3, 2000
                     dd  ActivoPAQ           +FichaPAQ+CiclicoPAQ
                                    ; InicioFila2[4,1]
                     dd  ArranqueVehiculo, IdentificadorCar2DerA  , 800
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar2DerA+1, 1200
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar2DerA+2, 1600
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar2DerA+3, 2000
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                                    ; InicioFila2[5,1]
                     dd  ArranqueVehiculo, IdentificadorCar2DerA  , 800
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar2DerA+1, 1200
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar2DerA+2, 1600
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar2DerA+3, 2000
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                                    ; desciptor de arranque de Fila2
  InicioCiclicoFila3 dd  ArrayVariable+ReferenciaCiclico*VersionesFila3
                     dd  VersionesFila3, VersionesFila3, ReferenciaCiclico
                     dd  TercerCarrilFila, 0, 0
                                    ; InicioCiclicoFila[1]
                     dd  ReferenciaCiclico, -PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                                    ; InicioCiclicoFila[2]
                     dd  ReferenciaCiclico, PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                                    ; InicioCiclicoFila[3]
                     dd  ReferenciaCiclico, -PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                                    ; InicioCiclicoFila[4]
                     dd  ReferenciaCiclico, PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                                    ; InicioCiclicoFila[5]
                     dd  ReferenciaCiclico, PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                                    ; Bloque de control de Fila1
                                    ; con punteros descriptores de movimiento
  InicioFila3        dd  MatrizVariable+ArranqueVehiculo*VersionesColumna3*VersionesFila3
                     dd  VersionesColumna3*VersionesFila3
                     dd  VersionesColumna3*VersionesFila3, ArranqueVehiculo
                     dd  VersionesFila3, VersionesColumna3, 0
                                    ; InicioFila3[1,1]
                     dd  ArranqueVehiculo, IdentificadorCar3IzqA  , 800
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar3IzqA+1, 1200
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar3IzqA+2, 1600
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar3IzqA+3, 2000
                     dd  ActivoPAQ           +FichaPAQ+CiclicoPAQ
                                    ; InicioFila3[2,1]
                     dd  ArranqueVehiculo, IdentificadorCar3DerA  , 800
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar3DerA+1, 1200
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar3DerA+2, 1600
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar3DerA+3, 2000
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                                    ; InicioFila3[3,1]
                     dd  ArranqueVehiculo, IdentificadorCar3IzqA  , 800
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar3IzqA+1, 1200
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar3IzqA+2, 1600
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar3IzqA+3, 2000
                     dd  ActivoPAQ           +FichaPAQ+CiclicoPAQ
                                    ; InicioFila3[4,1]
                     dd  ArranqueVehiculo, IdentificadorCar3DerA  , 800
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar3DerA+1, 1200
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar3DerA+2, 1600
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar3DerA+3, 2000
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                                    ; InicioFila3[5,1]
                     dd  ArranqueVehiculo, IdentificadorCar3DerA  , 800
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar3DerA+1, 1200
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar3DerA+2, 1600
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar3DerA+3, 2000
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                                    ; desciptor de arranque de Fila3
  InicioCiclicoFila4 dd  ArrayVariable+ReferenciaCiclico*VersionesFila4
                     dd  VersionesFila4, VersionesFila4, ReferenciaCiclico
                     dd  CuartoCarrilFila, 0, 0
                                    ; InicioCiclicoFila[1]
                     dd  ReferenciaCiclico, -PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                                    ; InicioCiclicoFila[2]
                     dd  ReferenciaCiclico, PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                                    ; InicioCiclicoFila[3]
                     dd  ReferenciaCiclico, -PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                                    ; InicioCiclicoFila[4]
                     dd  ReferenciaCiclico, PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                                    ; InicioCiclicoFila[5]
                     dd  ReferenciaCiclico, PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                                    ; Bloque de control de Fila1
                                    ; con punteros descriptores de movimiento
  InicioFila4        dd  MatrizVariable+ArranqueVehiculo*VersionesColumna4*VersionesFila4
                     dd  VersionesColumna4*VersionesFila4
                     dd  VersionesColumna4*VersionesFila4, ArranqueVehiculo
                     dd  VersionesFila4, VersionesColumna4, 0
                                    ; InicioFila4[1,1]
                     dd  ArranqueVehiculo, IdentificadorCar4IzqA  , 800
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar4IzqA+1, 1200
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar4IzqA+2, 1600
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar4IzqA+3, 2000
                     dd  ActivoPAQ           +FichaPAQ+CiclicoPAQ
                                    ; InicioFila4[2,1]
                     dd  ArranqueVehiculo, IdentificadorCar4DerA  , 800
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar4DerA+1, 1200
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar4DerA+2, 1600
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar4DerA+3, 2000
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                                    ; InicioFila4[3,1]
                     dd  ArranqueVehiculo, IdentificadorCar4IzqA  , 800
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar4IzqA+1, 1200
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar4IzqA+2, 1600
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar4IzqA+3, 2000
                     dd  ActivoPAQ           +FichaPAQ+CiclicoPAQ
                                    ; InicioFila4[4,1]
                     dd  ArranqueVehiculo, IdentificadorCar4DerA  , 800
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar4DerA+1, 1200
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar4DerA+2, 1600
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar4DerA+3, 2000
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                                    ; InicioFila4[5,1]
                     dd  ArranqueVehiculo, IdentificadorCar4DerA  , 800
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar4DerA+1, 1200
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar4DerA+2, 1600
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCar4DerA+3, 2000
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                                    ; desciptor de arranque de Fila4
  InicioCiclicoFila5 dd  ArrayVariable+Referenc5aCiclico*VersionesFila5
                     dd  VersionesFila5, VersionesFila5, ReferenciaCiclico
                     dd  QuintoCarrilFila, 0, 0
                                    ; InicioCiclicoFila[1]
                     dd  ReferenciaCiclico, -PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                                    ; InicioCiclicoFila[2]
                     dd  ReferenciaCiclico, PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                                    ; InicioCiclicoFila[3]
                     dd  ReferenciaCiclico, -PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                                    ; InicioCiclicoFila[4]
                     dd  ReferenciaCiclico, PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                                    ; InicioCiclicoFila[5]
                     dd  ReferenciaCiclico, PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                                    ; Bloque de control de Fila1
                                    ; con punteros descriptores de movimiento
  InicioFila5        dd  MatrizVariable+ArranqueVehiculo*VersionesColumna5*VersionesFila5
                     dd  VersionesColumna5*VersionesFila5
                     dd  VersionesColumna5*VersionesFila5, ArranqueVehiculo
                     dd  VersionesFila5, VersionesColumna5, 0
                                    ; InicioFila5[1,1]
                     dd  ArranqueVehiculo, IdentificadorCam1IzqA  , 800
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCam1IzqA+1, 1200
                     dd  ActivoPAQ           +FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCam1IzqA+2, 1600
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCam1IzqA+3, 2000
                     dd  ActivoPAQ           +FichaPAQ+CiclicoPAQ
                                    ; InicioFila5[2,1]
                     dd  ArranqueVehiculo, IdentificadorCam1DerA  , 800
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCam1DerA+1, 1200
                     dd  ActivoPAQ           +FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCam1DerA+2, 1600
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCam1DerA+3, 2000
                     dd  ActivoPAQ           +FichaPAQ+CiclicoPAQ
                                    ; InicioFila5[3,1]
                     dd  ArranqueVehiculo, IdentificadorCam2IzqA  , 800
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCam2IzqA+1, 1200
                     dd  ActivoPAQ           +FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCam2IzqA+2, 1600
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCam2IzqA+3, 2000
                     dd  ActivoPAQ           +FichaPAQ+CiclicoPAQ
                                    ; InicioFila5[4,1]
                     dd  ArranqueVehiculo, IdentificadorCam2DerA  , 800
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCam2DerA+1, 1200
                     dd  ActivoPAQ           +FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCam2DerA+2, 1600
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCam2DerA+3, 2000
                     dd  ActivoPAQ           +FichaPAQ+CiclicoPAQ
                                    ; InicioFila5[5,1]
                     dd  ArranqueVehiculo, IdentificadorCam1DerA  , 800
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCam1DerA+1, 1200
                     dd  ActivoPAQ           +FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCam1DerA+2, 1600
                     dd  ActivoPAQ+VisiblePAQ+FichaPAQ+CiclicoPAQ
                     dd  ArranqueVehiculo, IdentificadorCam1DerA+3, 2000
                     dd  ActivoPAQ           +FichaPAQ+CiclicoPAQ
                                    ; desciptor de arranque de Fila5
  InicioCiclicoFila6 dd  ArrayVariable+ReferenciaMarino*VersionesFila6
                     dd  VersionesFila6, VersionesFila6, ReferenciaMarino
                     dd  SextoCarrilFila, 0, 0
                                    ; InicioCiclicoFila[1]
                     dd  ReferenciaMarino, -PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                     dd  2, 4, 0, 0, 0
                                    ; InicioCiclicoFila[2]
                     dd  ReferenciaMarino, PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                     dd  2, 4, 0, 0, 0
                                    ; InicioCiclicoFila[3]
                     dd  ReferenciaMarino, -PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                     dd  2, 4, 0, 0, 0
                                    ; InicioCiclicoFila[4]
                     dd  ReferenciaMarino, PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                     dd  2, 4, 0, 0, 0
                                    ; InicioCiclicoFila[5]
                     dd  ReferenciaMarino, -PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                     dd  2, 4, 0, 0, 0
                                    ; Bloque de control de Fila6
                                    ; con punteros descriptores de movimiento
  InicioFila6        dd  MatrizVariable+ArranqueMarino*VersionesColumna6*VersionesFila6
                     dd  VersionesColumna6*VersionesFila6
                     dd  VersionesColumna6*VersionesFila6, ArranqueMarino
                     dd  VersionesFila6, VersionesColumna6, 0
                                    ; InicioFila6[1,1]
                     dd  ArranqueMarino, IdentificadorTronco6   , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ
                     dd  2, 0, 0
                     dd  ArranqueMarino, IdentificadorTronco6+1 , 1600
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ
                     dd  2, 0, 0
                     dd  ArranqueMarino, 0                      , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ
                     dd  2, 0, 0
                                    ; InicioFila6[2,1]
                     dd  ArranqueMarino, IdentificadorTronco6   , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ
                     dd  2, 0, 0
                     dd  ArranqueMarino, IdentificadorTronco6+1 , 1600
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ
                     dd  2, 0, 0
                     dd  ArranqueMarino, 0                      , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ
                     dd  2, 0, 0
                                    ; InicioFila6[3,1]
                     dd  ArranqueMarino, IdentificadorTronco6   , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ
                     dd  2, 0, 0
                     dd  ArranqueMarino, IdentificadorTronco6+1 , 1600
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ
                     dd  2, 0, 0
                     dd  ArranqueMarino, 0                      , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ
                     dd  2, 0, 0
                                    ; InicioFila6[4,1]
                     dd  ArranqueMarino, IdentificadorTronco6   , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ
                     dd  2, 0, 0
                     dd  ArranqueMarino, IdentificadorTronco6+1 , 1600
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ
                     dd  2, 0, 0
                     dd  ArranqueMarino, 0                      , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ
                     dd  2, 0, 0
                                    ; InicioFila6[5,1]
                     dd  ArranqueMarino, IdentificadorTronco6   , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ
                     dd  2, 0, 0
                     dd  ArranqueMarino, IdentificadorTronco6+1 , 1600
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ
                     dd  2, 0, 0
                     dd  ArranqueMarino, 0                      , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ
                     dd  2, 0, 0
                                    ; desciptor de arranque de Fila6
  InicioCiclicoFila8 dd  ArrayVariable+ReferenciaMarino*VersionesFila8
                     dd  VersionesFila8, VersionesFila8, ReferenciaMarino
                     dd  OctavoCarrilFila, 0, 0
                                    ; InicioCiclicoFila[1]
                     dd  ReferenciaMarino, -PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                     dd  4, 4, 0, 0, 0
                                    ; InicioCiclicoFila[2]
                     dd  ReferenciaMarino, PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                     dd  4, 4, 0, 0, 0
                                    ; InicioCiclicoFila[3]
                     dd  ReferenciaMarino, -PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                     dd  4, 4, 0, 0, 0
                                    ; InicioCiclicoFila[4]
                     dd  ReferenciaMarino, PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                     dd  4, 4, 0, 0, 0
                                    ; InicioCiclicoFila[5]
                     dd  ReferenciaMarino, -PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                     dd  4, 4, 0, 0, 0
                                    ; Bloque de control de Fila8
                                    ; con punteros descriptores de movimiento
  InicioFila8        dd  MatrizVariable+ArranqueMarino*VersionesColumna8*VersionesFila8
                     dd  VersionesColumna8*VersionesFila8
                     dd  VersionesColumna8*VersionesFila8, ArranqueMarino
                     dd  VersionesFila8, VersionesColumna8, 0
                                    ; InicioFila8[1,1]
                     dd  ArranqueMarino, IdentificadorTronco8   , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ
                     dd  4, 0, 0
                     dd  ArranqueMarino, 0                      , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ
                     dd  4, 0, 0
                     dd  ArranqueMarino, 0                      , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ
                     dd  4, 0, 0
                                    ; InicioFila8[2,1]
                     dd  ArranqueMarino, IdentificadorTronco8   , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ
                     dd  4, 0, 0
                     dd  ArranqueMarino, 0                      , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ
                     dd  4, 0, 0
                     dd  ArranqueMarino, 0                      , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ
                     dd  4, 0, 0
                                    ; InicioFila8[3,1]
                     dd  ArranqueMarino, IdentificadorTronco8   , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ
                     dd  4, 0, 0
                     dd  ArranqueMarino, 0                      , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ
                     dd  4, 0, 0
                     dd  ArranqueMarino, 0                      , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ
                     dd  4, 0, 0
                                    ; InicioFila8[4,1]
                     dd  ArranqueMarino, IdentificadorTronco8   , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ
                     dd  4, 0, 0
                     dd  ArranqueMarino, 0                      , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ
                     dd  4, 0, 0
                     dd  ArranqueMarino, 0                      , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ
                     dd  4, 0, 0
                                    ; InicioFila8[5,1]
                     dd  ArranqueMarino, IdentificadorTronco8   , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ
                     dd  4, 0, 0
                     dd  ArranqueMarino, 0                      , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ
                     dd  4, 0, 0
                     dd  ArranqueMarino, 0                      , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ
                     dd  4, 0, 0
                                    ; desciptor de arranque de Fila8
  InicioCiclicoFila10 dd  ArrayVariable+ReferenciaMarino*VersionesFila10
                      dd  VersionesFila10, VersionesFila10, ReferenciaMarino
                      dd  DecimoCarrilFila, 0, 0
                                    ; InicioCiclicoFila[1]
                     dd  ReferenciaMarino, -PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                     dd  4, 4, 0, 0, 0
                                    ; InicioCiclicoFila[2]
                     dd  ReferenciaMarino, PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                     dd  4, 4, 0, 0, 0
                                    ; InicioCiclicoFila[3]
                     dd  ReferenciaMarino, -PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                     dd  4, 4, 0, 0, 0
                                    ; InicioCiclicoFila[4]
                     dd  ReferenciaMarino, PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                     dd  4, 4, 0, 0, 0
                                    ; InicioCiclicoFila[5]
                     dd  ReferenciaMarino, -PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                     dd  4, 4, 0, 0, 0
                                    ; Bloque de control de Fila10
                                    ; con punteros descriptores de movimiento
  InicioFila10       dd  MatrizVariable+ArranqueMarino*VersionesColumna10*VersionesFila10
                     dd  VersionesColumna10*VersionesFila10
                     dd  VersionesColumna10*VersionesFila10, ArranqueMarino
                     dd  VersionesFila10, VersionesColumna10, 0
                                    ; InicioFila10[1,1]
                     dd  ArranqueMarino, IdentificadorTronco10  , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ+SoportePAQ
                     dd  4, 0, 0
                     dd  ArranqueMarino, 0                      , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ+SoportePAQ
                     dd  4, 0, 0
                     dd  ArranqueMarino, 0                      , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ+SoportePAQ
                     dd  4, 0, 0
                                    ; InicioFila10[2,1]
                     dd  ArranqueMarino, IdentificadorTronco10  , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ+SoportePAQ
                     dd  4, 0, 0
                     dd  ArranqueMarino, 0                      , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ+SoportePAQ
                     dd  4, 0, 0
                     dd  ArranqueMarino, 0                      , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ+SoportePAQ
                     dd  4, 0, 0
                                    ; InicioFila10[3,1]
                     dd  ArranqueMarino, IdentificadorTronco10  , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ+SoportePAQ
                     dd  4, 0, 0
                     dd  ArranqueMarino, 0                      , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ+SoportePAQ
                     dd  4, 0, 0
                     dd  ArranqueMarino, 0                      , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ+SoportePAQ
                     dd  4, 0, 0
                                    ; InicioFila10[4,1]
                     dd  ArranqueMarino, IdentificadorTronco10  , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ+SoportePAQ
                     dd  4, 0, 0
                     dd  ArranqueMarino, 0                      , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ+SoportePAQ
                     dd  4, 0, 0
                     dd  ArranqueMarino, 0                      , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ+SoportePAQ
                     dd  4, 0, 0
                                    ; InicioFila10[5,1]
                     dd  ArranqueMarino, IdentificadorTronco10  , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ+SoportePAQ
                     dd  4, 0, 0
                     dd  ArranqueMarino, 0                      , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ+SoportePAQ
                     dd  4, 0, 0
                     dd  ArranqueMarino, 0                      , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TroncoPAQ+SoportePAQ
                     dd  4, 0, 0
                                    ; desciptor de arranque de Fila10
  InicioCiclicoFila7  dd  ArrayVariable+ReferenciaMarino*VersionesFila7
                      dd  VersionesFila7, VersionesFila7, ReferenciaMarino
                      dd  SeptimoCarrilFila, 0, 0
                                    ; InicioCiclicoFila[1]
                     dd  ReferenciaMarino, PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                     dd  2, 4, 0, 4, 32
                                    ; InicioCiclicoFila[2]
                     dd  ReferenciaMarino, -PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                     dd  2, 4, 0, 4, 32
                                    ; InicioCiclicoFila[3]
                     dd  ReferenciaMarino, PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                     dd  2, 4, 0, 4, 32
                                    ; InicioCiclicoFila[4]
                     dd  ReferenciaMarino, -PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                     dd  2, 4, 0, 4, 32
                                    ; InicioCiclicoFila[5]
                     dd  ReferenciaMarino, PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                     dd  2, 4, 0, 4, 32
                                    ; Bloque de control de Fila7
                                    ; con punteros descriptores de movimiento
  InicioFila7        dd  MatrizVariable+ArranqueMarino*VersionesColumna7*VersionesFila7
                     dd  VersionesColumna7*VersionesFila7
                     dd  VersionesColumna7*VersionesFila7, ArranqueMarino
                     dd  VersionesFila7, VersionesColumna7, 0
                                    ; InicioFila7[1,1]
                     dd  ArranqueMarino, IdentificadorTortuga7Der, 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TortugaPAQ+SoportePAQ+SumergiblePAQ
                     dd  2, 4, 32
                     dd  ArranqueMarino, 0                       , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TortugaPAQ+SoportePAQ+SumergiblePAQ
                     dd  2, 4, 32
                     dd  ArranqueMarino, 0                       , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TortugaPAQ+SoportePAQ+SumergiblePAQ
                     dd  2, 4, 32
                                    ; InicioFila7[2,1]
                     dd  ArranqueMarino, IdentificadorTortuga7Izq, 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TortugaPAQ+SoportePAQ+SumergiblePAQ
                     dd  2, 4, 32
                     dd  ArranqueMarino, 0                       , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TortugaPAQ+SoportePAQ+SumergiblePAQ
                     dd  2, 4, 32
                     dd  ArranqueMarino, 0                       , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TortugaPAQ+SoportePAQ+SumergiblePAQ
                     dd  2, 4, 32
                                    ; InicioFila7[3,1]
                     dd  ArranqueMarino, IdentificadorTortuga7Der, 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TortugaPAQ+SoportePAQ+SumergiblePAQ
                     dd  2, 4, 32
                     dd  ArranqueMarino, 0                       , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TortugaPAQ+SoportePAQ+SumergiblePAQ
                     dd  2, 4, 32
                     dd  ArranqueMarino, 0                       , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TortugaPAQ+SoportePAQ+SumergiblePAQ
                     dd  2, 4, 32
                                    ; InicioFila7[4,1]
                     dd  ArranqueMarino, IdentificadorTortuga7Izq, 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TortugaPAQ+SoportePAQ+SumergiblePAQ
                     dd  2, 4, 32
                     dd  ArranqueMarino, 0                       , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TortugaPAQ+SoportePAQ+SumergiblePAQ
                     dd  2, 4, 32
                     dd  ArranqueMarino, 0                       , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TortugaPAQ+SoportePAQ+SumergiblePAQ
                     dd  2, 4, 32
                                    ; InicioFila7[5,1]
                     dd  ArranqueMarino, IdentificadorTortuga7Der, 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TortugaPAQ+SoportePAQ+SumergiblePAQ
                     dd  2, 4, 32
                     dd  ArranqueMarino, 0                       , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TortugaPAQ+SoportePAQ+SumergiblePAQ
                     dd  2, 4, 32
                     dd  ArranqueMarino, 0                       , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TortugaPAQ+SoportePAQ+SumergiblePAQ
                     dd  2, 4, 32
                                    ; desciptor de arranque de Fila7
  InicioCiclicoFila9  dd  ArrayVariable+ReferenciaMarino*VersionesFila9
                      dd  VersionesFila9, VersionesFila9, ReferenciaMarino
                      dd  NovenoCarrilFila, 0, 0
                                    ; InicioCiclicoFila[1]
                     dd  ReferenciaMarino, PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                     dd  2, 4, 0, 4, 32
                                    ; InicioCiclicoFila[2]
                     dd  ReferenciaMarino, -PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                     dd  2, 4, 0, 4, 32
                                    ; InicioCiclicoFila[3]
                     dd  ReferenciaMarino, PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                     dd  2, 4, 0, 4, 32
                                    ; InicioCiclicoFila[4]
                     dd  ReferenciaMarino, -PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                     dd  2, 4, 0, 4, 32
                                    ; InicioCiclicoFila[5]
                     dd  ReferenciaMarino, PixelExtraCiclico
                     dd  150*PixelExtraCiclico, 40*PixelExtraCiclico
                     dd  100*PixelExtraCiclico, 20*PixelExtraCiclico
                     dd  20*PixelExtraCiclico, 0
                     dd  2, 4, 0, 4, 32
                                    ; Bloque de control de Fila9
                                    ; con punteros descriptores de movimiento
  InicioFila9        dd  MatrizVariable+ArranqueMarino*VersionesColumna9*VersionesFila9
                     dd  VersionesColumna9*VersionesFila9
                     dd  VersionesColumna9*VersionesFila9, ArranqueMarino
                     dd  VersionesFila9, VersionesColumna9, 0
                                    ; InicioFila9[1,1]
                     dd  ArranqueMarino, IdentificadorTortuga9Der, 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TortugaPAQ+SoportePAQ+SumergiblePAQ
                     dd  2, 4, 32
                     dd  ArranqueMarino, 0                       , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TortugaPAQ+SoportePAQ+SumergiblePAQ
                     dd  2, 4, 32
                     dd  ArranqueMarino, 0                       , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TortugaPAQ+SoportePAQ+SumergiblePAQ
                     dd  2, 4, 32
                                    ; InicioFila9[2,1]
                     dd  ArranqueMarino, IdentificadorTortuga9Izq, 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TortugaPAQ+SoportePAQ+SumergiblePAQ
                     dd  2, 4, 32
                     dd  ArranqueMarino, 0                       , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TortugaPAQ+SoportePAQ+SumergiblePAQ
                     dd  2, 4, 32
                     dd  ArranqueMarino, 0                       , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TortugaPAQ+SoportePAQ+SumergiblePAQ
                     dd  2, 4, 32
                                    ; InicioFila9[3,1]
                     dd  ArranqueMarino, IdentificadorTortuga9Der, 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TortugaPAQ+SoportePAQ+SumergiblePAQ
                     dd  2, 4, 32
                     dd  ArranqueMarino, 0                       , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TortugaPAQ+SoportePAQ+SumergiblePAQ
                     dd  2, 4, 32
                     dd  ArranqueMarino, 0                       , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TortugaPAQ+SoportePAQ+SumergiblePAQ
                     dd  2, 4, 32
                                    ; InicioFila9[4,1]
                     dd  ArranqueMarino, IdentificadorTortuga9Izq, 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TortugaPAQ+SoportePAQ+SumergiblePAQ
                     dd  2, 4, 32
                     dd  ArranqueMarino, 0                       , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TortugaPAQ+SoportePAQ+SumergiblePAQ
                     dd  2, 4, 32
                     dd  ArranqueMarino, 0                       , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TortugaPAQ+SoportePAQ+SumergiblePAQ
                     dd  2, 4, 32
                                    ; InicioFila9[5,1]
                     dd  ArranqueMarino, IdentificadorTortuga9Der, 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TortugaPAQ+SoportePAQ+SumergiblePAQ
                     dd  2, 4, 32
                     dd  ArranqueMarino, 0                       , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TortugaPAQ+SoportePAQ+SumergiblePAQ
                     dd  2, 4, 32
                     dd  ArranqueMarino, 0                       , 800
                     dd  ActivoPAQ+VisiblePAQ+CiclicoPAQ+TortugaPAQ+SoportePAQ+SumergiblePAQ
                     dd  2, 4, 32
                                    ; desciptor de arranque de Fila9
  CocodriloFijoRef    dd  ArrayVariable+ReferenciaMarino*VersionesFilaCA
                      dd  VersionesFilaCA, VersionesFilaCA, ReferenciaMarino
                      dd  TerceraFranjaFila, 0, 0
                                    ; CocodriloFijoRef[1]
                     dd  ReferenciaMarino, 0
                     dd  0, 0
                     dd  0, 0
                     dd  0, 0
                     dd  0, 16, 0, 16, 0
                                    ; CocodriloFijoRef[2]
                     dd  ReferenciaMarino, 0
                     dd  0, 0
                     dd  0, 0
                     dd  0, 0
                     dd  0, 8, 0, 8, 0
                                    ; CocodriloFijoRef[3]
                     dd  ReferenciaMarino, 0
                     dd  0, 0
                     dd  0, 0
                     dd  0, 0
                     dd  0, 16, 0, 16, 0
                                    ; CocodriloFijoRef[4]
                     dd  ReferenciaMarino, 0
                     dd  0, 0
                     dd  0, 0
                     dd  0, 0
                     dd  0, 8, 0, 8, 0
                                    ; CocodriloFijoRef[5]
                     dd  ReferenciaMarino, 0
                     dd  0, 0
                     dd  0, 0
                     dd  0, 0
                     dd  0, 4, 0, 4, 0
                                    ; Fin de CocodriloFijoRef
  InicioCocodriloFijo dd  MatrizVariable+ArranqueMarino*VersionesColumnaCA*VersionesFilaCA
                      dd  VersionesColumnaCA*VersionesFilaCA
                      dd  VersionesColumnaCA*VersionesFilaCA, ArranqueMarino
                      dd  VersionesFilaCA, VersionesColumnaCA, 0
                                    ; InicioCocodriloFijo[1,1]
                     dd  ArranqueMarino, IdentificadorLagartoFijo, 0
                     dd  ActivoPAQ+VisiblePAQ+FijoFinPAQ+CocodriloPAQ
                     dd  0, 0, 0
                     dd  ArranqueMarino, IdentificadorLagartoFijo+1, 0
                     dd  ActivoPAQ+VisiblePAQ+FijoFinPAQ+CocodriloPAQ
                     dd  0, 0, 0
                                    ; InicioCocodriloFijo[2,1]
                     dd  ArranqueMarino, IdentificadorLagartoFijo  , 0
                     dd  ActivoPAQ+VisiblePAQ+FijoFinPAQ+CocodriloPAQ
                     dd  0, 0, 0
                     dd  ArranqueMarino, IdentificadorLagartoFijo+1, 0
                     dd  ActivoPAQ+VisiblePAQ+FijoFinPAQ+CocodriloPAQ
                     dd  0, 0, 0
                                    ; InicioCocodriloFijo[3,1]
                     dd  ArranqueMarino, IdentificadorLagartoFijo  , 0
                     dd  ActivoPAQ+VisiblePAQ+FijoFinPAQ+CocodriloPAQ
                     dd  0, 0, 0
                     dd  ArranqueMarino, IdentificadorLagartoFijo+1, 0
                     dd  ActivoPAQ+VisiblePAQ+FijoFinPAQ+CocodriloPAQ
                     dd  0, 0, 0
                                    ; InicioCocodriloFijo[4,1]
                     dd  ArranqueMarino, IdentificadorLagartoFijo  , 0
                     dd  ActivoPAQ+VisiblePAQ+FijoFinPAQ+CocodriloPAQ
                     dd  0, 0, 0
                     dd  ArranqueMarino, IdentificadorLagartoFijo+1, 0
                     dd  ActivoPAQ+VisiblePAQ+FijoFinPAQ+CocodriloPAQ
                     dd  0, 0, 0
                                    ; InicioCocodriloFijo[5,1]
                     dd  ArranqueMarino, IdentificadorLagartoFijo  , 0
                     dd  ActivoPAQ+VisiblePAQ+FijoFinPAQ+CocodriloPAQ
                     dd  0, 0, 0
                     dd  ArranqueMarino, IdentificadorLagartoFijo+1, 0
                     dd  ActivoPAQ+VisiblePAQ+FijoFinPAQ+CocodriloPAQ
                     dd  0, 0, 0
                                    ; Fin de datos de Cocodrilo
  MoscaFijoRef       dd  ArrayVariable+ReferenciaMarino*VersionesFilaMA
                     dd  VersionesFilaMA, VersionesFilaMA, ReferenciaMarino
                     dd  TerceraFranjaFila, 0, 0
                                    ; MoscaFijoRef[1]
                     dd  ReferenciaMarino, 0
                     dd  0, 0
                     dd  0, 0
                     dd  0, 0
                     dd  0, 16, 0, 16, 0
                                     ; MoscaFijoRef[2]
                     dd  ReferenciaMarino, 0
                     dd  0, 0
                     dd  0, 0
                     dd  0, 0
                     dd  0, 8, 0, 8, 0
                                    ; MoscaFijoRef[3]
                     dd  ReferenciaMarino, 0
                     dd  0, 0
                     dd  0, 0
                     dd  0, 0
                     dd  0, 16, 0, 16, 0
                                    ; MoscaFijoRef[4]
                     dd  ReferenciaMarino, 0
                     dd  0, 0
                     dd  0, 0
                     dd  0, 0
                     dd  0, 8, 0, 8, 0
                                    ; MoscaFijoRef[5]
                     dd  ReferenciaMarino, 0
                     dd  0, 0
                     dd  0, 0
                     dd  0, 0
                     dd  0, 4, 0, 4, 0
                                    ; Fin de CocodriloFijoRef
  InicioMoscaFijo    dd  MatrizVariable+ArranqueMarino*VersionesColumnaMA*VersionesFilaMA
                     dd  VersionesColumnaMA*VersionesFilaMA
                     dd  VersionesColumnaMA*VersionesFilaMA, ArranqueMarino
                     dd  VersionesFilaMA, VersionesColumnaMA, 0
                                    ; InicioMoscaFijo[1,1]
                     dd  ArranqueMarino, IdentificadorMoscaFijo  , 0
                     dd  ActivoPAQ+VisiblePAQ+FijoFinPAQ+MoscaPAQ
                     dd  0, 0, 0
                                    ; InicioMoscaFijo[2,1]
                     dd  ArranqueMarino, IdentificadorMoscaFijo  , 0
                     dd  ActivoPAQ+VisiblePAQ+FijoFinPAQ+MoscaPAQ
                     dd  0, 0, 0
                                    ; InicioMoscaFijo[3,1]
                     dd  ArranqueMarino, IdentificadorMoscaFijo  , 0
                     dd  ActivoPAQ+VisiblePAQ+FijoFinPAQ+MoscaPAQ
                     dd  0, 0, 0
                                    ; InicioMoscaFijo[4,1]
                     dd  ArranqueMarino, IdentificadorMoscaFijo  , 0
                     dd  ActivoPAQ+VisiblePAQ+FijoFinPAQ+MoscaPAQ
                     dd  0, 0, 0
                                    ; InicioMoscaFijo[5,1]
                     dd  ArranqueMarino, IdentificadorMoscaFijo  , 0
                     dd  ActivoPAQ+VisiblePAQ+FijoFinPAQ+MoscaPAQ
                     dd  0, 0, 0
                                    ; Fin de datos de Mosca
  AnfibioREF         dd  ArrayVariable+ReferenciaMarino
                     dd  1, 1, ReferenciaMarino
                     dd  PrimerFranjaFila, 0, 0
                                    ; RanaRef[1]
                     dd  ReferenciaMarino, 0
                     dd  0, 0
                     dd  0, 0
                     dd  0, 0
                     dd  0, 0, 0, 8, 0
                            ; es una rana
  InicioAnfibio      dd  MatrizVariable+ArranqueMarino
                     dd  1
                     dd  1, ArranqueMarino
                     dd  1, 1, 0
                                    ; InicioMoscaFijo[1,1]
                     dd  ArranqueMarino, IdentificadorAnfibio    , 1200
                     dd  ActivoPAQ+VisiblePAQ+AnfibioPAQ+AbajoPAQ+EstadoBPAQ+SolidarioPAQ
                     dd  0, 8, 0

.CODE
PROC InicializacionGeneral              ; numero identificacion 021
.CODE
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, DosLocales              ; espacio para locales

      mov  BanderaPantalla, FALSE       ; modo grafico inactivo
      mov  edi, OFFSET NombrePantalla   ; nombre de archivo con pantalla
      call OpenFileToRead               ; preparacion de lectura
      jnc  LeerArchivoPantalla021       ; si existe lee (salta)
      push ByteColor                    ; si no existe prepara
      push ColumnaPantalla              ; una nueva matriz vacia
      push FilaPantalla                 ; de tamano estandar
      call NewMatrizVariable            ; creando la MatrizVariable
      mov  PunteroPantalla, eax         ; llena de ceros que se guarda
      mov  esi, eax                     ; en PunteroPantalla y esi
      RL( CampoBase )                   ; el tamano de la Matriz
      mov  ecx, eax                     ; en ecx
      mov  edi, OFFSET NombrePantalla   ; y el nombre del archivo
      call SaveFile                     ; se crea el archivo
      mov  HandlePantalla, ebx          ; y se guarda el Handle
      jmp  CerrarPantalla021            ; finalmente cerrar el archivo
LeerArchivoPantalla021:
      mov  HandlePantalla, ebx          ; lectura del Handle de pantalla
      push HandlePantalla               ; se coloca en Stack
      call LeerRegistroFile             ; para LeerRegistroFile
      mov  PunteroPantalla, eax         ; y guardar PunteroPantalla
CerrarPantalla021:
      mov  ebx, HandlePantalla          ; lee el HandlePantalla
      call CloseFile                    ; y cierra el archivo
      EscribirEnter                     ; espera Enter de usuario
      call InitRandom
      call GenerarPaqueteFichas         ; procede a crear un paquete fichas
      cmp  ActivaPantalla, TRUE         ; verifica ActivaPantalla
      jne  SaltarAGrafico021            ; si no TRUE salta proceso grafico
      mov  eax, 0                       ; modo 0
      call InitGraph                    ; de tipo grafico
      jc   ErrorGeneral                 ; no logro inicializar
      mov  BanderaPantalla, TRUE        ; modo grafico activo
      mov  ecx, 0                       ; rectangulo
      mov  edx, 0                       ; en 0,0,319,199
      mov  esi, 319                     ; colocado en ecx, edx
      mov  edi, 199                     ; esi y edi
      mov  ebx, 0                       ; se borra ebx
      mov  bl, 68                       ; y se elige color 68
      call FillBlock                    ; escribe el bloque
      call SystemGetKey                 ; espera tecla de usuario
      push PunteroPantalla              ; coloca en Stack puntero a pantalla
      call PonerPantalla                ; pone la pantalla
      call SystemGetKey                 ; espera tecla de usuario
SaltarAGrafico021:


      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  CeroParametros               ; retorno liberacion de parametros
ENDP InicializacionGeneral

.CODE
PROC FinalizacionGeneral                ; numero identificacion 022
.CODE
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, CeroLocales             ; espacio para locales

      cmp  BanderaPantalla, TRUE        ; verificando la pantalla activa
      jne  IgnorarSetText022            ; si no esta activa ignorar
      call SetTextMode                  ; para desactivar el modo texto
      mov  BanderaPantalla, FALSE       ; coloca FALSE en BanderaPantalla
IgnorarSetText022:
      push OFFSET PunteroPantalla       ; direccion a PunteroPantalla VAR
      call DisposeMatrizVariable        ; para eliminarlo de memoria
      push OFFSET PunteroCentral        ; direccion a PunteroCentral VAR
      call DisposeMatrizVariable        ; para eliminarlo de memoria
      push OFFSET PunteroPaquete        ; direccion a PunteroPaquete VAR
      call DisposeCadenaEnlazada        ; para eliminarlo de memoria

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  CeroParametros               ; retorno liberacion de parametros
ENDP FinalizacionGeneral

.CODE
PROC PruebaGeneral                      ; numero identificacion 025
.DATA
  PunteroAPrueba025     dd      0       ; para puntero a Matriz
  Car1Der025            dd      0       ; para puntero a ficha

.CODE
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, UnLocal                 ; espacio para locales
                                        ; LocalA        : exitos en
                                        ;       prueba RandomBoolean

      cmp  BanderaPantalla, TRUE        ; detectango modo grafico
      jne  ProcederTextMode025          ; caso contrario lo ignora
      push PunteroPantalla              ; puntero a pantalla
      call PonerPantalla                ; lo visualiza
      call SystemGetKey                 ; presione tecla para continuar
      call CicloTemporalGeneral         ; llama a la rutina ciclica grafica
      jmp  Salida025                    ; y salta a Salida
ProcederTextMode025:
      Escribir( 'Inicio de Prueba General modo texto' )
                                        ; mensaje de aviso de modo texto
      call  Tiempo                      ; devuelve tiempo Tom en eax
      EscribirNumero( 'TiempoActual : ', eax )
                                        ; escribe el Tiempo al usuario
      mov   eax, 1000                   ; espera de 1000 ms
      call  SystemDelay                 ; mediante SystemDelay
      mov   eax, OFFSET Tiempo          ; llamado mediante OFFSET
      call  eax                         ; lee el tiempo nuevamente
      EscribirNumero( 'Tiempo 814 Tom aprox despues : ', eax )
                                        ; lo informa al usuario
      Escribir( 'Presione ESC para salir' )
                                        ; aviso de existencia de ESC
      call  CicloTemporalGeneral        ; ciclo temporal
      Escribir( 'Fin de Ciclo exitoso' )
                                        ; informe al usuario
RepiteRandom025:
      mov   eax, 10                     ; numero aleatorio de 0..9
      call GetRandom                    ; genera numero aleatorio
      EscribirNumero( 'NumeroAleatorio es (0..9) : ', eax )
                                        ; escribe el numero aleatorio
      Escribir( 'Presione tecla para repetir (ESC=salir)' )
                                        ; mensaje de ESC para salir
      call SystemGetKey                 ; espera respuesta de usuario
      cmp  al, CodigoESC                ; verifica CodigoESC para salir
      jne  RepiteRandom025              ; si no lo es nuevo Random
RepiteRandomLineal025:
      push 10                           ; numero aleatorio de 10..20
      push 20                           ; limites incluidos
      call RandomLineal                 ; genera numero aleatorio
      EscribirNumero( 'NumeroAleatorio es (20..10) : ', eax )
                                        ; escribe el numero aleatorio
      Escribir( 'Presione tecla para repetir (ESC=salir)' )
                                        ; mensaje de ESC para salir
      call SystemGetKey                 ; espera respuesta de usuario
      cmp  al, CodigoESC                ; verifica CodigoESC para salir
      jne  RepiteRandomLineal025        ; si no lo es nuevo Random
      Escribir( 'Ahorar probamos RandomBoolean' )
                                        ; informendo al usuario de prueba
      mov  eax, 0                       ; contador de exitos en LocalA
      mov  [ EBP+LocalA ], eax          ; usamos eax como pivote
      mov  eax, 1000000                 ; veces para hacer la prueba
RepiteRandomBoolean025:
      push eax                          ; el contador total se guarda en Stack
      push 10                           ; prueba con probabilidad %10
      push 100                          ; Random(0..ParametroA-1)<ParametroB
      call RandomBoolean                ; llamado a proceso Random
      cmp  eax, TRUE                    ; verifica la condicion TRUE
      jne  IgnorarContador025           ; si no se ignora
      mov  eax, [ EBP+LocalA ]          ; si TRUE se incrementa
      inc  eax                          ; LocalA en una unidad
      mov  [ EBP+LocalA ], eax          ; se guarda en el contador
IgnorarContador025:
      pop  eax                          ; se recupera contador total
      dec  eax                          ; se decrementa hasta cero
      cmp  eax, 0                       ; cuando llega a 0 fin
      jne  RepiteRandomBoolean025       ; si no repite ciclo
      Escribir( 'Se inicieron 1000000 pruebas con 10% probabilidad exito' )
                                        ; explicacion al usuario
      mov  eax, [ EBP+LocalA ]          ; informe de LocalA
      EscribirNumero( 'Resultado (e.aprox=100000) : ', eax )
                                        ; mediante macro de escritura
Salida025:

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  CeroParametros               ; retorno liberacion de parametros
ENDP PruebaGeneral

.CODE
PROC ActualizarPunteroCentral           ; numero identificacion 036
.CODE
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, UnLocal                 ; espacio para locales
                                        ; ParametroA    : TiempoActual
                                        ; Variables Locales
                                        ; LocalA        :
                                        ;       puntero Cadena actual

      push IdentificadorPantalla        ; busca IdentificadorPantalla
      push PunteroPaquete               ; en PunteroPaquete
      call BuscarIdentificadorCE        ; resultado en eax
      RL( PunteroDatoFE )               ; este es una pantalla central
      push 0                            ; limpia que refresca la image
      push 1                            ; mediante un PutImageVirtual
      push 1                            ; hacia PunteroCentral
      push NIL                          ; que servira de intermediario
      push PunteroCentral               ; para la imagen final en
      push eax                          ; PunteroPantalla
      call PutImageVirtual              ; luego hace la revision
      mov  eax, PunteroPaquete          ; del PunteroPaquete de fichas
RepiteRevisionPaquete036:
      mov  [ EBP+LocalA ], eax          ; FichaEnlazada por vez
      RL( DescriptorFE )                ; el DescriptorFE
      mov  edx, eax                     ; es la clave de interpretacion
      and  eax, ActivoPAQ+VisiblePAQ    ; si no es ActivoPAQ+VisiblePAQ
      cmp  eax, ActivoPAQ+VisiblePAQ    ; simplemente se ignora
      jne  FinCASE036                   ; y se pasa al siguiente
      mov  eax, edx                     ; edx es intermediario
      and  eax, FichaPAQ+CiclicoPAQ     ; se verifica caso
      cmp  eax, FichaPAQ+CiclicoPAQ     ; FichaPAQ+CiclicoPAQ, esto es
      je   FichaCiclicoPAQ036           ; un vehiculo o similar de una casilla
      mov  eax, edx                     ; edx contiene descriptor
      and  eax, TroncoPAQ+CiclicoPAQ    ; ahora condicion TroncoPAQ
      cmp  eax, TroncoPAQ+CiclicoPAQ    ; mediante cmp y and
      jne  TipoTortuga036               ; si no siguiente caso
      mov  eax, [ EBP+ParametroA ]      ; parametros para ProcesarTronco
      push eax                          ; que son el TiempoActual
      mov  eax, [ EBP+LocalA ]          ; y la FichaEnlazada actual
      push eax                          ; se utiliza eax como intermediario
      call ProcesarTronco               ; llamada a PROC
      jmp  FinCase036                   ; luego al fin del CASE conjunto
TipoTortuga036:
      mov  eax, edx                     ; ahora se consulta CASE
      and  eax, TortugaPAQ+CiclicoPAQ   ; TortugaPAQ+CiclicoPAQ mediante
      cmp  eax, TortugaPAQ+CiclicoPAQ   ; and y cmp con edx de pivote
      jne  TipoLagarto036               ; si no se pasa al siguiente
      mov  eax, [ EBP+ParametroA ]      ; caso contrario llama a PROC
      push eax                          ; ProcesarTortuga pero primero
      mov  eax, [ EBP+LocalA ]          ; coloca en Stack parametros
      push eax                          ; ParametroA y LocalA con eax
      call ProcesarTortuga              ; de pivote
      jmp  FinCase036                   ; luego al fin del CASE conjunto
TipoLagarto036:
      mov  eax, edx                     ; ahora se consulta CASE
      and  eax, FijoFinPAQ+CocodriloPAQ ; CocodriloPAQ+FijoFinPAQ mediante
      cmp  eax, FijoFinPAQ+CocodriloPAQ ; and y cmp con edx de pivote
      jne  TipoMosca036                 ; si no se pasa al siguiente
      mov  eax, [ EBP+ParametroA ]      ; caso contrario llama a PROC
      push eax                          ; ProcesarCocodrilo pero primero
      mov  eax, [ EBP+LocalA ]          ; coloca en Stack parametros
      push eax                          ; ParametroA y LocalA con eax
      call ProcesarCocodrilo            ; de pivote
      jmp  FinCASE036                   ; y finalmente al fin del CASE
TipoMosca036:
      mov  eax, edx                     ; ahora se consulta CASE
      and  eax, FijoFinPAQ+MoscaPAQ     ; FijoFinPAQ+MoscaPAQ mediante
      cmp  eax, FijoFinPAQ+MoscaPAQ     ; and y cmp con edx de pivote
      jne  TipoSerpiente036             ; si no se pasa al siguiente
      mov  eax, [ EBP+ParametroA ]      ; caso contrario llama a PROC
      push eax                          ; ProcesarTortuga pero primero
      mov  eax, [ EBP+LocalA ]          ; coloca en Stack parametros
      push eax                          ; ParametroA y LocalA con eax
      call ProcesarMosca                ; de pivote
      jmp  FinCASE036                   ; salida a Fin de CASE
TipoSerpiente036:
      jmp  FinCASE036
FichaCiclicoPAQ036:
      push BitImageTransparente         ; Caso FichaPAQ+CiclicoPAQ
      mov  eax, [ EBP+LocalA ]          ; se realiza el PutImageVirtual
      RL( ColumnaFE )                   ; a PunteroCentral
      sar  eax, BitsExtraCiclico        ; sar corrimiento con signo
      push eax                          ; los Bits extras hacen mas flexible
      mov  eax, [ EBP+LocalA ]          ; la velocidad
      RL( FilaFE )                      ; estamos en el proceso de colocar
      push eax                          ; el STACK para el PutImageVirtual
      push NIL                          ; NIL coloca la ficha completa
      push PunteroCentral               ; PunteroCentral es el destino
      mov  eax, [ EBP+LocalA ]          ; la matriz de imagen se guarda
      RL( PunteroDatoFE )               ; en LocalA.PunteroDatoFE
      push eax                          ; finalmente se llama al PROC
      call PutImageVirtual              ; el movimiento ciclico
      mov  eax, [ EBP+ParametroA ]      ; requiere reactualizacion de valores
      push eax                          ; para eso se llama al
      mov  eax, [ EBP+LocalA ]          ; PROC ProcesarFichaCiclica
      push eax                          ; con ParametroA y Ficha Actual
      call ProcesarFichaCiclica         ; de parametros
      jmp  FinCASE036                   ; fin del CASE
FinCASE036:
      mov  eax, [ EBP+LocalA ]          ; prosigue pasar a la siguiente ficha
      RL( SiguienteFE )                 ; LocalA = LocalA.SiguienteFE
      cmp  eax, NIL                     ; hasta encontrar NIL
      jne  RepiteRevisionPaquete036     ; repite ciclo mientras no NIL
      mov  eax, PunteroPaquete
RepiteMovil036:
      mov  [ EBP+LocalA ], eax
      RL( DescriptorFE )
      mov  edx, eax                     ; es la clave de interpretacion
      and  eax, ActivoPAQ+VisiblePAQ    ; si no es ActivoPAQ+VisiblePAQ
      cmp  eax, ActivoPAQ+VisiblePAQ    ; simplemente se ignora
      jne  FinCASEMovil036              ; y se pasa al siguiente
      mov  eax, edx
      and  eax, AnfibioPAQ
      cmp  eax, AnfibioPAQ
      jne  IgnorarAnfibio036
      mov  eax, [ EBP+ParametroA ]      ; caso contrario llama a PROC
      push eax                          ; ProcesarAnfibio pero primero
      mov  eax, [ EBP+LocalA ]          ; coloca en Stack parametros
      push eax                          ; ParametroA y LocalA con eax
      call ProcesarAnfibio              ; de pivote
      jmp  FinCASEMovil036
IgnorarAnfibio036:
      jmp  FinCASEMovil036
FinCaseMovil036:
      mov  eax, [ EBP+LocalA ]
      RL( SiguienteFE )
      cmp  eax, NIL
      jne  RepiteMovil036
Salida036:

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  UnParametro                  ; retorno liberacion de parametros
ENDP ActualizarPunteroCentral

.CODE
PROC GenerarPaqueteFichas               ; numero identificacion 036
.DATA
      CuadriculaOrigenPantalla036       dd  RectanguloLongInt
                                        dd  1, MargenPantalla+1
                                        dd  FilaPantalla
                                        dd  ColumnaPantalla-MargenPantalla
.CODE
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, CeroLocales             ; espacio para locales

      push ByteColor                    ; se genera una pantalla central
      push ColumnaPantalla-2*MargenPantalla
                                        ; que servira de receptor de cambios
      push FilaPantalla                 ; tiene la ventaja de realizar el
      call NewMatrizVariable            ; recorte de las fichas que salen
      mov  PunteroCentral, eax          ; de la pantalla central
      push 0                            ; el tamano es el del centro
      push 1                            ; hay que realizar
      push 1                            ; la transferencia de datos
      push OFFSET CuadriculaOrigenPantalla036
                                        ; desde PunteroPantalla
      push PunteroCentral               ; con una llamada a PutImageVirtual
      push PunteroPantalla              ; CuadriculaOrigenPantalla tiene
      call PutImageVirtual              ; una descripcion de posicion
      push PunteroCentral               ; para generar un gemelo
      call GemeloRegistro               ; de PunteroCentral en
      push eax                          ; eax que se pasa a Stack
      push PunteroPaquete               ; junto con actual
      push FichaEnlazada                ; PunteroPaquete
      call NewCadenaEnlazada            ; para alargar cadena
      mov  PunteroPaquete, eax          ; de fichas enlazada
      RG( DescriptorFE, ActivoPAQ+VisiblePAQ+PantallaPAQ )
                                        ; PantallaPAQ reconoce la pantalla
      mov  eax, PunteroPaquete          ; guarda la posicion
      RG( FilaFE, 1 )                   ; en coordenadas absolutas
      mov  eax, PunteroPaquete          ; de pantalla despliegue
      RG( ColumnaFE, MargenPantalla )   ; asigna IdentificadorPantalla
      mov  eax, PunteroPaquete          ; a IdentificadorFE
      RG( IdentificadorFE, IdentificadorPantalla )
                                        ; macro de guardar en memoria
      push ActivoPAQ+FichaPAQ+CiclicoPAQ
                                        ; descriptor en Stack
      push TotalCar1Der                 ; con GenerarCiclico1
      push FichaEnlazada
      push IdentificadorCar1DerA        ; se genera un paquete de fichas
      push OFFSET NombreCar1Der         ; enlazadas muy parecidas entre si
      call GenerarCiclico               ; el resultado se devuelve en eax
      push eax                          ; se enlaza con PunteroPaquete
      push PunteroPaquete               ; al final del mismo
      call AppendCadenaEnlazada         ; mediante PROC AppendCadenaEnlazada
      push ActivoPAQ+FichaPAQ+CiclicoPAQ
                                        ; descriptor en Stack
      push TotalCar1Izq                 ; con GenerarCiclico1
      push FichaEnlazada
      push IdentificadorCar1IzqA        ; se genera un paquete de fichas
      push OFFSET NombreCar1izq         ; enlazadas muy parecidas entre si
      call GenerarCiclico               ; el resultado se devuelve en eax
      push eax                          ; se enlaza con PunteroPaquete
      push PunteroPaquete               ; al final del mismo
      call AppendCadenaEnlazada         ; mediante PROC AppendCadenaEnlazada
      push ActivoPAQ+FichaPAQ+CiclicoPAQ
                                        ; descriptor en Stack
      push TotalCar2Der                 ; con GenerarCiclico1
      push FichaEnlazada
      push IdentificadorCar2DerA        ; se genera un paquete de fichas
      push OFFSET NombreCar2Der         ; enlazadas muy parecidas entre si
      call GenerarCiclico               ; el resultado se devuelve en eax
      push eax                          ; se enlaza con PunteroPaquete
      push PunteroPaquete               ; al final del mismo
      call AppendCadenaEnlazada         ; mediante PROC AppendCadenaEnlazada
      push ActivoPAQ+FichaPAQ+CiclicoPAQ
                                        ; descriptor en Stack
      push TotalCar2Izq                 ; con GenerarCiclico1
      push FichaEnlazada
      push IdentificadorCar2IzqA        ; se genera un paquete de fichas
      push OFFSET NombreCar2izq         ; enlazadas muy parecidas entre si
      call GenerarCiclico               ; el resultado se devuelve en eax
      push eax                          ; se enlaza con PunteroPaquete
      push PunteroPaquete               ; al final del mismo
      call AppendCadenaEnlazada         ; mediante PROC AppendCadenaEnlazada
      push ActivoPAQ+FichaPAQ+CiclicoPAQ
                                        ; descriptor en Stack
      push TotalCar3Der                 ; con GenerarCiclico1
      push FichaEnlazada
      push IdentificadorCar3DerA        ; se genera un paquete de fichas
      push OFFSET NombreCar3Der         ; enlazadas muy parecidas entre si
      call GenerarCiclico               ; el resultado se devuelve en eax
      push eax                          ; se enlaza con PunteroPaquete
      push PunteroPaquete               ; al final del mismo
      call AppendCadenaEnlazada         ; mediante PROC AppendCadenaEnlazada
      push ActivoPAQ+FichaPAQ+CiclicoPAQ
                                        ; descriptor en Stack
      push TotalCar3Izq                 ; con GenerarCiclico1
      push FichaEnlazada
      push IdentificadorCar3IzqA        ; se genera un paquete de fichas
      push OFFSET NombreCar3izq         ; enlazadas muy parecidas entre si
      call GenerarCiclico               ; el resultado se devuelve en eax
      push eax                          ; se enlaza con PunteroPaquete
      push PunteroPaquete               ; al final del mismo
      call AppendCadenaEnlazada         ; mediante PROC AppendCadenaEnlazada
      push ActivoPAQ+FichaPAQ+CiclicoPAQ
                                        ; descriptor en Stack
      push TotalCar4Der                 ; con GenerarCiclico1
      push FichaEnlazada
      push IdentificadorCar4DerA        ; se genera un paquete de fichas
      push OFFSET NombreCar4Der         ; enlazadas muy parecidas entre si
      call GenerarCiclico               ; el resultado se devuelve en eax
      push eax                          ; se enlaza con PunteroPaquete
      push PunteroPaquete               ; al final del mismo
      call AppendCadenaEnlazada         ; mediante PROC AppendCadenaEnlazada
      push ActivoPAQ+FichaPAQ+CiclicoPAQ
                                        ; descriptor en Stack
      push TotalCar4Izq                 ; con GenerarCiclico1
      push FichaEnlazada
      push IdentificadorCar4IzqA        ; se genera un paquete de fichas
      push OFFSET NombreCar4izq         ; enlazadas muy parecidas entre si
      call GenerarCiclico               ; el resultado se devuelve en eax
      push eax                          ; se enlaza con PunteroPaquete
      push PunteroPaquete               ; al final del mismo
      call AppendCadenaEnlazada         ; mediante PROC AppendCadenaEnlazada
      push ActivoPAQ+FichaPAQ+CiclicoPAQ
                                        ; descriptor en Stack
      push TotalCam1Der                 ; con GenerarCiclico1
      push FichaEnlazada
      push IdentificadorCam1DerA        ; se genera un paquete de fichas
      push OFFSET NombreCam1Der         ; enlazadas muy parecidas entre si
      call GenerarCiclico               ; el resultado se devuelve en eax
      push eax                          ; se enlaza con PunteroPaquete
      push PunteroPaquete               ; al final del mismo
      call AppendCadenaEnlazada         ; mediante PROC AppendCadenaEnlazada
      push ActivoPAQ+FichaPAQ+CiclicoPAQ
                                        ; descriptor en Stack
      push TotalCam1Izq                 ; con GenerarCiclico1
      push FichaEnlazada
      push IdentificadorCam1IzqA        ; se genera un paquete de fichas
      push OFFSET NombreCam1izq         ; enlazadas muy parecidas entre si
      call GenerarCiclico               ; el resultado se devuelve en eax
      push eax                          ; se enlaza con PunteroPaquete
      push PunteroPaquete               ; al final del mismo
      call AppendCadenaEnlazada         ; mediante PROC AppendCadenaEnlazada
      push ActivoPAQ+FichaPAQ+CiclicoPAQ
                                        ; descriptor en Stack
      push TotalCam2Der                 ; con GenerarCiclico1
      push FichaEnlazada
      push IdentificadorCam2DerA        ; se genera un paquete de fichas
      push OFFSET NombreCam2Der         ; enlazadas muy parecidas entre si
      call GenerarCiclico               ; el resultado se devuelve en eax
      push eax                          ; se enlaza con PunteroPaquete
      push PunteroPaquete               ; al final del mismo
      call AppendCadenaEnlazada         ; mediante PROC AppendCadenaEnlazada
      push ActivoPAQ+FichaPAQ+CiclicoPAQ
                                        ; descriptor en Stack
      push TotalCam2Izq                 ; con GenerarCiclico1
      push FichaEnlazada
      push IdentificadorCam2IzqA        ; se genera un paquete de fichas
      push OFFSET NombreCam2izq         ; enlazadas muy parecidas entre si
      call GenerarCiclico               ; el resultado se devuelve en eax
      push eax                          ; se enlaza con PunteroPaquete
      push PunteroPaquete               ; al final del mismo
      call AppendCadenaEnlazada         ; mediante PROC AppendCadenaEnlazada
      push ActivoPAQ+CiclicoPAQ+TroncoPAQ
                                        ; banderas basicas del paquete
      push TotalTronco6                 ; cantidad de copias
      push MarinoEnlazado               ; tipo de dato MarinoEnlazado
      push IdentificadorTronco6         ; identificador inicial de la lista
      push OFFSET NombreTronco          ; archivo con imagen
      call GenerarCiclico               ; proceso de generacion de fichas
      push eax                          ; agrega la nueva lista como eax
      push PunteroPaquete               ; a PunteroPaquete
      call AppendCadenaEnlazada         ; mediante AppendCadenaEnlazada
      push ActivoPAQ+CiclicoPAQ+TroncoPAQ
                                        ; banderas basicas del paquete
      push TotalTronco8                 ; cantidad de copias
      push MarinoEnlazado               ; tipo de dato MarinoEnlazado
      push IdentificadorTronco8         ; identificador inicial de la lista
      push OFFSET NombreTronco          ; archivo con imagen
      call GenerarCiclico               ; proceso de generacion de fichas
      push eax                          ; agrega la nueva lista como eax
      push PunteroPaquete               ; a PunteroPaquete
      call AppendCadenaEnlazada         ; mediante AppendCadenaEnlazada
      push ActivoPAQ+CiclicoPAQ+TroncoPAQ
                                        ; banderas basicas del paquete
      push TotalTronco10                ; cantidad de copias
      push MarinoEnlazado               ; tipo de dato MarinoEnlazado
      push IdentificadorTronco10        ; identificador inicial de la lista
      push OFFSET NombreTronco          ; archivo con imagen
      call GenerarCiclico               ; proceso de generacion de fichas
      push eax                          ; agrega la nueva lista como eax
      push PunteroPaquete               ; a PunteroPaquete
      call AppendCadenaEnlazada         ; mediante AppendCadenaEnlazada
      push ActivoPAQ+CiclicoPAQ+TortugaPAQ
                                        ; banderas basicas del paquete
      push TotalTortuga7Der             ; cantidad de copias
      push MarinoEnlazado               ; tipo de dato MarinoEnlazado
      push IdentificadorTortuga7Der     ; identificador inicial de la lista
      push OFFSET NombreTortuDer        ; archivo con imagen
      call GenerarCiclico               ; proceso de generacion de fichas
      push eax                          ; agrega la nueva lista como eax
      push PunteroPaquete               ; a PunteroPaquete
      call AppendCadenaEnlazada         ; mediante AppendCadenaEnlazada
      push ActivoPAQ+CiclicoPAQ+TortugaPAQ
                                        ; banderas basicas del paquete
      push TotalTortuga7Izq             ; cantidad de copias
      push MarinoEnlazado               ; tipo de dato MarinoEnlazado
      push IdentificadorTortuga7Izq     ; identificador inicial de la lista
      push OFFSET NombreTortuIzq        ; archivo con imagen
      call GenerarCiclico               ; proceso de generacion de fichas
      push eax                          ; agrega la nueva lista como eax
      push PunteroPaquete               ; a PunteroPaquete
      call AppendCadenaEnlazada         ; mediante AppendCadenaEnlazada
      push ActivoPAQ+CiclicoPAQ+TortugaPAQ
                                        ; banderas basicas del paquete
      push TotalTortuga9Der             ; cantidad de copias
      push MarinoEnlazado               ; tipo de dato MarinoEnlazado
      push IdentificadorTortuga9Der     ; identificador inicial de la lista
      push OFFSET NombreTortuDer        ; archivo con imagen
      call GenerarCiclico               ; proceso de generacion de fichas
      push eax                          ; agrega la nueva lista como eax
      push PunteroPaquete               ; a PunteroPaquete
      call AppendCadenaEnlazada         ; mediante AppendCadenaEnlazada
      push ActivoPAQ+CiclicoPAQ+TortugaPAQ
                                        ; banderas basicas del paquete
      push TotalTortuga9Izq             ; cantidad de copias
      push MarinoEnlazado               ; tipo de dato MarinoEnlazado
      push IdentificadorTortuga9Izq     ; identificador inicial de la lista
      push OFFSET NombreTortuIzq        ; archivo con imagen
      call GenerarCiclico               ; proceso de generacion de fichas
      push eax                          ; agrega la nueva lista como eax
      push PunteroPaquete               ; a PunteroPaquete
      call AppendCadenaEnlazada         ; mediante AppendCadenaEnlazada
      push ActivoPAQ+CocodriloPAQ+FijoFinPAQ
                                        ; banderas basicas del paquete
      push TotalCocodriloFijo           ; cantidad de copias
      push MarinoEnlazado               ; tipo de dato MarinoEnlazado
      push IdentificadorLagartoFijo     ; identificador inicial de la lista
      push OFFSET NombreCocodrilo       ; archivo con imagen
      call GenerarCiclico               ; proceso de generacion de fichas
      push eax                          ; agrega la nueva lista como eax
      push PunteroPaquete               ; a PunteroPaquete
      call AppendCadenaEnlazada         ; mediante AppendCadenaEnlazada
      push ActivoPAQ+MoscaPAQ+FijoFinPAQ
                                        ; banderas basicas del paquete
      push TotalMoscaFijo               ; cantidad de copias
      push MarinoEnlazado               ; tipo de dato MarinoEnlazado
      push IdentificadorMoscaFijo       ; identificador inicial de la lista
      push OFFSET NombreMosca           ; archivo con imagen
      call GenerarCiclico               ; proceso de generacion de fichas
      push eax                          ; agrega la nueva lista como eax
      push PunteroPaquete               ; a PunteroPaquete
      call AppendCadenaEnlazada         ; mediante AppendCadenaEnlazada
      push ActivoPAQ+AnfibioPAQ
                                        ; banderas basicas del paquete
      push 1                            ; cantidad de copias
      push MarinoEnlazado               ; tipo de dato MarinoEnlazado
      push IdentificadorAnfibio         ; identificador inicial de la lista
      push OFFSET NombreAnfibio         ; archivo con imagen
      call GenerarCiclico               ; proceso de generacion de fichas
      push eax                          ; agrega la nueva lista como eax
      push PunteroPaquete               ; a PunteroPaquete
      call AppendCadenaEnlazada         ; mediante AppendCadenaEnlazada
      push NivelPaquete                 ; se inicializa Paquete de datos
      push PunteroPaquete               ; con NivelPaquete que se encuentra
      call InicializarNivel             ; en Nivel 1 al inicio

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  CeroParametros               ; retorno liberacion de parametros
ENDP GenerarPaqueteFichas

.CODE
PROC ProcedimientoUsuarioCiclo          ; numero identificacion 034
.DATA
      BanderaPrimero034                  dd TRUE
                                        ; es la primera vez que se ejecuta
                                        ; el ciclo
.CODE
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, CeroLocales             ; espacio para locales
                                        ; ParametroA    : TiempoActual

      cmp  BanderaPrimero034, TRUE      ; verifica si es la primera vez
      jne  IgnorarPrimero034            ; si no lo es salta
      mov  BanderaPrimero034, FALSE     ; simplemente desactiva la bandera
IgnorarPrimero034:
      call LeerTeclaActiva              ; procede a intentar lectura
      mov  eax, FALSE                   ; devuelve FALSE como fin defecto
      cmp  BanderaTecla, FALSE          ; consulta de tecla ESC
      je   Salir034                     ; si la detecta manda TRUE como
      cmp  BanderaTeclaEspecial, TRUE   ; senal de salida
      je   TeclaEspecial034             ; para ello BanderaTecla = TRUE
      cmp  TeclaOpcion, CodigoESC       ; CodigoESC en TeclaOpcion
      jne  Salir034                     ; y no es tecla extendida
      mov  eax, TRUE                    ; Tecla ESC produce TRUE de fin
TeclaEspecial034:
      cmp  TeclaOpcion, CodigoAvPag     ; verifica CodigoAvPag
      jne  Salir034                     ; que produce un cambio de nivel
      inc  NivelPaquete                 ; forzado mediante
      push NivelPaquete                 ; una llamada a InicializarNivel
      push PunteroPaquete               ; los parametros a Stack
      call InicializarNivel             ; llamado al PROC
      jmp  Salir034                     ; fin del CASE
Salir034:

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  UnParametro                  ; retorno liberacion de parametros
ENDP ProcedimientoUsuarioCiclo

.CODE
PROC RandomBoolean                      ; numero identificacion 044
.CODE
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, CeroLocales             ; espacio para locales
                                        ; ParametroA :
                                        ;       Valor a pasar a GetRandom
                                        ;       resultado 0..AX-1
                                        ; ParametroB : criterio TRUE
                                        ;       Random < ParametroB
                                        ; OUT EAX    : TRUE o FALSE segun
                                        ;       cumple criterio

      mov  eax, [ EBP+ParametroA ]      ; cargo intervalo Random
      cmp  eax, 0                       ; caso 0 siempre TRUE
      jne  IgnorarEspecial044           ; caso contrario continua
      mov  edx, TRUE                    ; asigna 0 por caso trivial
      jmp  IgnorarFalse044              ; asignacion final
IgnorarEspecial044:
      call GetRandom                    ; genera aleatorio
      mov  edx, TRUE                    ; alternativa posible
      mov  ebx, [ EBP+ParametroB ]      ; se verifica comparando
      cmp  eax, ebx                     ; con ParametroB
      jl   IgnorarFALSE044              ; Random < ParametroB
      mov  edx, FALSE                   ; caso contrario FALSE
IgnorarFALSE044:
      mov  eax, edx                     ; eax = resultado

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  DosParametros                ; retorno liberacion de parametros
ENDP RandomBoolean

.CODE
PROC InicializarNivel                   ; numero identificacion 045
.CODE
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, CeroLocales             ; espacio para locales
                                        ; ParametroA    : puntero paquete
                                        ;       de fichas
                                        ; ParametroB    : nivel

      mov  eax, [ EBP+ParametroA ]      ; inicio de paquete
      cmp  eax, NIL                     ; se verifica no NIL
      je   Fin045                       ; en ese caso no hace nada
CiclicoAnulador045:
      mov  edx, eax                     ; en edx FichaEnlazada actual
      RL( DescriptorFE )                ; FichaEnlazada.DescriptorFE
      mov  ebx, eax                     ; copia de banderas en ebx
      and  eax, CiclicoPAQ
                                        ; grupo que se vuelve invisible
      cmp  eax, 0                       ; si and = 0 no pertenece
      je   IgnorarInvisibilidad045      ; se mantiene en su estado
      and  ebx, ConjuntoTotal xor VisiblePAQ
                                        ; para anular VisiblePAQ
      mov  eax, edx                     ; FichaEnlazada.DescriptorFE
      RG( DescriptorFE, ebx )           ;       -VisiblePAQ
IgnorarInvisibilidad045:
      mov  eax, edx                     ; se avanza hacia la siguiente
      RL( SiguienteFE )                 ; FichaEnlazada
      cmp  eax, NIL                     ; el ciclo se repite hasta
      jne  CiclicoAnulador045           ; encontrar NIL
      mov  eax, [ EBP+ParametroB ]      ; se carga nivel
      push eax                          ; se inicializa Paquete de datos
      push OFFSET InicioFila1           ; a nivel de Fila1 con una
      push OFFSET InicioCiclicoFila1    ; llamada a InicializarCiclicoFila
      push PunteroPaquete               ; con NivelPaquete que se encuentra
      call InicializarCiclicoFila       ; en Nivel 1 al inicio
      mov  eax, [ EBP+ParametroB ]      ; se carga nivel
      push eax                          ; se inicializa Paquete de datos
      push OFFSET InicioFila2           ; a nivel de Fila2 con una
      push OFFSET InicioCiclicoFila2    ; llamada a InicializarCiclicoFila
      push PunteroPaquete               ; con NivelPaquete que se encuentra
      call InicializarCiclicoFila       ; en Nivel 1 al inicio
      mov  eax, [ EBP+ParametroB ]      ; se carga nivel
      push eax                          ; se inicializa Paquete de datos
      push OFFSET InicioFila3           ; a nivel de Fila3 con una
      push OFFSET InicioCiclicoFila3    ; llamada a InicializarCiclicoFila
      push PunteroPaquete               ; con NivelPaquete que se encuentra
      call InicializarCiclicoFila       ; en Nivel 1 al inicio
      mov  eax, [ EBP+ParametroB ]      ; se carga nivel
      push eax                          ; se inicializa Paquete de datos
      push OFFSET InicioFila4           ; a nivel de Fila4 con una
      push OFFSET InicioCiclicoFila4    ; llamada a InicializarCiclicoFila
      push PunteroPaquete               ; con NivelPaquete que se encuentra
      call InicializarCiclicoFila       ; en Nivel 1 al inicio
      mov  eax, [ EBP+ParametroB ]      ; se carga nivel
      push eax                          ; se inicializa Paquete de datos
      push OFFSET InicioFila5           ; a nivel de Fila4 con una
      push OFFSET InicioCiclicoFila5    ; llamada a InicializarCiclicoFila
      push PunteroPaquete               ; con NivelPaquete que se encuentra
      call InicializarCiclicoFila       ; en Nivel 1 al inicio
      mov  eax, [ EBP+ParametroB ]      ; se carga nivel
      push eax                          ; se inicializa Paquete de datos
      push OFFSET InicioFila6           ; a nivel de Fila6 con una
      push OFFSET InicioCiclicoFila6    ; llamada a InicializarCiclicoFila
      push PunteroPaquete               ; con NivelPaquete que se encuentra
      call InicializarCiclicoFila       ; en Nivel 1 al inicio
      mov  eax, [ EBP+ParametroB ]      ; se carga nivel
      push eax                          ; se inicializa Paquete de datos
      push OFFSET InicioFila8           ; a nivel de Fila8 con una
      push OFFSET InicioCiclicoFila8    ; llamada a InicializarCiclicoFila
      push PunteroPaquete               ; con NivelPaquete que se encuentra
      call InicializarCiclicoFila       ; en Nivel 1 al inicio
      mov  eax, [ EBP+ParametroB ]      ; se carga nivel
      push eax                          ; se inicializa Paquete de datos
      push OFFSET InicioFila10          ; a nivel de Fila10 con una
      push OFFSET InicioCiclicoFila10   ; llamada a InicializarCiclicoFila
      push PunteroPaquete               ; con NivelPaquete que se encuentra
      call InicializarCiclicoFila       ; en Nivel 1 al inicio
      mov  eax, [ EBP+ParametroB ]      ; se carga nivel
      push eax                          ; se inicializa Paquete de datos
      push OFFSET InicioFila7           ; a nivel de Fila7 con una
      push OFFSET InicioCiclicoFila7    ; llamada a InicializarCiclicoFila
      push PunteroPaquete               ; con NivelPaquete que se encuentra
      call InicializarCiclicoFila       ; en Nivel 1 al inicio
      mov  eax, [ EBP+ParametroB ]      ; se carga nivel
      push eax                          ; se inicializa Paquete de datos
      push OFFSET InicioFila9           ; a nivel de Fila7 con una
      push OFFSET InicioCiclicoFila9    ; llamada a InicializarCiclicoFila
      push PunteroPaquete               ; con NivelPaquete que se encuentra
      call InicializarCiclicoFila       ; en Nivel 1 al inicio
      mov  eax, [ EBP+ParametroB ]      ; se carga nivel
      push eax                          ; se inicializa Paquete de datos
      push OFFSET InicioCocodriloFijo   ; a nivel de Fila Cocodrilo con una
      push OFFSET CocodriloFijoREF      ; llamada a InicializarCiclicoFila
      push PunteroPaquete               ; con NivelPaquete que se encuentra
      call InicializarCiclicoFila       ; en Nivel 1 al inicio
      mov  eax, [ EBP+ParametroB ]      ; se carga nivel
      push eax                          ; se inicializa Paquete de datos
      push OFFSET InicioMoscaFijo       ; a nivel de Fila Cocodrilo con una
      push OFFSET MoscaFijoREF          ; llamada a InicializarCiclicoFila
      push PunteroPaquete               ; con NivelPaquete que se encuentra
      call InicializarCiclicoFila       ; en Nivel 1 al inicio
      mov  eax, [ EBP+ParametroB ]      ; se carga nivel
      push eax                          ; se inicializa Paquete de datos
      push OFFSET InicioAnfibio         ; a nivel de AnfibioREF con una
      push OFFSET AnfibioREF            ; llamada a InicializarCiclicoFila
      push PunteroPaquete               ; con NivelPaquete que se encuentra
      call InicializarCiclicoFila       ; en Nivel 1 al inicio
Fin045:

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  DosParametros                ; retorno liberacion de parametros
ENDP InicializarNivel

.CODE
PROC ProcesarTronco                     ; numero identificacion 046
.CODE
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, TresLocales             ; espacio para locales
                                        ; ParametroA   : es el puntero a
                                        ;        ficha enlazada
                                        ; ParametroB   : es el Tiempo actual
                                        ; VariablesLocales
                                        ; LocalA       : columna verdadera
                                        ; LocalB       : contador de
                                        ;        tamano de tronco
                                        ; LocalC       : DescriptorME

      mov  eax, [ EBP+ParametroA ]      ; proceso para leer DescriptorME
      RL( DescriptorME )                ; y desactivar ReinicioMarinoPAQ
      and  eax, ConjuntoTotal xor ReinicioMarinoPAQ
                                        ; si necesario
      mov  [ EBP+LocalC ], eax          ; se guarda resultado en LocalC
      push BitImageTransparente         ; Caso FichaPAQ+CiclicoPAQ
      mov  eax, [ EBP+ParametroA ]      ; se realiza el PutImageVirtual
      RL( ColumnaFE )                   ; a PunteroCentral
      sar  eax, BitsExtraCiclico        ; sar corrimiento con signo
      mov  [ EBP+LocalA ], eax          ; LocalA guarda Columna verdadera
      push eax                          ; los Bits extras hacen mas flexible
      mov  eax, [ EBP+ParametroA ]      ; la velocidad
      RL( FilaFE )                      ; estamos en el proceso de colocar
      push eax                          ; el STACK para el PutImageVirtual
      push 1                            ; inicio del tronco con 1
      call GenerarCuadriculaBufferA     ; genera RectanguloLongInt
      push OFFSET BufferParametroA      ; en OFFSET BufferParametroA
      push PunteroCentral               ; PunteroCentral es el destino
      mov  eax, [ EBP+ParametroA ]      ; la matriz de imagen se guarda
      RL( PunteroDatoFE )               ; en LocalA.PunteroDatoFE
      push eax                          ; finalmente se llama al PROC
      call PutImageVirtual              ; el movimiento ciclico
      mov  eax, [ EBP+ParametroA ]      ; en ParametroA el MarinoEnlazado
      RL( AdyacentesME )                ; se lee AdyacentesME
      mov  [ EBP+LocalB ], eax          ; que se guarda como LocalB
RepiteLargoTronco046:
      mov  eax, [ EBP+LocalB ]          ; este ciclo imprime el medio
      cmp  eax, 2                       ; del tronco interno LocalB-2
      jle  SalirCiclo046                ; veces luego sale
      dec  eax                          ; decrementa el contador cada vez
      mov  [ EBP+LocalB ], eax          ; y lo guarda
      push BitImageTransparente         ; como regular activa Transparente
      mov  eax, [ EBP+LocalA ]          ; columna verdadera se
      add  eax, LargoYBasicoFicha       ; incremente en LargoYBasicoFicha
      mov  [ EBP+LocalA ], eax          ; y se guarda nuevamente
      push eax                          ; generamos la cuadricula interna
      mov  eax, [ EBP+ParametroA ]      ; objetivo con la columna y la
      RL( FilaFE )                      ; fila en ParametroA
      push eax                          ; ademas se utiliza un 2 para
      push 2                            ; ubicar el sector interno de la
      call GenerarCuadriculaBufferA     ; imagen interna
      push OFFSET BufferParametroA      ; cuadricula en BufferParametroA
      push PunteroCentral               ; PunteroCentral es el destino
      mov  eax, [ EBP+ParametroA ]      ; la matriz de imagen se guarda
      RL( PunteroDatoFE )               ; en LocalA.PunteroDatoFE
      push eax                          ; finalmente se llama al PROC
      call PutImageVirtual              ; el movimiento ciclico
      jmp  RepiteLargoTronco046         ; se repite el ciclo de tronco interno
SalirCiclo046:
      push BitImageTransparente         ; Caso FichaPAQ+CiclicoPAQ
      mov  eax, [ EBP+LocalA ]          ; se lee columna verdadera
      add  eax, LargoYBasicoFicha       ; para dibujar el final de tronco
      mov  [ EBP+LocalA ], eax          ; actualizando columna verdadera
      push eax                          ; los Bits extras hacen mas flexible
      mov  eax, [ EBP+ParametroA ]      ; la velocidad
      RL( FilaFE )                      ; estamos en el proceso de colocar
      push eax                          ; el STACK para el PutImageVirtual
      push 3                            ; posicion 3 interna
      call GenerarCuadriculaBufferA     ; que es el final de tronco
      push OFFSET BufferParametroA      ; RectanguloLongInt en buffer
      push PunteroCentral               ; PunteroCentral es el destino
      mov  eax, [ EBP+ParametroA ]      ; la matriz de imagen se guarda
      RL( PunteroDatoFE )               ; en LocalA.PunteroDatoFE
      push eax                          ; finalmente se llama al PROC
      call PutImageVirtual              ; el movimiento ciclico
      mov  eax, [ EBP+ParametroB ]      ; ahora se considera actualizar
      push eax                          ; el movimiento ciclico del tronco
      mov  eax, [ EBP+ParametroA ]      ; con ProcesarFichaCiclica
      push eax                          ; el cual devuelve boolean
      call ProcesarFichaCiclica         ; informando si reinicio de ciclo
      cmp  eax, TRUE                    ; si no es TRUE se salta
      jne  SalirProcesar046             ; si lo es Random para tamano
      mov  eax, [ EBP+LocalC ]          ; LocalC+ReinicioMarinoPAQ
      or   eax, ReinicioMarinoPAQ       ; por detectar reinicio
      mov  [ EBP+LocalC ], eax          ; se guarda en LocalC
      mov  eax, [ EBP+ParametroA ]      ; la probabilidad de agrandado+1
      RL( ReferenciaME )                ; lo toma del dato ParametroA., etx
      RL( ProbabilidadARM )             ;    .ReferenciaME.ProbabilidadARM
      cmp  eax, 0                       ; si es 0 se ignora agrandado
      je   SalirProcesar046             ; caso contrario RandomBoolean
      push 1                            ; 1/ProbabilidadARM probabilidad
      push eax                          ; de agrandado, otro normal
      call RandomBoolean                ; el agrandado o no se indica
      mov  ecx, 0                       ; usando ecx con un incremento de 1
      cmp  eax, FALSE                   ; o de 0 segun si agrandado o no
      je   IgnorarAgrandar046           ; la resultado TRUE o FALSE
      mov  ecx, 1                       ; de RandomBoolean lo determina
IgnorarAgrandar046:
      mov  eax, [ EBP+ParametroA ]      ; ParametroA.ReferenciaME.,  etc
      RL( ReferenciaME )                ;    TamanoBasicoRM es el tamano
      RL( TamanoBasicoRM )              ; normal que combinado con ecx
      add  ecx, eax                     ; se guarda en ParametroA.AdyacentesME
      mov  eax, [ EBP+ParametroA ]      ; mediante el macroRG
      RG( AdyacentesME, ecx )           ; usando ecx como pivote
SalirProcesar046:
      mov  ecx, [ EBP+LocalC ]          ; se actualiza el valor
      mov  eax, [ EBP+ParametroA ]      ; de banderas en DescriptorME
      RG( DescriptorME, ecx )           ; talvez cambie ReinicioMarinoPAQ

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  DosParametros                ; retorno liberacion de parametros
ENDP ProcesarTronco

PROC GenerarCuadriculaBufferA           ; numero identificacion 047
                                        ; genera una cuadricula de ficha
                                        ; normal, se supone que esta dividida
                                        ; en cuadriculas de tamano
                                        ; (Fila,Columna)=
                                        ; LargoXBasicoFicha-LargoYBasicoFicha
.CODE
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, CeroLocales             ; espacio para locales
                                        ; ParametroA   : NumeroCuadricula

      mov  eax, OFFSET BufferParametroA ; lee el OFFSET del buffer
      RG( CampoBase, RectanguloLongInt )
                                        ; guarda RectanguloLongInt como tipo
      mov  eax, OFFSET BufferParametroA ; y tamano se supone que
      RG( PosicionX0RL, 1 )             ; fila es fija 1..LargoXBasicoFicha
      mov  eax, [ EBP+ParametroA ]      ; calzando con la "cuadricula"
      dec  eax                          ; hipotetica, el que varia
      mov  edx, eax                     ; es columna segun ParametroA
      mov  ecx, LargoYBasicoFicha       ; en el intervalo
      mul  ecx                          ; ( ParametroA-1 )*LargoYBasicoFicha+1
      inc  eax                          ;    ..ParametroA*LargoYBasicoFicha
      mov  ebx, eax                     ; la cuadricula asi disenada
      mov  eax, OFFSET BufferParametroA ; como un Rectangulo LongInt
      RG( PosicionY0RL, ebx )           ; en OFFSET BufferParametroA
      mov  eax, OFFSET BufferParametroA ; existen a veces interferencias
      RG( PosicionX1RL, LargoXBasicoFicha )
                                        ; en la generacion de punteros
      mov  eax, [ EBP+ParametroA ]      ; en modo grafico
      mov  ecx, LargoYBasicoFicha       ; las multiplicaciones se realizan
      mul  ecx                          ; con ecx como pivote
      mov  ebx, eax                     ; y para guarda se utiliza
      mov  eax, OFFSET BufferParametroA ; la macro RG con
      RG( PosicionY1RL, ebx )           ; eax=OFFSET BufferParametroA

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  UnParametro                  ; retorno liberacion de parametros
ENDP GenerarCuadriculaBufferA

.CODE
PROC ProcesarTortuga                    ; numero identificacion 048
.CODE
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, TresLocales             ; espacio para locales
                                        ; ParametroA   : es el puntero a
                                        ;        ficha enlazada
                                        ; ParametroB   : es el Tiempo actual
                                        ; Variables Locales
                                        ; LocalA       : DescriptorME
                                        ; LocalB       : posicion columna
                                        ; LocalC       : bandera reinicio
                                        ;        de ciclo

      mov  eax, [ EBP+ParametroA ]      ; el primer paso es
      RL( DescriptorME )                ; desactivar ReinicioMarinoPAQ
      and  eax, ConjuntoTotal xor ReinicioMarinoPAQ
                                        ; debe de estudiarse de nuevo
      mov  [ EBP+LocalA ], eax          ; LocalA guarda DescriptorME
      mov  eax, [ EBP+LocalA ]          ; la bandera SoportePAQ
      and  eax, SoportePAQ              ; se desactiva si la tortuga
      cmp  eax, 0                       ; es invisible por eso
      je   IgnorarImprimir048           ; el je de no imprimir
      mov  ecx, 1                       ; la ficha posee 4 casillas
      mov  eax, [ EBP+LocalA ]          ; las 2 primeras son tortugas
      and  eax, SumergiblePAQ           ; normales, caso ecx=1..2
      cmp  eax, 0                       ; SumergibleActivoPAQ indica
      je   TortugaNormal048             ; Tortuga que se sumerge
      mov  eax, [ EBP+LocalA ]          ; caso ecx=3..4
      and  eax, SumergibleActivoPAQ     ; lo primero que hacemos
      cmp  eax, 0                       ; es colocar por defecto ecx 1
      je   TortugaNormal048             ; y luego estudiar la posibilidad
      mov  ecx, 3                       ; de colocar ecx=3
TortugaNormal048:
      mov  eax, [ EBP+LocalA ]          ; ambos tienen dos estados
      and  eax, EstadoAPAQ              ; el EstadoAPAQ le suma 1 a ecx
      cmp  eax, 0                       ; primero se detecta la bandera
      je   IgnorarEstadoA048            ; si no esta presente ecx igual
      inc  ecx                          ; caso contrario se suma 1
IgnorarEstadoA048:
      push ecx                          ; GenerarCuadriculaBufferA
      call GenerarCuadriculaBufferA     ; genera un RectanguloLongInt
      mov  eax, [ EBP+ParametroA ]      ; en OFFSET BufferParametroA
      RL( ColumnaFE )                   ; que es variable global
      sar  eax, BitsExtraCiclico        ; en LocalB se guarda ColumnaFE
      mov  [ EBP+LocalB ], eax          ; corregida a precision corriente
      mov  eax, [ EBP+ParametroA ]      ; se usa LocalB como pivote
      RL( AdyacentesME )                ; para colocar un total de
      cmp  eax, 0                       ; AdyacentesME tortugas seguidas
      je   IgnorarImprimir048           ; si 0 tortugas salta
RepetirAdyacente048:
      push eax                          ; contador de tortugas en Stack
      push BitImageTransparente         ; parametro de PutImageVirtual
      mov  eax, [ EBP+LocalB ]          ; son seis parametros
      push eax                          ; LocalB la columna se incrementa
      add  eax, LargoYBasicoFicha       ; cada vez que se imprime una tortuga
      mov  [ EBP+LocalB ], eax          ; y se actualiza
      mov  eax, [ EBP+ParametroA ]      ; FilaFE es fijo, lo mismo
      RL( FilaFE )                      ; con OFFSET BufferParametroA
      push eax                          ; PunteroCentral ( pantalla pivote )
      push OFFSET BufferParametroA      ; y PunteroDatoFE que tiene
      push PunteroCentral               ; la imagen de 4 casillas
      mov  eax, [ EBP+ParametroA ]      ; luego de colocar los
      RL( PunteroDatoFE )               ; seis parametros
      push eax                          ; es Stack se llama al PROC
      call PutImageVirtual              ; PutImageVirtual que coloca imagen
      pop  eax                          ; hay que reactualizar el contador
      dec  eax                          ; tipo decreciente hasta
      cmp  eax, 0                       ; llegar a 0 en ese caso
      jne  RepetirAdyacente048          ; sale sino reinicia ciclo
IgnorarImprimir048:
      mov  eax, [ EBP+ParametroB ]      ; parametros de ProcesarFichaCiclica
      push eax                          ; los mismos de Self este PROC
      mov  eax, [ EBP+ParametroA ]      ; se encarga de mover la ficha
      push eax                          ; ademas devuelve eax=TRUE si
      call ProcesarFichaCiclica         ; es reinicio de ciclo
      mov  [ EBP+LocalC ], eax          ; guarda bandera en LocalC
      mov  eax, [ EBP+LocalA ]          ; ahora se inicio cambio de banderas
      and  eax, SumergiblePAQ           ; de tortuga, tiene dos contadores
      cmp  eax, 0                       ; un contador de inmersion que se
      je   IgnorarActivo048             ; desactiva desactivando SumergiblePAQ
      mov  eax, [ EBP+ParametroA ]      ; ContadorActivoME es un conteo
      RL( ContadorActivoME )            ; regresivo hasta 0 entonces
      cmp  eax, 0                       ; genera el proceso de sumergirse
      je   IgnorarActivo048             ; activando SumergibleActivoPAQ
      dec  eax                          ; luego el ContadorActivoME se divide
      cmp  eax, 0                       ; entre 2 para dos etapas de
      jne  NuevoActivo048               ; dibujo sumergido con
      mov  eax, [ EBP+LocalA ]          ; EstadoAPAQ, y finalmente desaparece
      and  eax, SoportePAQ              ; de pantalla anulando SoportePAQ
      cmp  eax, 0                       ; tambien con el contador a la mitad
      je   SoportePAQ048                ; luego reinicia el ciclo
      mov  eax, [ EBP+LocalA ]          ; el orden de activacion de banderas
      and  eax, SumergibleActivoPAQ     ; I=Activo A = Activo
      cmp  eax, 0                       ;                     1 2 3 4
      je   ActivarSoporte048            ; SoportePAQ          A A A I ...
      mov  eax, [ EBP+LocalA ]          ; SumergibleActivoPAQ I A A A ...
      and  eax, EstadoAPAQ              ; EstadoAPAQ          I I A I ...
      cmp  eax, 0                       ; y se repiten 1 2 3 4 varias veces
      je   ActivarAPAQ048               ; 2, 3, 4 usan la mitad del contador
      mov  eax, [ EBP+LocalA ]          ; las banderas actualizadas
      and  eax, ConjuntoTotal XOR ( SoportePAQ+EstadoAPAQ )
                                        ; se guardan cada vez en LocalA
      mov  [ EBP+LocalA ], eax          ; se utiliza una especie
      jmp  FinPosibles048               ; de CASE conjunto para esto
ActivarAPAQ048:
      mov  eax, [ EBP+LocalA ]          ; estamos en la etapa 3 segun
      or   eax, EstadoAPAQ              ; esquema, simplemente
      mov  [ EBP+LocalA ], eax          ; se activa EstadoAPAQ
      jmp  FinPosibles048               ; y se pasa al fin del CASE conjunto
SoportePAQ048:
      mov  eax, [ EBP+LocalA ]          ; reinicio con activacion de
      or   eax, SoportePAQ              ; SoportePAQ con or
      and  eax, ConjuntoTotal xor ( SumergibleActivoPAQ+EstadoAPAQ )
                                        ; y desactivacion con and NOT()
      mov  [ EBP+LocalA ], eax          ; resultado en LocalA
      jmp  FinPosibles048               ; y luego el fin del CASE conjunto
ActivarSoporte048:
      mov  eax, [ EBP+LocalA ]          ; estamos iniciando etapa2
      or   eax, SumergibleActivoPAQ     ; activando SumergibleActivoPAQ
      and  eax, ConjuntoTotal xor EstadoAPAQ
                                        ; nos aseguramos de desactivar
      mov  [ EBP+LocalA ], eax          ; EstadoAPAQ, recordar otro contador
FinPosibles048:
      mov  eax, [ EBP+ParametroA ]      ; se requiere reiniciar el
      RL( ReferenciaME )                ; contador leyendo de ReferenciaME
      RL( ContadorActivoRM )            ; ademas si la bandera
      mov  ebx, [ EBP+LocalA ]          ; SumergibleActivoPAQ esta activa
      and  ebx, SumergibleActivoPAQ     ; el contador se divide entre 2
      cmp  ebx, 0                       ; con el shr
      je   NuevoActivo048               ; o se deja igual si inactiva
      shr  eax, 1                       ; shr sirve para divisiones rapidas
NuevoActivo048:
      mov  ecx, eax                     ; se carga ContadorActivoME
      mov  eax, [ EBP+ParametroA ]      ; note que podria ser reiniciado
      RG( ContadorActivoME, ecx )       ; o simplemente decremente en 1
      mov  eax, [ EBP+LocalA ]          ; en el estado SumergibleActivoPAQ
      and  eax, SumergibleActivoPAQ     ; se ignora el primer contador
      cmp  eax, 0                       ; que se usa para mover las patitas
      jne  IgnorarContadorA048          ; caso de ignorar
IgnorarActivo048:
      mov  eax, [ EBP+ParametroA ]      ; se puede desactivar el moviento
      RL( ContadorME )                  ; de patas si ContadorME llega a 0
      cmp  eax, 0                       ; puede tomarse como un atrapa
      je   IgnorarContadorA048          ; errores, caso contrario
      dec  eax                          ; se decrementa en 1
      cmp  eax, 0                       ; hasta 0, cuando llega a 0
      jne  IgnorarActualizarContadorA048
                                        ; se requiere cambiar la
      mov  eax, [ EBP+LocalA ]          ; bandera EstadoAPAQ
      xor  eax, EstadoAPAQ              ; se invierte su estado con xor
      mov  [ EBP+LocalA ], eax          ; y se guarda en LocalA
      mov  eax, [ EBP+ParametroA ]      ; ademas hay que buscar en
      RL( ReferenciaME )                ; ReferenciaME.ContadorInternoRM
      RL( ContadorInternoRM )           ; para reiniciar contador
IgnorarActualizarContadorA048:
      mov  ebx, eax                     ; ebx el valor actual del contador
      mov  eax, [ EBP+ParametroA ]      ; y se guarda en
      RG( ContadorME, ebx )             ; ParametroA.ContadorME
IgnorarContadorA048:
      mov  eax, [ EBP+LocalC ]          ; LocalC si TRUE indica
      cmp  eax, TRUE                    ; reinicio de ciclo
      jne  IgnorarSuerte048             ; caso contrario se ignora reinicio
      mov  eax, [ EBP+LocalA ]          ; el reinicio se indica a otros
      or   eax, ReinicioMarinoPAQ       ; PROC con ReinicioMarinoPAQ
      mov  [ EBP+LocalA ], eax          ; en LocalA, luego se hace una
      mov  eax, [ EBP+ParametroA ]      ; rifa con ParametroARM
      RL( ReferenciaME )                ; el valor 0 desactiva la rifa
      RL( ProbabilidadARM )             ; en otras palabras se respeta
      cmp  eax, 0                       ; el estado inicial de SumergiblePAQ
      je   IgnorarSuerte048             ; de reinicio de nivel
      push 1                            ; RandomBoolean asigna
      push eax                          ; probabilidad 1/ProbabilidadARM
      call RandomBoolean                ; de que la nueva tortuga sea
      mov  ecx, [ EBP+LocalA ]          ; tipo SumergiblePAQ sino no se
      or   ecx, SumergiblePAQ           ; sumerge el resultado Random
      cmp  eax, TRUE                    ; se aprecia como boolean en eax
      je   IgnorarFALSESumergible048    ; por defecto SumergiblePAQ
      and  ecx, ConjuntoTotal xor ( SumergiblePAQ+SumergibleActivoPAQ )
                                        ; caso contrario no es SumergiblePAQ
IgnorarFALSESumergible048:
      mov  [ EBP+LocalA ], ecx          ; hay que reactualizar LocalA
IgnorarSuerte048:
      mov  eax, [ EBP+ParametroA ]      ; y por supuesto LocalA
      mov  ebx, [ EBP+LocalA ]          ; se asigna finalmente a
      RG( DescriptorME, ebx )           ; ParametroA.DescriptorME

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  DosParametros                ; retorno liberacion de parametros
ENDP ProcesarTortuga

.CODE
PROC ProcesarCocodrilo                  ; numero identificacion 049
.CODE
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, CeroLocales             ; espacio para locales
                                        ; ParametroA   : es el puntero a
                                        ;        ficha enlazada
                                        ; ParametroB   : es el Tiempo actual

      mov  eax, [ EBP+ParametroB ]      ; mueve ParametroB a stack
      push eax                          ; mueve ParametroA a stack
      mov  eax, [ EBP+ParametroA ]      ; luego llama a ProcesarMosca
      push eax                          ; si devuelve FALSE en eax
      call ProcesarMosca                ; no hace nada
      cmp  eax, FALSE                   ; si devuleve TRUE continuar
      je   Salida049                    ; porque se trata de un cocodrilo
      mov  eax, [ EBP+ParametroA ]      ; se requiere la asignacion
      RL( ColumnaME )                   ; FinalBloquedo[ ColumnaME ]=TRUE
      mov  ebx, eax                     ; via AP que cuenta a partir de 1
      mov  eax, OFFSET FinalBloqueado   ; en eax direccion de ARRAY
      AP( ebx )                         ; se carga ebx con valor TRUE
      mov  ebx, TRUE                    ; con ebx como pivote
      mov  [ EAX ], ebx                 ; y direccion en eax
      mov  eax, TRUE                    ; indica nueva asignacion
Salida049:

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  DosParametros                ; retorno liberacion de parametros
ENDP ProcesarCocodrilo

.CODE
PROC ProcesarMosca                      ; numero identificacion 050
.CODE
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, DosLocales              ; espacio para locales
                                        ; ParametroA   : es el puntero a
                                        ;        ficha enlazada
                                        ; ParametroB   : es el Tiempo actual
                                        ; OUT eax      : indica nueva
                                        ;        asignacion de mosca
                                        ; VariablesLocales
                                        ; LocalA       : Nueva columna fin
                                        ; LocalB       : bandera nuevo

      mov  eax, FALSE                   ; FALSE que indica que no es nueva
      mov  [ EBP+LocalB ], eax          ; mosca si no una ya existente
      mov  eax, [ EBP+ParametroA ]      ; ParametroA.ContadorME funciona
      RL( ContadorME )                  ; con cuenta regresiva
      cmp  eax, 0                       ; si es 0 se pasa a
      je   CasoZero049                  ; etiqueta CasoZero049
      dec  eax                          ; caso contrario decrece contador
      cmp  eax, 0                       ; si todavia no llega a cero
      jne  IgnorarApagado049            ; salta a guardar el contador
      mov  eax, [ EBP+ParametroA ]      ; en caso de decrecer hasta anularse
      RL( ColumnaME )                   ; primero debe colocar en FALSE
      mov  ebx, eax                     ; las banderas respectivas
      push eax                          ; en FinalOcupado[ ColumnaME ] y
      mov  eax, OFFSET FinalOcupado     ; en FinalBloqueado[ ColumnaME ]
      AP( ebx )                         ; la macro AP direcciona la casilla
      mov  ebx, FALSE                   ; en cada ARRAY respectivo
      mov  [ EAX ], ebx                 ; utilizamos OFFSET pues se pasan
      pop  ebx                          ; direcciones a AP
      mov  eax, OFFSET FinalBloqueado   ; la direccion calculada asi en eax
      AP( ebx )                         ; y en ebx el valor FALSE deseado
      mov  ebx, FALSE                   ; que se guarda en cada caso
      mov  [ EAX ], ebx                 ; push pop para "recordar" ColumnaME
      mov  eax, 0                       ; eax = 0 indica fin del conteo
IgnorarApagado049:
      mov  ebx, eax                     ; en ebx valor de contador actual
      mov  eax, [ EBP+ParametroA ]      ; que se guarda en
      RG( ContadorME, ebx )             ; ParametroA.ContadorME
      push BitImageTransparente         ; ahora el PutImageVirtual
      mov  eax, [ EBP+ParametroA ]      ; respectivo, ColumnaME
      RL( ColumnaME )                   ; se guarda como un indice
      mov  ebx, eax                     ; para apuntar en
      mov  eax, OFFSET ColumnaFinal     ; ColumnaFinal[ ColumnaME ]
      AP( ebx )                         ; el indice se guarda en base 1
      mov  eax, [ EAX ]                 ; el valor se obtiene centrado
      sub  eax, LargoYCocodrilo         ; se resta LargoYCocodrilo
      push eax                          ; para afinar ubicacion
      mov  eax, [ EBP+ParametroA ]      ; el valor de FilaME se coloca
      RL( FilaME )                      ; sin cambios
      push eax                          ; NIL para indicar ficha completa
      push NIL                          ; como siempre la transferencia
      push PunteroCentral               ; desde PunteroDatoME hasta
      mov  eax, [ EBP+ParametroA ]      ; PunteroCentral
      RL( PunteroDatoME )               ; utilizando eax como pivote
      push eax                          ; luego la llamada al
      call PutImageVirtual              ; PROC PutImageVirtual
      jmp  Salida049                    ; y salto al final
CasoZero049:
      mov  eax, [ EBP+ParametroA ]      ; se utiliza ParametroA...
      RL( ReferenciaME )                ;    .ReferenciaME.ProbabilidadARM
      RL( ProbabilidadARM )             ; si es 0 se ignora
      cmp  eax, 0                       ; si no lo es se intenta
      je   Salida049                    ; RandomBoolean con
      push 1                            ; probabilidad (1/ProbabilidadARM)
      push eax                          ; de ubicar una nueva mosca
      call RandomBoolean                ; el resultado se lee en eax
      cmp  eax, FALSE                   ; como un boolean
      je   Salida049                    ; si es FALSE fin
      push IntentosMoscaFijo            ; contador de intentos para mosca
RepiteIntento049:
      pop  eax                          ; el contador permite
      dec  eax                          ; repetir la busqueda de una
      cmp  eax, 0                       ; eleccion de final varias veces
      je   Salida049                    ; con posible fracaso
      push eax                          ; reestablece el stack contador
      mov  eax, 5                       ; por repetidos intentos
      call GetRandom                    ; elegimos via GetRandom
      inc  eax                          ; una de las cinco casillas finales
      mov  [ EBP+LocalA ], eax          ; se repite el intento
      mov  eax, [ EBP+ParametroA ]      ; hasta obtener casilla vacia
      RL( ReferenciaME )                ; se obtiene ParametroA.
      RL( ContadorInternoRM )           ;    ..ReferenciaME.ContadorRM
      cmp  eax, 0                       ; si es 0 se ignora
      je   Salida049                    ; y salta a la Salida049
      mov  ebx, [ EBP+LocalA ]          ; ahora el ubicador de columna
      mov  eax, OFFSET FinalOcupado     ; en ARRAY FinalOcupado
      AP( ebx )                         ; luego apunta el ARRAY
      mov  eax, [ EAX ]                 ; carga la bandera
      cmp  eax, TRUE                    ; y compara con TRUE
      je   RepiteIntento049             ; si es TRUE salta
      pop  eax                          ; libera el stack del contador
      mov  eax, [ EBP+ParametroA ]      ; ahora carga ParametroA.
      RL( ReferenciaME )                ;   ..ReferenciaME.ContadorInternoME
      RL( ContadorInternoRM )           ; y lo mueve a ebx
      mov  ebx, eax                     ; y lo guarda en
      mov  eax, [ EBP+ParametroA ]      ; ParametroA.ContadorME
      RG( ContadorME, ebx )             ; lee el OFFSET de FinalOcupado
      mov  eax, OFFSET FinalOcupado     ; y apunta con AP a la columna
      mov  ebx, [ EBP+LocalA ]          ; para poner un TRUE
      AP( ebx )                         ; es decir
      mov  ebx, TRUE                    ; FinalOcupado[ LocalA ] = TRUE
      mov  [ EAX ], ebx                 ; en forma similar se asigna
      mov  eax, OFFSET FinalBloqueado   ; FinalBloqueado[ LocalA ] = FALSE
      mov  ebx, [ EBP+LocalA ]          ; porque la mosca no bloquea el acceso
      AP( ebx )                         ; se utiliza ebx como pivote
      mov  ebx, FALSE                   ; para el valor de bandera
      mov  [ EAX ], ebx                 ; y se guarda via este mov
      mov  eax, [ EBP+ParametroA ]      ; luego se asigna
      mov  ebx, [ EBP+LocalA ]          ; ParametroA.ColumnaME = LocalA
      RG( ColumnaME, ebx )              ; y se carga LocalB = TRUE
      mov  eax, TRUE                    ; para indicar que hubo
      mov  [ EBP+LocalB ], eax          ; nueva asignacion
Salida049:
      mov  eax, [ EBP+LocalB ]          ; LocalB indica nueva mosca

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  DosParametros                ; retorno liberacion de parametros
ENDP ProcesarMosca

.CODE
PROC ProcesarAnfibio                    ; numero identificacion 051
.CODE
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, UnLocal                 ; espacio para locales
                                        ; ParametroA   : es el puntero a
                                        ;        ficha enlazada
                                        ; ParametroB   : es el Tiempo actual
                                        ; OUT EAX      : TRUE es fin de juego
                                        ; Variables locales
                                        ; LocalA       : es DescriptorME

      mov  eax, [ EBP+ParametroA ]      ; primero se carga el
      RL( DescriptorME )                ; LocalA = ParametroA.DescriptorME
      mov  [ EBP+LocalA ], eax          ; usando eax como pivote
      mov  edx, eax                     ; se coloca en edx tambien
      and  eax, DerechaPAQ              ; CASE DerechaPAQ
      cmp  eax, DerechaPAQ              ; puede revisarse con and-cmp
      jne  IgnorarDerecha051            ; si no siguiente
      mov  ecx, 1                       ; la primera rana es derecha
      jmp  FinCASEA051                  ; luego hacia el fin de CASE
IgnorarDerecha051:
      mov  eax, edx                     ; recupera DescriptorME
      and  eax, IzquierdaPAQ            ; CASE IzquierdaPAQ
      cmp  eax, IzquierdaPAQ            ; puede revisarse con and-cmp
      jne  IgnorarIzquierda051          ; si no siguiente
      mov  ecx, 4                       ; siguiente rana es izquierda
      jmp  FinCASEA051                  ; luego hacia el fin de CASE
IgnorarIzquierda051:
      mov  eax, edx                     ; recupera DescriptorME
      and  eax, ArribaPAQ               ; CASE ArribaPAQ
      cmp  eax, ArribaPAQ               ; puede revisarse con and-cmp
      jne  IgnorarArriba051             ; si no siguiente
      mov  ecx, 7                       ; siguiente rana es arriba
      jmp  FinCASEA051                  ; luego hacia el fin de CASE
IgnorarArriba051:
      mov  eax, edx                     ; recupera DescriptorME
      and  eax, AbajoPAQ                ; CASE AbajoPAQ
      cmp  eax, AbajoPAQ                ; puede revisarse con and-cmp
      jne  Difunto051                   ; si no siguiente
      mov  ecx, 10                      ; ahora la rana es abajo
      jmp  FinCASEA051                  ; luego hacia el fin de CASE
Difunto051:
      mov  ecx, 13                      ; si ninguna anterio
      jmp  FinCASEB051                  ; entonces caso difunto
FinCASEA051:
      mov  eax, edx                     ; recupera DescriptorME
      and  eax, EstadoAPAQ+EstadoBPAQ   ; si ambas
      cmp  eax, 0                       ; EstadoAPAQ+EstadoBPAQ apagada
      je   FinCASEB051                  ; entonces salta la correccion B
      mov  eax, edx                     ; si EstadoAPAQ activa
      and  eax, EstadoAPAQ              ; indica movimiento de rana
      cmp  eax, EstadoAPAQ              ; con inc ecx
      jne  IgnorarEstadoAPAQ051         ; ecx indica numero de dibujo
      inc  ecx                          ; en una secuencia de casilla
      jmp  FinCASEB051                  ; hacia el fin del CASE
IgnorarEstadoAPAQ051:
      add  ecx, 2                       ; si EstadoBPA se a¤ade 2 casillas
FinCASEB051:
      push ecx                          ; GenerarCuadriculaBuffer devuelve
      call GenerarCuadriculaBufferA     ; en OFFSET BufferParametroA
      push BitImageTransparente         ; una casilla tipica de juego
      mov  eax, [ EBP+ParametroA ]      ; para ubicar una ficha en una matriz
      RL( ColumnaFE )                   ; seis parametros para PutImageVirtual
      sar  eax, BitsExtraCiclico        ; ColumnaFE se describe con exceso
      push eax                          ; de bits para facilitar cambio de
      mov  eax, [ EBP+ParametroA ]      ; velocidad por ello el sar
      RL( FilaFE )                      ; FilaFE si se coloca sin cambio
      push eax                          ; luego la cuadricula respectiva
      push OFFSET BufferParametroA      ; que es tipo RectanguloLongInt
      push PunteroCentral               ; luego el PunteroCentral que es
      mov  eax, [ EBP+ParametroA ]      ; un pivote de la pantalla
      RL( PunteroDatoFE )               ; y finalmente el MatrizARRAY
      push eax                          ; para extraer la imagen de la ficha
      call PutImageVirtual              ; pone la imagen en PunteroCentral
      mov  eax, [ EBP+LocalA ]          ; ColumnaFE se corrige, puede
      and  eax, SolidarioPAQ            ; tener movimiento solidario como
      cmp  eax, SolidarioPAQ            ; cuando la rana esta en un tronco
      jne  IgnorarSolidario051          ; SolidarioPAQ activo y
      mov  eax, [ EBP+ParametroA ]      ; FichaVinculado <> 0 entonces
      RL( FichaVinculadoME )            ; se busca en PunteroPaquete
      cmp  eax, 0                       ; la ficha respectiva
      je   IgnorarSolidario051          ; y se consulta su velocidad
      push eax                          ; en ReferenciaFE del tipo
      push PunteroPaquete               ; FichaEnlazada respectivo
      call BuscarIdentificadorCE        ; la velocidad se suma
      cmp  eax, nil                     ; simplemente en ColumnaME
      je   IgnorarSolidario051          ; y se guarda de nuevo
      RL( ReferenciaFE )                ; esta rutina no revisa
      RL( VelocidadRM )                 ; consistencias para ello
      mov  edx, eax                     ; se utiliza luego un proceso externo
      mov  eax, [ EBP+ParametroA ]      ; aqui estamos cargando
      RL( ColumnaME )                   ; ColumnaME, en edx teniamos velocidad
      add  eax, edx                     ; ambas con exceso de bits
      mov  edx, eax                     ; se devuelve el resultado a edx
      mov  eax, [ EBP+ParametroA ]      ; para utilizar RG para guardar
      RG( ColumnaME, edx )              ; el valor actualizado en ColumnaME
IgnorarSolidario051:
      mov  eax, [ EBP+ParametroA ]      ; el ContadorME activo permite
      RL( ContadorME )                  ; dejar una ficha fija en pantalla
      cmp  eax, 0                       ; excepto desplazamiento solidario
      jne  DecrecerContadorME051        ; si no es 0 se asume esta
      mov  eax, [ EBP+LocalA ]          ; condicion hasta llegar a 0
      and  eax, DerrotadoPAQ            ; al llegar a 0 se revisa la condicion
      cmp  eax, DerrotadoPAQ            ; DerrotadoPAQ que si es falsa
      je   IgnorarDerrotado051          ; se ignora el bloque hasta el label
      mov  eax, [ EBP+ParametroB ]      ; si es cierta se llama al PROC
      push eax                          ; SapoDerrotado para que haga
      mov  eax, [ EBP+ParametroA ]      ; las revisiones necesarios
      push eax                          ; con bandera de salida en eax
      call SapoDerrotado                ; en cuyo caso simplemente
      cmp  eax, TRUE                    ; termina este PROC pasando tambien
      je   FinEAX051                    ; la bandera como respuesta en eax
IgnorarDerrotado051:
      mov  eax, [ EBP+LocalA ]          ; ahora revisamos la bandera SaltoPAQ
      and  eax, SaltoPAQ                ; durante un salto no se cambian
      cmp  eax, SaltoPAQ                ; condiciones excepto
      je   Saltar051                    ; cambio de imagen en la secuencia
      mov  eax, [ EBP+ParametroB ]      ; ahora se procede a revisar
      push eax                          ; la condicion del sapor mediante
      mov  eax, [ EBP+ParametroA ]      ; el PROC SapoCondicion
      push eax                          ; su objetivo es detectar choques
      call SapoCondicion                ; y cosas asi indicando con banderas
      cmp  eax, TRUE                    ; revisa si el sapo fue derrotado
      mov  eax, FALSE                   ; si fue derrotado eax devuelve
      je   FinEAX051                    ; FALSE, se asume que hay que ignorar
      cmp  BanderaTeclaEspecial, TRUE   ; LocalA, ahora se revisan teclas
      jne  Salida051                    ; solo teclas especiales de flecha
      cmp  TeclaOpcion, CodigoFlechaArriba
                                        ; caso CodigoFlechaArriba
      jne  IgnorarArribaC051            ; si no salta
      mov  eax, ArribaPAQ               ; si positivo coloca ArribaPAQ en eax
      jmp  FinCASEC051                  ; y luego fin del CASE
IgnorarArribaC051:
      cmp  TeclaOpcion, CodigoFlechaAbajo
                                        ; caso CodigoFlechaAbajo
      jne  IgnorarAbajoC051             ; si no salta
      mov  eax, AbajoPAQ                ; si positivo coloca AbajoPAQ en eax
      jmp  FinCASEC051                  ; y luego fin del CASE
IgnorarAbajoC051:
      cmp  TeclaOpcion, CodigoFlechaIzquierda
                                        ; caso CodigoFlechaIzquierda
      jne  IgnorarIzquierdaC051         ; si no salta
      mov  eax, IzquierdaPAQ            ; si positivo coloca IzquierdaPAQ en
      jmp  FinCASEC051                  ; eax y luego fin del CASE
IgnorarIzquierdaC051:
      cmp  TeclaOpcion, CodigoFlechaDerecha
                                        ; caso CodigoFlechaDerecha
      jne  IgnorarDerechaC051           ; si no salta
      mov  eax, DerechaPAQ              ; si positivo coloca DerechaPAQ en
      jmp  FinCASEC051                  ; eax y luego fin del CASE
IgnorarDerechaC051:
      jmp  Salida051                    ; si ninguna simplemente sale
FinCASEC051:
      mov  edx, eax                     ; coloca en edx la direccion PAQ
      mov  eax, [ EBP+LocalA ]          ; carga DescriptorME
      and  eax, ConjuntoTotal xor ( ArribaPAQ+AbajoPAQ+DerechaPAQ+IzquierdaPAQ+EstadoAPAQ+EstadoBPAQ )
                                        ; y le borra banderas de salto
      mov  ebx, edx                     ; ademas se requiere borrar
      and  ebx, ArribaPAQ+AbajoPAQ      ; la bandera SolidarioPAQ
      cmp  ebx, 0                       ; en el caso de salto vertical
      je   IgnorarSolidarioPAQ051       ; si no, entonces no hay que hacerlo
      and  eax, ConjuntoTotal xor SolidarioPAQ
                                        ; esto borra la bandera SolidarioPAQ
IgnorarSolidarioPAQ051:
      or   eax, edx                     ; se agrega la nueva direccion PAQ
      or   eax, SaltoPAQ                ; se agrega tambien SaltoPAQ
      mov  [ EBP+LocalA ], eax          ; guarda en LocalA
Saltar051:
      mov  edx, [ EBP+LocalA ]          ; para el desplazamiento
      mov  ecx, FALSE                   ; se utiliza un valor distinto
      mov  eax, edx                     ; fila y columna, la bandera
      and  eax, EstadoBPAQ              ; EstadoBPAQ indica una correccion
      cmp  eax, EstadoBPAQ              ; como una bandera colocada en ecx
      jne  IgnorarCorreccionD051        ; dos saltos identicos y uno difiere
      mov  ecx, TRUE                    ; si difiere ecx TRUE
IgnorarCorreccionD051:
      mov  eax, edx                     ; se revisa direccion con edx como
      and  eax, ArribaPAQ               ; reserva de DescriptorME actual
      cmp  eax, ArribaPAQ               ; si ArribaPAQ
      jne  IgnorarArribaD051            ; si no se salta
      mov  eax, [ EBP+ParametroA ]      ; si es ArribaPAQ se suma
      RL( FilaFE )                      ; FilaFE=FilaFE-SaltoSapoFila
      sub  eax, SaltoSapoFila           ; ecx indica la correccion adicional
      cmp  ecx, TRUE                    ; con -SaltoCorregidoFila
      jne  FinCASED051                  ; caso EstadoBPAQ activo
      sub  eax, SaltoCorregidoFila      ; el salto tiene tres etapas
      jmp  FinCASED051                  ; se hace calzar con el tamano casilla
IgnorarArribaD051:
      mov  eax, edx                     ; nuevamente DescriptorME
      and  eax, AbajoPAQ                ; se consulta AbajoPAQ
      cmp  eax, AbajoPAQ                ; si no lo es se ignora
      jne  IgnorarAbajoD051             ; y se salta al siguiente label
      mov  eax, [ EBP+ParametroA ]      ; caso positivo se calcula
      RL( FilaFE )                      ; FilaFE=FilaFE+SaltoSapoFila
      add  eax, SaltoSapoFila           ; ecx TRUE indica correccion
      cmp  ecx, TRUE                    ; adicional con +SaltoCorregidoFila
      jne  FinCASED051                  ; de esa manera las tres etapas
      add  eax, SaltoCorregidoFila      ; de salto calzan con
      jmp  FinCASED051                  ; el tamano de casilla
IgnorarAbajoD051:
      mov  eax, edx                     ; nuevamente DescriptorME
      and  eax, DerechaPAQ              ; se compara con DerechaPAQ
      cmp  eax, DerechaPAQ              ; si inactiva se salta
      jne  IgnorarDerechaD051           ; hacia el siguiente label
      mov  eax, [ EBP+ParametroA ]      ; si activa se calcula
      RL( ColumnaFE )                   ; ColumnaFE=ColumnaFE+SaltoSapoColumna
      add  eax, SaltoSapoColumna        ; caso ecx=TRUE correccion
      cmp  ecx, TRUE                    ; adicional +SaltoCorregidoColumna
      jne  FinCASEColumnaD051           ; si no lo es fin del case
      add  eax, SaltoCorregidoColumna   ; si lo es suma la correccion
      jmp  FinCASEColumnaD051           ; y de todas formas fin del case
IgnorarDerechaD051:
      mov  eax, edx                     ; nuevamente DescriptorME
      and  eax, IzquierdaPAQ            ; ahora se revisa caso
      cmp  eax, IzquierdaPAQ            ; IzquierdaPAQ con and-cmp
      jne  IgnorarIzquierdaD051         ; si no lo es salta a label
      mov  eax, [ EBP+ParametroA ]      ; caso positivo se calcula
      RL( ColumnaFE )                   ; ColumnaFE=ColumnaFE-SaltoSapoColumna
      sub  eax, SaltoSapoColumna        ; se consulta caso ecx=TRUE
      cmp  ecx, TRUE                    ; y calcula -SaltoCorregidoColumna
      jne  FinCASEColumnaD051           ; se revisa la condicion ecx
      sub  eax, SaltoCorregidoColumna   ; caso positivo
      jmp  FinCASEColumnaD051           ; de cualquier forma fin del CASE
IgnorarIzquierdaD051:
      jmp  Salida051                    ; si ninguna Salida051 (¨error?)
FinCASED051:
      mov  ebx, eax                     ; se pasa a ebx
      mov  eax, [ EBP+ParametroA ]      ; y se guarda en
      RG( FilaFE, ebx )                 ; ParametroA.FilaFE
      jmp  IgnorarFinColumnaD051        ; si es fila
FinCASEColumnaD051:
      mov  ebx, eax                     ; y si es columna
      mov  eax, [ EBP+ParametroA ]      ; se reactualiza
      RG( ColumnaFE, ebx )              ; ParametroA.ColumnaFE
IgnorarFinColumnaD051:
      mov  eax, [ EBP+LocalA ]          ; nuevamente el DescriptorME
      and  eax, EstadoAPAQ+EstadoBPAQ   ; si ambas banderas
      cmp  eax, 0                       ; EstadoAPAQ+EstadoBPAQ apagadas
      jne  SegundaActivacionE051        ; simultaneamente sigue si no salta
      mov  eax, [ EBP+LocalA ]          ; caso positivo
      or   eax, EstadoAPAQ              ; agregar EstadoAPAQ
      mov  [ EBP+LocalA ], eax          ; a DescriptorME
      jmp  FinCASEE051                  ; y luego fin del CASE
SegundaActivacionE051:
      mov  eax, [ EBP+LocalA ]          ; note que el CASE lo que hace
      and  eax, EstadoAPAQ              ; es pasar del estado
      cmp  eax, EstadoAPAQ              ; -- a +- a -+ a --
      jne  TerceraActivacionE051        ; para las banderas EstadoAPAQ
      mov  eax, [ EBP+LocalA ]          ; y EstadoBPAQ con - Inactivo
      and  eax, ConjuntoTotal xor EstadoAPAQ
                                        ; y + Activo
      or   eax, EstadoBPAQ              ; es pues un CASE de tres estados
      mov  [ EBP+LocalA ], eax          ; carga valor de LocalA
      jmp  FinCASEE051                  ; y luego fin del CASE
TerceraActivacionE051:
      mov  eax, [  EBP+LocalA ]         ; el caso de -+ a --
      and  eax, ConjuntoTotal xor ( EstadoAPAQ+EstadoBPAQ+SaltoPAQ )
                                        ; desactiva SaltoPAQ por salto
      mov  [ EBP+LocalA ], eax          ; completo, aprecial que LocalA
      jmp  IgnorarActivacionE051        ; guarda el resultado
FinCASEE051:
      mov  eax, [ EBP+ParametroA ]      ; durante el salto excepto al final
      RL( ReferenciaME )                ; se activa un contador tal vez 0
      RL( ContadorInternoRM )           ; colocandolo en ContadorME
      mov  ebx, eax                     ; esto actua como variable
      mov  eax, [ EBP+ParametroA ]      ; de animacion
      RG( ContadorME, ebx )             ; se guarda con macro RG
IgnorarActivacionE051:
      jmp  Salida051                    ; al arranque no es necesario dec
DecrecerContadorME051:
      dec  eax                          ; se decrece el contador en eax
      mov  ecx, eax                     ; y su valor actualizado
      mov  eax, [ EBP+ParametroA ]      ; se guarda en
      RG( ContadorME, ecx )             ; ParametroA.ContadorME
Salida051:
      mov  eax, [ EBP+ParametroA ]      ; con frecuencia sera necesario
      mov  ebx, [ EBP+LocalA ]          ; guardar un valor actualizado
      RG( DescriptorME, ebx )           ; de DescriptorME desde LocalA
      mov  eax, FALSE                   ; TRUE en eax es fin de juego
FinEAX051:

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  DosParametros                ; retorno liberacion de parametros
ENDP ProcesarAnfibio

.CODE
PROC SapoDerrotado                      ; numero identificacion 052
.CODE
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, CeroLocales             ; espacio para locales
                                        ; ParametroA   : es el puntero a
                                        ;        ficha enlazada
                                        ; ParametroB   : es el Tiempo actual

      mov  eax, TRUE

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  DosParametros                ; retorno liberacion de parametros
ENDP SapoDerrotado

.CODE
PROC SapoCondicion                      ; numero identificacion 053
.CODE
      push ebp                          ; guarda ebp antes de PROC
      mov  ebp, esp                     ; parametros a partir de [ EBP ]
      sub  esp, CuatroLocales           ; espacio para locales
                                        ; ParametroA   : es el puntero a
                                        ;        ficha enlazada
                                        ; ParametroB   : es el Tiempo actual
                                        ; OUT EAX      : TRUE es derrota
                                        ; Variables Locales
                                        ; LocalA       : ficha enlazada a
                                        ;        confrontar con sapo
                                        ; LocalB       : FilaME del sapo
                                        ; LocalC       : ColumnaME del sapo
                                        ; LocalD       : Bandera derrotado

      mov  eax, FALSE
      mov  [ EBP+LocalD ], eax
      mov  eax, [ EBP+ParametroA ]
      RL( FilaME )
      mov  [ EBP+LocalB ], eax
      mov  eax, [ EBP+ParametroA ]
      RL( ColumnaME )
      mov  [ EBP+LocalC ], eax
      mov  eax, PunteroPaquete
CicloFichas053:
      mov  [ EBP+LocalA ], eax
      RL( DescriptorME )
      mov  edx, eax
      and  eax, ActivoPAQ+VisiblePAQ
      cmp  eax, ActivoPAQ+VisiblePAQ
      jne  Siguiente053
      mov  eax, [ EBP+LocalA ]
      RL( FilaFE )
      mov  ebx, [ EBP+LocalB ]
      cmp  eax, ebx
      jne  Siguiente053
      mov  eax, edx
      and  eax, FichaPAQ+CiclicoPAQ
      cmp  eax, FichaPAQ+CiclicoPAQ
      jne  IgnorarFichaPAQ053
      mov  eax, [ EBP+LocalA ]
      RL( ColumnaME )
      mov  ebx, [ EBP+LocalC ]
      cmp  eax, ebx
      jle  CasoFichaIzquierda053
      sub  eax, ebx
      cmp  eax, BitsExtraCiclico*LargoYBasicoFicha
      jge  Siguiente053
      mov  eax, [ EBP+LocalA ]
      and  eax, ConjuntoTotal xor ( ArribaPAQ+AbajoPAQ+IzquierdaPAQ+DerechaPAQ )
      or   eax, DerrotadoPAQ
      mov  [ EBP+LocalA ], eax
      mov  eax, TRUE
      mov  [ EBP+LocalD ], eax
      jmp  SalidaLocal053
CasoFichaIzquierda053:
      jmp  FinCASE053
IgnorarFichaPAQ053:
      jmp  FinCASE053
FinCASE053:
Siguiente053:
      mov  eax, [ EBP+LocalA ]
      RL( SiguienteFE )
      cmp  eax, NIL
      jne  CicloFichas053
SalidaLocal053:
      mov  eax, [ EBP+ParametroA ]
      mov  ebx, [ EBP+LocalA ]
      RG( DescriptorME, ebx )
SalidaEAX053:
      mov  eax, [ EBP+LocalD ]

      mov  esp, ebp                     ; reestablece ESP
      pop  ebp                          ; recupera ebp antes de PROC
      ret  DosParametros                ; retorno liberacion de parametros
ENDP SapoCondicion

.CODE
START:
  mov  edi, OFFSET NombrePrograma       ; para escribir el NombrePrograma
  call systemWriteLn                    ; lo escribe en pantalla
  mov  edi, OFFSET CambioGrafico        ; ofrece modo grafico o texto
  call SystemWriteLn                    ; con un mensaje en pantalla
  call SystemGetKey                     ; espera respuesta de usuario
  mov  ActivaPantalla, FALSE            ; FALSE por defecto
  cmp  al, '1'                          ; TRUE si teclea '1'
  jne  IgnorarActivaPantalla            ; selector condicional
  mov  ActivaPantalla, TRUE             ; caso TRUE
IgnorarActivaPantalla:
  call InicializacionGeneral            ; inicializacion general Programa
  call PruebaGeneral                    ; proceso de prueba
  call FinalizacionGeneral              ; finalizacion general Programa
  mov  eax, ErrorArchivo                ; lee ErrorArchivo
  cmp  eax, FALSE                       ; si es FALSE
  je   SALIDA                           ; no hace nada
.PUBLIC ErrorGeneral:
  cmp  BanderaPantalla, TRUE            ; verificando la pantalla activa
  jne  IgnorarSetText                   ; si no esta activa ignorar
  call SetTextMode                      ; para desactivar el modo texto
  mov  BanderaPantalla, FALSE           ; coloca FALSE en BanderaPantalla
IgnorarSetText:
  mov  edi, OFFSET MensajeErrorGeneral  ; caso error general
  call SystemWriteLn                    ; escribe mensaje de error
.PUBLIC SALIDA:
.PUBLIC FIN:
  mov  edi, OFFSET FinPrograma          ; mensaje despedida
  call SystemWriteLn                    ; impreso en pantalla
  mov  ah,4ch                           ; orden de salida
  int  21h                              ; interrupcion de salida
END START
END
