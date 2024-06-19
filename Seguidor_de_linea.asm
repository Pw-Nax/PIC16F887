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
LIST P=16F887
    INCLUDE <p16f887.inc>

    __CONFIG _CONFIG1, _FOSC_INTRC_NOCLKOUT & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_ON & _IESO_ON & _FCMEN_ON & _LVP_OFF
    __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF

     ; Declaración de pines para el sensor QTR-8A
    #DEFINE LED_ON PORTA, RA0  ; Es una salida, debe estar en alto cuando inicia el programa.
    #DEFINE QTR1   PORTA, RA1  ; Entrada
    #DEFINE QTR2   PORTA, RA2  ; Entrada
    #DEFINE QTR3   PORTA, RA3  ; Entrada
    #DEFINE QTR4   PORTA, RA5  ; Entrada
    #DEFINE QTR5   PORTE, RE0  ; Entrada
    #DEFINE QTR6   PORTE, RE1  ; Entrada

    ; OUTPUTS para el driver TB6612FNG
    #DEFINE PWM_A    PORTC, 1  ; Salida
    #DEFINE PWM_B    PORTC, 2  ; Salida
    #DEFINE MOTOR_B1 PORTB, RB1  ; Salida  IZQUIERDO
    #DEFINE MOTOR_B2 PORTB, RB2  ; Salida  IZQUIERDO
    #DEFINE MOTOR_A1 PORTB, RB3  ; Salida  DERECHO
    #DEFINE MOTOR_A2 PORTB, RB4  ; Salida  DERECHO

;    Periféricos (outputs)
    #DEFINE PUSH   PORTB, RB0  ; Botón de GO
    #DEFINE BUZZER PORTE, RE2  ; Zumbador
    
    CBLOCK  0x70
	R_ContA				; Contadores para los retardos.
	R_ContB
	R_ContC
	w_temp                          ; para salvar el contexto
	status_temp
	CONT
        RESULTHI                        ; resultado alto del ADC
        RESULTLO                        ; resultado bajo del ADC
        SENSOR
	ENDC
     
    ORG 0x00
    GOTO MAIN

    ORG 0X04
    GOTO INTERRUP_RBO
   
    ;CUANDO HAGAMOS LA INTERRUPCION POR RB0
    
    ORG 0x05   ; Dirección de inicio de código

MAIN
    ; Configuración de puertos

SETUP
    BANKSEL TRISA
    MOVLW   b'11111110'  ; QTR1, QTR2, QTR3, QTR4 como entradas; QTR5, QTR6 como entradas en el PORTE
    MOVWF   TRISA  
    
    
    ; Configuracion de ADC -- estara en las entradas en el puerto A 
    BANKSEL ADCON1 ;
    MOVLW B'00000000' ;right justify
    MOVWF ADCON1 ;Vdd and Vss as Vref
        
    BANKSEL TRISB
    ; Puerto B para el driver TB6612FNG y periféricos
    MOVLW   b'00000001'  ; MOTOR_A1, MOTOR_A2, MOTOR_B1, MOTOR_B2, PUSH como salidas; PUSH como entrada (botón)
    MOVWF   TRISB
    ;Config para la interrupcion del PUSH (por RB0)
    BANKSEL WPUB         ;Para las resistencias de PULL-UP
    MOVLW   b'00000001'
    MOVWF WPUB
    BANKSEL IOCB         ;Para decidir que bit del puerto B va a interrumpir 
    MOVLW   b'00000001'
    MOVWF IOCB
    BANKSEL OPTION_REG
    CLRF OPTION_REG
    BANKSEL INTCON
    MOVLW   b'10010000'
    MOVWF INTCON
  
    BANKSEL TRISC 
    ; Puerto C para PWM y otros
    MOVLW   b'11111001'  ; PWM_A, PWM_B como salidas
    MOVWF   TRISC
    
    BANKSEL TRISE
    ; Puerto E para QTR5 y QTR6 (entradas)
    MOVLW   b'00000011'  ; QTR5, QTR6 como entradas
    MOVWF   TRISE
    ; Limpiamos el puerto E para arrancar
    BANKSEL PORTE
    CLRF PORTE
    
    ; Configuracion del puerto D para prueba de ADC de QTR3
    BANKSEL TRISD
    CLRF TRISD
    
    
    BANKSEL ANSELH
    MOVLW b'01111110'  
    MOVWF ANSEL
    CLRF ANSELH
    

LOOP
    ; Configuración inicial de los motores y buzzer
    BANKSEL PORTA
    BSF LED_ON
    CALL SENSOR3
    CALL SENSOR4
    
    ; EL 0 ES NEGRO Y EL 1 ES BLANCO
    ;TESTEO SENSORES
    BTFSS SENSOR,0 ;SI EL SENSOR0 ES 0(NEGRO), TESTEA EL OTRO SENSOR 
    GOTO $+7
    BTFSC SENSOR,1
    GOTO $+3
    ;SI SENSOR 0 ES 1 Y EL SENSOR 1 ES 0
    ;GIRAR IZQ
    CALL GIRO_I
    GOTO LOOP
    ;SI AMBOS SENSORES SON 1 (NEGROS)
    ;APAGAR MOTORES
    CALL STOP
    GOTO LOOP
    ;SI EL SENSOR 0 ES 0 (BLANCO)
    BTFSC SENSOR,1 ; SI ES 1 ENTRA (GOTO $+9) DE LA LINEA 118
    GOTO $+3
    ;SI AMBOS SENSORES SON 0 (BLANCOS)
    ;ENCENDER MOTORES
    CALL AVANCE
    GOTO LOOP
    ;SI SENSOR 0 ES 0 Y EL SENSOR 1 ES 1
    ;GIRAR DER
    CALL GIRO_D
    GOTO LOOP
    
    ;CALL AVANCE
    ;CALL DELAY_5S
    ;CALL STOP
    ;CALL DELAY_5S
    ;CALL GIRO_D
    ;CALL DELAY_5S
    ;CALL GIRO_I
    ;CALL DELAY_5S
    
    ;GOTO LOOP
    
SampleTime
    MOVLW .255
    MOVWF CONT
LOOP1
    DECFSZ CONT,F
    GOTO LOOP1
    RETURN
	
SENSOR3
    ;CONFIG DE CANALES ADC    
    ;CANAL 3 -- QTR3
    BANKSEL ADCON0     ; se configura la entrada y conversion del RA3 -- QTR3 
    MOVLW B'11001101' ;ADC Frc clock, OSC INTERNO, RA3, ENABLE=ON
    MOVWF ADCON0 ;AN0, On
ADC_TEST
    ;TIEMPO ADQUISICION
    CALL SampleTime ;Acquisiton delay
    ;EMPEZAR CONVERSION
    BANKSEL ADCON0
    BSF ADCON0,GO ;Start conversion
    ;TESTEAR FINAL CONVERSION
    BTFSC ADCON0,GO ;Is conversion done?
    GOTO $-1 ;No, test again
    ;MOVER RESULTADOS A REGISTROS
    BANKSEL ADRESH ;
    MOVF ADRESH,W ;Read upper 2 bits
    ;MOVWF PORTD ; VEREMOS EN EL PUERTO D, LA CONVERSION ALTA, LOS 8 BITS ALTOS
    MOVWF RESULTHI ;store in GPR space
    BANKSEL ADRESL 
    MOVF ADRESL,W ;Read lower 8 bits
    MOVWF RESULTLO ;Store in GPR space
    ;MOVER REGISTROS A PUERTOS
    BANKSEL STATUS
    MOVLW .128
    SUBWF RESULTHI,W
    BTFSS STATUS,C
    BSF SENSOR,0
    BTFSC STATUS,C
    BCF SENSOR,0
    RETURN
    
SENSOR4
    ;CANAL 4 -- QTR4
    BANKSEL ADCON0     ; se configura la entrada y conversion del RA4 -- QTR4 
    MOVLW B'11010001' ;ADC Frc clock, OSC INTERNO, RA4, ENABLE=ON
    MOVWF ADCON0 ;AN0, On
    ;TIEMPO ADQUISICION
    CALL SampleTime ;Acquisiton delay
    ;EMPEZAR CONVERSION
    BANKSEL ADCON0
    BSF ADCON0,GO ;Start conversion
    ;TESTEAR FINAL CONVERSION
    BTFSC ADCON0,GO ;Is conversion done?
    GOTO $-1 ;No, test again
    ;MOVER RESULTADOS A REGISTROS
    BANKSEL ADRESH ;
    MOVF ADRESH,W ;Read upper 2 bits
    ;MOVWF PORTD ; VEREMOS EN EL PUERTO D, LA CONVERSION ALTA, LOS 8 BITS ALTOS
    MOVWF RESULTHI ;store in GPR space
    BANKSEL ADRESL 
    MOVF ADRESL,W ;Read lower 8 bits
    MOVWF RESULTLO ;Store in GPR space
    ;MOVER REGISTROS A PUERTOS
    BANKSEL STATUS
    MOVLW .128
    SUBWF RESULTHI,W
    BTFSS STATUS,C
    BSF SENSOR,1
    BTFSC STATUS,C
    BCF SENSOR,1
    RETURN
   
    
INTERRUP_RBO
    MOVWF w_temp ; Guarda valor del registro W
    SWAPF STATUS,W ; Guarda valor del registro STATUS
    MOVWF status_temp
    
    BANKSEL INTCON
    BCF INTCON, INTF   ; Bajamos la bandera de la interrupcion
    BSF BUZZER	;buzer
    CALL DELAY_1S
    BCF BUZZER
    CALL DELAY_2S
    BSF BUZZER
    CALL DELAY_1S
    BCF BUZZER
    
    swapf status_temp,W
    movwf STATUS ; a STATUS se le da su contenido original
    swapf w_temp, F ; a W se le da su contenido original
    swapf w_temp, W
    
    RETFIE
    
STOP
   ;Con la siguiente configuración para los dos motores.
    BANKSEL PORTB
    BCF PWM_A
    BCF PWM_B
    ;Motor Izquierdo
    BCF MOTOR_B1  
    BCF MOTOR_B2  
    ;Motor Derecho
    BCF MOTOR_A1  
    BCF MOTOR_A2 
    
    RETURN
    ;BANKSEL PORTB
    ;BCF PWM_A
    ;BCF PWM_B
    ;RETURN
    
    
AVANCE
 ;Con la siguiente configuración avanzan los dos motores.
    BANKSEL PORTB
    BSF PWM_A
    BSF PWM_B
    ;Motor Izquierdo
    BCF MOTOR_B1  
    BSF MOTOR_B2  
    ;Motor Derecho
    BCF MOTOR_A1  
    BSF MOTOR_A2  
    
    RETURN
    
GIRO_D
    BANKSEL PORTB
    BCF PWM_A
    BSF PWM_B
    
    ;Motor Izquierdo
    BCF MOTOR_B1  
    BSF MOTOR_B2  
    ;Motor Derecho
    BCF MOTOR_A1  
    BCF MOTOR_A2  
    
    RETURN
    
GIRO_I
    BANKSEL PORTB
    BSF PWM_A
    BCF PWM_B
   
    ;Motor Izquierdo
    BCF MOTOR_B1  
    BCF MOTOR_B2  
    ;Motor Derecho
    BCF MOTOR_A1  
    BSF MOTOR_A2  
    
    RETURN
    
    
DELAY_2S
     ;Retardo_2s				; La llamada "call" aporta 2 ciclos m?quina.
     movlw	d'20'			; Aporta 1 ciclo m?quina. Este es el valor de "N".
     goto	Retardo_1Decima		; Aporta 2 ciclos m?quina.
     RETURN
DELAY_1S
      ;Retardo_1s				; La llamada "call" aporta 2 ciclos m?quina.
      movlw	d'10'			; Aporta 1 ciclo m?quina. Este es el valor de "N".
      goto	Retardo_1Decima		; Aporta 2 ciclos m?quina.
      RETURN
DELAY_02S
      ;Retardo_1s				; La llamada "call" aporta 2 ciclos m?quina.
      movlw	d'2'			; Aporta 1 ciclo m?quina. Este es el valor de "N".
      goto	Retardo_1Decima		; Aporta 2 ciclos m?quina.
      RETURN
DELAY_05S
      ;Retardo_1s				; La llamada "call" aporta 2 ciclos m?quina.
      movlw	d'5'			; Aporta 1 ciclo m?quina. Este es el valor de "N".
      goto	Retardo_1Decima		; Aporta 2 ciclos m?quina.
      RETURN
DELAY_5S
      ;Retardo_1s				; La llamada "call" aporta 2 ciclos m?quina.
      movlw	d'50'			; Aporta 1 ciclo m?quina. Este es el valor de "N".
      goto	Retardo_1Decima		; Aporta 2 ciclos m?quina.
      RETURN
      

;RETARDO MAIN
Retardo_1Decima
	movwf	R_ContC			; Aporta 1 ciclo m?quina.
R1Decima_BucleExterno2
	movlw	d'100'			; Aporta Nx1 ciclos m?quina. Este es el valor de "M".
	movwf	R_ContB			; Aporta Nx1 ciclos m?quina.
R1Decima_BucleExterno
	movlw	d'249'			; Aporta MxNx1 ciclos m?quina. Este es el valor de "K".
	movwf	R_ContA			; Aporta MxNx1 ciclos m?quina.
R1Decima_BucleInterno          
	nop				; Aporta KxMxNx1 ciclos m?quina.
	decfsz	R_ContA,F		; (K-1)xMxNx1 cm (si no salta) + MxNx2 cm (al saltar).
	goto	R1Decima_BucleInterno	; Aporta (K-1)xMxNx2 ciclos m?quina.
	decfsz	R_ContB,F		; (M-1)xNx1 cm (cuando no salta) + Nx2 cm (al saltar).
	goto	R1Decima_BucleExterno	; Aporta (M-1)xNx2 ciclos m?quina.
	decfsz	R_ContC,F		; (N-1)x1 cm (cuando no salta) + 2 cm (al saltar).
	goto	R1Decima_BucleExterno2	; Aporta (N-1)x2 ciclos m?quina.
	RETURN			; El salto del retorno aporta 2 ciclos m?quina.
    
    END
