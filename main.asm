;CABECERA----------------------------------------------------------------------

RES_VECT  CODE    0x0000            ; processor reset vector
    GOTO    START                   ; go to beginning of program
    ORG 0x04
	GOTO RUT_INTERR

; TODO ADD INTERRUPTS HERE IF USED

MAIN_PROG CODE                      ; let linker place main program
 
;VARIABLES----------------------------------------------------------------------
 NRO_VUELTAS EQU 0x20
 VELOCIDAD_ACT EQU 0x21
 CIFRA_DECENA EQU 0x22
 CIFRA_UNIDAD EQU 0x23
 SSEG_DECENA EQU 0x1A0; 0001 1001 0000
 SSEG_UNIDAD EQU 0x1A1; 0001 1001 0001:solo cambia el bit menos signif
 COPIA_NRO_VUELTAS EQU 0x27;
 
 BANDERAS EQU 0x26;
 BAN_SENSOR EQU 0x0;
 BAN_1MIN EQU 0x1;
 BAN_20MILI EQU 0x2;
 
;CONFIGURACIONES----------------------------------------------------------------------
 CONFIG_TMR1:;cada 60 seg
    BANKSEL T1CON;
    BSF T1CON, T1CKPS1;seleccionamos el presacer de 8
    BSF T1CON, T1CKPS0;
    BANKSEL PIE1;
    BSF PIE1, TMR1E;
    BCF PIR1, TMR1F;
    MOVLW B'00010000';
    MOVWF TMR1H;
    CLRF TMR1L;
    RETURN;
    
 CONFIG_RB0:
    BANKSEL OPTION_REG;
    BSF OPTION_REG, INTED;
    BANKSEL INTCON;
    BSF INTCON, INTE;
    BSF INTCON, GIE;
    RETURN;
    
 CONFIG_TMR0:;cada 20ms
    BANKSEL STATUS;
    MOVLW B'0010111';flanco de subida y prescaler de 256
    MOVWF OPTION_REG;
    BANKSEL INTCON;
    BSF INTCON, T0IE; habilito la interrupcion por tmr0
    BSF INTCON, GIE;
    MOVLW .32;
    MOVWF TMR0;
    RETURN;
    
 CONFIG_PINES_PANTALLA:
    ;TODO configurar ANSEL
    CLRF TRISD;poniendo los pines del puerto d como salida digital
    MOVLW B'11000001'; El pin 0 va como entreda porque es el pin del sensor y los pines 7 y 6 para seleccionar la pantalla
    MOVWF TRISB; 
    RETURN;
 
INCIALIZO_VARIABLES:
    CLRF NRO_VUELTAS;
    CLRF VELOCIDAD_ACT;
    CLRF CIFRA_DECENA
    CLRF CIFRA_UNIDAD
    CLRF SSEG_DECENA
    CLRF SSEG_UNIDAD
    
    MOVLW 0x1A0;
    MOVWF FSR;
    CLRF PORTB;
    MOVLW B'1000000';por defecto seleccionada la pantalla de la decena
    MOVWF PORTD;
    RETURN;
    
 CONFIGS:
    CALL INCIALIZO_VARIABLES;
    CALL CONFIG_TMR1;para el retardo de un minuito
    CALL CONFIG_RB0;cuando gira el disco salta la interrupcion en el pin rb0
    CALL CONFIG_TMR0;para el refresco de las pantallas
    CALL CONFIG_PINES_PANTALLA;puerto d como salida, 2 pines del puerto b para seleccionar las pantalla.
    
    RETURN;
;RUTINA DE INTERR----------------------------------------------------------------------
 RUT_INTERR:
    ;GUARDAS CONTEXTO
    BTFSC INTCON, T0IF;pregunta si llamo el timer 0 cada 20ms
    BSF BANDERAS, BAN_20MILI;
    BTFSC INTCON, INTF;pregunta si salto la bandera de rb0 osea la polea dio una vuelta.
    BSF BANDERAS, BAN_SENSOR;
    BTFSC PIR1, TMR1F;pregunta si salto el tmr1 osea paso 60 seg
    BSF BANDERAS, BAN_1MIN;
    ;RESTAURAR CONTEXTO
    RETFIE
;FUNCIONES----------------------------------------------------------------------
 CONTAR_VUELTA:
    ;si la velocidad excede los 255rpm perdemos el valor pero en la consigna 
    ;dice que el valor maximo posible es 83rpm por lo tanto no hay problema
    INCF NRO_VUELTAS;
    BCF BANDERAS, BAN_SENSOR;
    BCF INTCON, INTF;
    RETURN;
    
 MEDIR_VELOCIDAD:;sucede cada 60 segundos
    MOVFW NRO_VUELTAS;
    MOVWF VELOCIDAD_ACT;
    CLRF NRO_VUELTAS;para reincializar el registro que cuenta las vueltas
    BCF BANDERAS, BAN_1MIN;
    BCF PIR1, TMR1F;
    RETURN;
    

 CALCULAR_CIFRAS_DEC:
    ;va a cargar el valor decimal correspondiente
    ; CIFRA_DECENA, CIFRA_UNIDAD
    CLRF CIFRA_DECENA;
    CLRF CIFRA_UNIDAD;
    MOVFW NRO_VUELTAS;
    MOVWF COPIA_NRO_VUELTAS;
 CICLO
    MOVFW COPIA_NRO_VUELTAS;
    MOVWF CIFRA_UNIDAD; 8
    MOVLW .10;
    SUBWF COPIA_NRO_VUELTAS, F;nv -2
    BTFSS STATUS, ZERO;
    RETURN;
    INCF CIFRA_DECENA;3
    GOTO CICLO;
    RETURN;
 
 TABLA_BCD_7SEG:
    ;comvierte el valor BCD que viene en W a codigo de 7 seg catodo comun
    ADDWF PCL, F;
    RETLW B'00000110';
    RETLW B'01111011';
    ;
    ;
    ;
    ;
    ;
    
 CALCULAR_CODIGOS_7SEG:
    ;teniendo en cuenta los valores de CIFRA_DECENA, CIFRA_UNIDAD
    ;convertirlos en codigo de 7segmentos y cargarlos en 
    ; estas variables SSEG_DECENA(0x1A0) y SSEG_UNIDAD(0x1A1)
    MOVFW CIFRA_DECENA; cargo el valor en w para que consulte la tabla
    CALL TABLA_BCD_7SEG; consulta la tabla y trae el valor en w
    MOVWF SSEG_DECENA;
    MOVFW CIFRA_UNIDAD;
    CALL TABLA_BCD_7SEG
    MOVWF SSEG_UNIDAD;
    RETURN;
 
    
 REFRESCO_DISPLAY:;se ejecuta cada 20ms
    ;como tengo dos displays de 7seg necesito calcular las dos cifras/digitos decimales para mostrar
    ;en la pantalla, adicionalmente estas cifras decimales deben convertirse a el codigo de 7seg.
    ;coloco el valor corresponeidte en el pierto d
    ;y tengo que seleccionar la pantalla correspondiente 
    CALL CALCULAR_CIFRAS_DEC;
    CALL CALCULAR_CODIGOS_7SEG;
    
    MOVFW FSR;
    XORLW B'00000001'; alterno solamente el bit menos significativo del puntero
    MOVWF FSR;entonces puedo alternar de la dir 0x1A0 y 0x1A1 
    
    MOVFW INDF;
    MOVWF PORTB;cargo el valor de los pines de portb conectado a los segmentos de la pantalla
    
    ; Sea port D selecciona la patalla que tiene que estar prendida en este momento
    
    ;[1 0 0 0 0 0 0 0] selecciona la primer pantalla (decena)
    ;XOR
    ;[1 1 0 0 0 0 0 0] operador de xor para alternar los bits 7 y 6
    ;[0 1 0 0 0 0 0 0] consigo alternar los bits deseados, selecciona la segunda pantalla (unidad)
    MOVFW PORTD;
    XORLW B'11000000';
    MOVWF PORTD;
    
    BCF BANDERA, BAN_20MILI;
    BCF INTCON, T0IF;
    RETURN;
;MAIN---------------------------------------------------------------------------
MAIN
    CALL CONFIGS;
BUCLE;bucle de eventos aquí el main tiene que revisar si se produjo algun evento relevante 
    ;cuando se produjo una vuelta de la polea guiada el sensor interrumpe por rb0
    ;cuando pasa un minuto deberia medir las vueltas
    ;cuando pasan 20ms tengo que refrescar los dispays
    BTFSC BANDERAS, BAN_SENSOR;
    CALL CONTAR_VUELTA;
    
    BTFSC BANDERAS, BAN_1MIN;
    CALL MEDIR_VELOCIDAD;
    
    BTFSC BANDERAS, BAN_20MILI;
    CALL REFRESCO_DISPLAY;
    
    GOTO BUCLE
    END
