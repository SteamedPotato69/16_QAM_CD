% =========================================================================
%  MAIN_SIMULACION.M
%  Análisis de un sistema de comunicaciones digital sobre canal AWGN (Fase I)
%  Universidad del Cauca - Comunicaciones digitales
% -------------------------------------------------------------------------
%  Esquema de modulación: 16-QAM (M=16, k=4 bits/símbolo)
%  Conformación de pulso: Coseno alzado raíz (RRC) en Tx y Rx (filtro acoplado)
%                         => cascada RRC*RRC = Coseno alzado (RC) -> Nyquist
%  Canal: AWGN
%
%  Cumple los requerimientos:
%    RF1-RF7  : Modulación, canal, demodulación, BER, curvas, ojo,
%               constelación y espectro.
%    RNF1-RNF5: Modularidad, granularidad, sin funciones especiales
%               (qammod, rcosdesign, eyediagram, etc.), M=16 > 4,
%               reproducibilidad (semilla fija).
% =========================================================================

clear; clc; close all;

% -------------------------------------------------------------------------
% 1. PARÁMETROS GLOBALES DEL SISTEMA
% -------------------------------------------------------------------------
% Semilla para reproducibilidad (RNF5).
semilla_aleatoria = 2026;
rng(semilla_aleatoria);

% Parámetros de la modulación digital.
orden_modulacion_M       = 16;                          % Orden de la modulación (16-QAM).
bits_por_simbolo         = log2(orden_modulacion_M);    % k = 4 bits/símbolo.

% Parámetros de tiempo / tasa.
tasa_simbolos_Rs         = 1;                           % Rs normalizada a 1 baudio.
muestras_por_simbolo_sps = 8;                           % Sobremuestreo (sps).
frecuencia_muestreo_fs   = tasa_simbolos_Rs * muestras_por_simbolo_sps; % fs = Rs*sps.
periodo_simbolo_Ts       = 1/tasa_simbolos_Rs;          % Ts = 1/Rs.
periodo_muestreo_Tm      = 1/frecuencia_muestreo_fs;    % T = 1/fs.

% Parámetros del filtro coseno alzado raíz (RRC).
factor_roll_off_beta     = 0.35;                        % Factor de roll-off (0<=β<=1).
span_filtro_simbolos     = 6;                           % Longitud del filtro: ±span símbolos.

% Frecuencia portadora para la modulación pasabanda.
% Debe cumplir: fc + B < fs/2  (B = (1+β)*Rs/2 ≈ 0.675 para β=0.35).
frecuencia_portadora_fc  = 2 * tasa_simbolos_Rs;        % fc = 2*Rs.

% Parámetros de la simulación.
numero_bits_a_transmitir = 1e5;                         % Tamaño del paquete.
% Aseguramos que el número de bits sea múltiplo de k.
numero_bits_a_transmitir = bits_por_simbolo * ...
                           floor(numero_bits_a_transmitir/bits_por_simbolo);

% Rango de Eb/No (dB) a barrer para la curva BER.
vector_EbNo_dB           = 0:1:14;
numero_puntos_EbNo       = length(vector_EbNo_dB);

% Vectores donde se guardarán las BERs en cada Eb/No.
vector_BER_simulada      = zeros(1, numero_puntos_EbNo);
vector_BER_teorica       = zeros(1, numero_puntos_EbNo);

% -------------------------------------------------------------------------
% 2. PRE-CÁLCULO: FILTRO RRC (mismo en Tx y Rx => filtro acoplado).
% -------------------------------------------------------------------------
% Se genera UNA sola vez porque no depende del Eb/No.
coeficientes_filtro_rrc = filtro_coseno_alzado_raiz( ...
                            factor_roll_off_beta,    ...
                            span_filtro_simbolos,    ...
                            muestras_por_simbolo_sps);

% -------------------------------------------------------------------------
% 3. BARRIDO DE Eb/No  (RF4, RF5)
% -------------------------------------------------------------------------
% Para cada valor de Eb/No, se ejecuta una corrida completa Tx -> canal -> Rx
% y se calcula la BER simulada. La BER teórica se calcula analíticamente.
for indice_EbNo = 1:numero_puntos_EbNo
    valor_EbNo_dB_actual = vector_EbNo_dB(indice_EbNo);

    % --- 3.1 TRANSMISOR (RF1) ----------------------------------------------
    % 3.1.1 Generación de bits y mapeo Gray a 16-QAM.
    [secuencia_bits_transmitidos, simbolos_complejos_transmitidos] = ...
        modulador_binario_16qam(numero_bits_a_transmitir);

    % 3.1.2 Conformación de pulso (upsampling + filtrado RRC).
    senal_banda_base_conformada = conformacion_pulso( ...
        simbolos_complejos_transmitidos, ...
        coeficientes_filtro_rrc,         ...
        muestras_por_simbolo_sps);

    % 3.1.3 Modulación a pasabanda (subida con la portadora).
    senal_pasabanda_transmitida = modulacion_pasabanda( ...
        senal_banda_base_conformada, ...
        frecuencia_portadora_fc,     ...
        frecuencia_muestreo_fs);

    % --- 3.2 CANAL AWGN (RF2) ---------------------------------------------
    senal_pasabanda_recibida = canal_awgn( ...
        senal_pasabanda_transmitida, ...
        valor_EbNo_dB_actual,        ...
        bits_por_simbolo,            ...
        muestras_por_simbolo_sps);

    % --- 3.3 RECEPTOR (RF3) ------------------------------------------------
    % El demodulador integra: bajada de pasabanda + filtro acoplado RRC
    % + decisor + demapeo Gray inverso.
    [secuencia_bits_recibidos,                ...
     simbolos_recibidos_post_filtro_acoplado, ...
     senal_banda_base_filtrada_rx] = demodulador_16qam( ...
        senal_pasabanda_recibida,    ...
        coeficientes_filtro_rrc,     ...
        muestras_por_simbolo_sps,    ...
        span_filtro_simbolos,        ...
        frecuencia_portadora_fc,     ...
        frecuencia_muestreo_fs);

    % --- 3.4 CÁLCULO DE BER (RF4) -----------------------------------------
    [vector_BER_simulada(indice_EbNo), vector_BER_teorica(indice_EbNo)] = ...
        calculo_ber(                              ...
            secuencia_bits_transmitidos,          ...
            secuencia_bits_recibidos,             ...
            valor_EbNo_dB_actual,                 ...
            orden_modulacion_M);

    % --- 3.5 GUARDAR DATOS DEL Eb/No "MEDIO" PARA LAS GRÁFICAS ------------
    % Se eligen los datos a un Eb/No intermedio para mostrar las gráficas
    % de constelación, ojo y espectro (se ven bien sin ruido extremo).
    if abs(valor_EbNo_dB_actual - 10) < 1e-9
        senal_pasabanda_guardada_para_grafica  = senal_pasabanda_transmitida;
        senal_basebanda_rx_guardada_para_ojo   = senal_banda_base_filtrada_rx;
        simbolos_guardados_para_constelacion   = simbolos_recibidos_post_filtro_acoplado;
    end

    fprintf('Eb/No = %5.1f dB | BER simulada = %.3e | BER teórica = %.3e\n', ...
        valor_EbNo_dB_actual,                                                ...
        vector_BER_simulada(indice_EbNo),                                    ...
        vector_BER_teorica(indice_EbNo));
end

% -------------------------------------------------------------------------
% 4. GRÁFICAS  (RF5, RF6, RF7)
% -------------------------------------------------------------------------
graficas_simulacion(                                ...
    vector_EbNo_dB,                                 ...
    vector_BER_simulada,                            ...
    vector_BER_teorica,                             ...
    simbolos_guardados_para_constelacion,           ...
    senal_basebanda_rx_guardada_para_ojo,           ...
    senal_pasabanda_guardada_para_grafica,          ...
    muestras_por_simbolo_sps,                       ...
    frecuencia_muestreo_fs,                         ...
    span_filtro_simbolos);

disp('Simulación finalizada correctamente.');
