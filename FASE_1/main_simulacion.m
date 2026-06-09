% =========================================================================
%  MAIN_SIMULACION.M
%  Análisis de un sistema de comunicaciones digital sobre canal AWGN (Fase I)
%  Universidad del Cauca — Comunicaciones digitales
% -------------------------------------------------------------------------
%  Esquema de modulación : 16-QAM  (M=16, k=4 bits/símbolo)
%  Conformación de pulso : Coseno alzado raíz (RRC) en Tx y Rx
%                          RRC(Tx) * RRC(Rx) = RC → criterio de Nyquist
%  Canal                 : AWGN (señal pasabanda real)
%
%  Requerimientos cumplidos:
%    RF1-RF7  : Modulación, canal, demodulación, BER, curvas de desempeño,
%               diagrama del ojo, constelación y espectro.
%    RNF1-RNF5: Modularidad, granularidad, sin funciones especiales,
%               M=16 > 4 (bidimensional), reproducibilidad (semilla fija).
% =========================================================================

clear; clc; close all;

%% Agregar todas las subcarpetas del proyecto al path de MATLAB.
addpath(genpath(fileparts(mfilename('fullpath'))));

% -------------------------------------------------------------------------
% 1. CONFIGURACIÓN DEL SISTEMA
% -------------------------------------------------------------------------
% Todos los parámetros se definen y validan en config_sistema.m.
params = config_sistema();

% Extraer parámetros a variables locales para legibilidad.
orden_modulacion_M       = params.orden_modulacion_M;
bits_por_simbolo         = params.bits_por_simbolo;
muestras_por_simbolo_sps = params.muestras_por_simbolo_sps;
frecuencia_muestreo_fs   = params.frecuencia_muestreo_fs;
factor_roll_off_beta     = params.factor_roll_off_beta;
span_filtro_simbolos     = params.span_filtro_simbolos;
frecuencia_portadora_fc  = params.frecuencia_portadora_fc;
numero_bits_a_transmitir = params.numero_bits;
vector_EbNo_dB           = params.vector_EbNo_dB;

% Fijar semilla para reproducibilidad (RNF5).
rng(params.semilla_aleatoria);

% -------------------------------------------------------------------------
% 2. PRESENTACIÓN DEL SISTEMA
% -------------------------------------------------------------------------
fprintf('=========================================================\n');
fprintf('  SISTEMA DE COMUNICACIONES DIGITALES 16-QAM / AWGN  \n');
fprintf('  Universidad del Cauca — Comunicaciones Digitales     \n');
fprintf('=========================================================\n');
fprintf('  Modulación             : 16-QAM\n');
fprintf('  Orden M                : %d\n',    orden_modulacion_M);
fprintf('  Bits por símbolo k     : %d\n',    bits_por_simbolo);
fprintf('  Número de bits         : %d\n',    numero_bits_a_transmitir);
fprintf('  Tasa de símbolos Rs    : %g baudios\n', params.tasa_simbolos_Rs);
fprintf('  Muestras por símbolo   : %d\n',    muestras_por_simbolo_sps);
fprintf('  Frecuencia de muestreo : %g Hz\n', frecuencia_muestreo_fs);
fprintf('  Frecuencia portadora   : %g Hz\n', frecuencia_portadora_fc);
fprintf('  Roll-off β             : %.2f\n',  factor_roll_off_beta);
fprintf('  Span del filtro        : %d símbols\n', span_filtro_simbolos);
fprintf('  Rango Eb/No            : %g a %g dB\n', ...
    min(vector_EbNo_dB), max(vector_EbNo_dB));
fprintf('  Semilla aleatoria      : %d\n',    params.semilla_aleatoria);
fprintf('=========================================================\n\n');

% -------------------------------------------------------------------------
% 3. PRE-CÁLCULO DEL FILTRO RRC
% -------------------------------------------------------------------------
% El filtro se genera UNA sola vez porque no depende de Eb/No.
% En Tx y Rx se usa el mismo filtro → filtro acoplado → RC total (Nyquist).
coeficientes_filtro_rrc = filtro_coseno_alzado_raiz( ...
    factor_roll_off_beta, span_filtro_simbolos, muestras_por_simbolo_sps);

% -------------------------------------------------------------------------
% 4. BARRIDO DE Eb/No  (RF4, RF5)
% -------------------------------------------------------------------------
numero_puntos_EbNo = length(vector_EbNo_dB);
vector_BER_simulada = zeros(1, numero_puntos_EbNo);
vector_BER_teorica  = zeros(1, numero_puntos_EbNo);

% Determinar el índice del Eb/No elegido para las gráficas.
indice_EbNo_graficas = find(abs(vector_EbNo_dB - params.EbNo_dB_graficas) < 1e-9, 1);

% Inicializar variables de captura para evitar referencias indefinidas.
senal_pasabanda_guardada_para_grafica = [];
senal_basebanda_rx_guardada_para_ojo  = [];
simbolos_guardados_para_constelacion  = [];

fprintf('--- Barrido de Eb/No ---\n');

for indice_EbNo = 1:numero_puntos_EbNo
    valor_EbNo_dB_actual = vector_EbNo_dB(indice_EbNo);

    % --- TRANSMISOR (RF1) -------------------------------------------------
    % 1) Generación de bits y mapeo Gray 16-QAM.
    [secuencia_bits_transmitidos, simbolos_complejos_transmitidos] = ...
        modulador_binario_16qam(numero_bits_a_transmitir);

    % 2) Conformación de pulso: upsampling manual + filtrado RRC.
    senal_banda_base_conformada = conformacion_pulso( ...
        simbolos_complejos_transmitidos, coeficientes_filtro_rrc, ...
        muestras_por_simbolo_sps);

    % 3) Modulación a pasabanda (señal estrictamente real).
    senal_pasabanda_transmitida = modulacion_pasabanda( ...
        senal_banda_base_conformada, frecuencia_portadora_fc, frecuencia_muestreo_fs);

    % --- CANAL AWGN (RF2) -------------------------------------------------
    senal_pasabanda_recibida = canal_awgn( ...
        senal_pasabanda_transmitida, valor_EbNo_dB_actual, ...
        bits_por_simbolo, muestras_por_simbolo_sps);

    % --- RECEPTOR (RF3) ---------------------------------------------------
    % Down-conversion + filtro acoplado RRC + muestreo óptimo + decisor + demapeo.
    [secuencia_bits_recibidos,                ...
     simbolos_recibidos_post_filtro_acoplado, ...
     senal_banda_base_filtrada_rx] = demodulador_16qam( ...
        senal_pasabanda_recibida, coeficientes_filtro_rrc, ...
        muestras_por_simbolo_sps, span_filtro_simbolos, ...
        frecuencia_portadora_fc, frecuencia_muestreo_fs);

    % --- CÁLCULO DE BER (RF4) ---------------------------------------------
    [vector_BER_simulada(indice_EbNo), vector_BER_teorica(indice_EbNo)] = ...
        calculo_ber(secuencia_bits_transmitidos, secuencia_bits_recibidos, ...
                    valor_EbNo_dB_actual, orden_modulacion_M);

    fprintf('  Eb/No = %5.1f dB | BER sim = %.3e | BER teo = %.3e\n', ...
        valor_EbNo_dB_actual, vector_BER_simulada(indice_EbNo), vector_BER_teorica(indice_EbNo));

    % --- CAPTURA PARA GRÁFICAS --------------------------------------------
    % Se guardan los datos del Eb/No elegido en params.EbNo_dB_graficas.
    if indice_EbNo == indice_EbNo_graficas
        senal_pasabanda_guardada_para_grafica = senal_pasabanda_transmitida;
        senal_basebanda_rx_guardada_para_ojo  = senal_banda_base_filtrada_rx;
        simbolos_guardados_para_constelacion  = simbolos_recibidos_post_filtro_acoplado;
    end
end

% -------------------------------------------------------------------------
% 5. GRÁFICAS  (RF5, RF6, RF7)
% -------------------------------------------------------------------------
fprintf('\n--- Generando gráficas ---\n');

graficas_simulacion( ...
    vector_EbNo_dB,                            ...
    vector_BER_simulada,                       ...
    vector_BER_teorica,                        ...
    simbolos_guardados_para_constelacion,      ...
    senal_basebanda_rx_guardada_para_ojo,      ...
    senal_pasabanda_guardada_para_grafica,     ...
    muestras_por_simbolo_sps,                  ...
    frecuencia_muestreo_fs,                    ...
    span_filtro_simbolos,                      ...
    params.EbNo_dB_graficas);

% -------------------------------------------------------------------------
% 6. PRUEBAS DE VALIDACIÓN
% -------------------------------------------------------------------------
fprintf('\n--- Ejecutando pruebas de validación ---\n');
resultados_pruebas = pruebas_validacion(params);

verificar_funciones_prohibidas();

% -------------------------------------------------------------------------
% 7. RESUMEN FINAL
% -------------------------------------------------------------------------
fprintf('=========================================================\n');
fprintf('  RESUMEN FINAL\n');
fprintf('=========================================================\n');
fprintf('  Sistema         : 16-QAM sobre canal AWGN\n');
fprintf('  M = %d, k = %d bits/símbolo\n', orden_modulacion_M, bits_por_simbolo);
fprintf('  BER más baja    : %.3e (Eb/No = %.1f dB)\n', ...
    min(vector_BER_simulada(vector_BER_simulada > 0)), ...
    vector_EbNo_dB(vector_BER_simulada == min(vector_BER_simulada(vector_BER_simulada > 0))));
if resultados_pruebas.todas_aprobadas
    fprintf('  Pruebas         : TODAS APROBADAS\n');
else
    fprintf('  Pruebas         : ALGUNAS FALLARON — revisar el sistema\n');
end
fprintf('  Gráficas        : 4 figuras generadas\n');
fprintf('=========================================================\n');
fprintf('Simulación finalizada correctamente.\n');
