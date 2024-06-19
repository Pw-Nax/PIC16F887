;Autores:
;CABERO, MAURO EZEQUIEL
;DE LOS SANTOS AUGUSTO FRANCISCO
;PANIAGUA ROMERO, RODRIGO ALEJANDRO
;
;ESTABLECIMIENTO: UNIVERSIDAD NACIONAL DE CÓRDOBA - FACULTAD DE CIENCIAS EXACTAS FISICAS Y NATURALES
;AÑO: 2024
;MATERIA: ELECTRÓNICA DIGITAL II
;SUPERVISIÓN ACADÉMICA: ING. DEL BARCO, MARTIN IGNACIO
;
;------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

INCLUDE <p16f887.inc>
  
 ; CONFIG1
; __config 0x3FE4
 __CONFIG _CONFIG1, _FOSC_INTRC_NOCLKOUT & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_ON & _IESO_ON & _FCMEN_ON & _LVP_ON
; CONFIG2
; __config 0x3FFF
 __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF
 
ORG 0x0

SETUP
;CONFIGURACION DE E/S
BANKSEL TRISC;
BCF TRISC,2
BSF TRISC,7 ;Set RA0 to input
CLRF TRISD
BANKSEL STATUS
CLRF PORTC
CLRF PORTD
 
; Configurar CCP1 para modo PWM
    BANKSEL CCP1CON    ; Seleccionar el banco de CCP1CON
    movlw   b'00001100' ; Configurar CCP1 para modo PWM
    movwf   CCP1CON     ; CCP1CON<5:4> = 11 (modo PWM)

    ; Configurar el prescaler del Timer2 para generar la frecuencia del PWM
    BANKSEL T2CON       ; Seleccionar el banco de T2CON
    movlw   b'00000111' ; Prescaler 1:16 para Timer2 (ajustar según necesidades)
    movwf   T2CON       ; Configurar Timer2

    ; Establecer el periodo del PWM (ajustar para una frecuencia de 1 kHz)
    BANKSEL PR2         ; Seleccionar el banco de PR2
    movlw   0x3F        ; Valor para el periodo (ajustar según la frecuencia deseada)
    movwf   PR2         ; Cargar en el registro de periodo

    ; Habilitar Timer2 y el módulo PWM
    BANKSEL T2CON       ; Seleccionar el banco de T2CON nuevamente por seguridad
    bsf     T2CON, TMR2ON   ; Habilitar Timer2
    BANKSEL CCP1CON     ; Seleccionar el banco de CCP1CON nuevamente
    bsf     CCP1CON, CCP1M0 ; Habilitar el módulo PWM

;Configuración del puerto UART
BANKSEL SPBRG   ; Calcular valor apropiado para la velocidad en baudios deseada
MOVLW .25
MOVWF SPBRG
BANKSEL TXSTA
BSF TXSTA,BRGH   ; Alta velocidad (podría no ser necesario para la velocidad en baudios elegida)
BANKSEL RCSTA
BSF RCSTA,SPEN   ; Activar puerto serie
BSF RCSTA,CREN
    
Recibir_dato:
BANKSEL PIR1
BTFSS PIR1,RCIF
GOTO Recibir_dato
BANKSEL RCREG
MOVF RCREG,W   
BANKSEL CCPR1L
MOVWF CCPR1L ;store in GPR space
MOVF CCPR1L,W
BANKSEL PORTD
MOVWF PORTD
GOTO Recibir_dato  
 
END
