% =========================================================================
%  MAIN_FASE2
%  =========================================================================
%  Script principal de la Fase II: Fuente de Audio + Codificación de Canal
%
%  Extiende el sistema 16-QAM sobre AWGN de la Fase I añadiendo:
%    · Fuente de audio real (PCM, 16 bits, 44100 Hz).
%    · Conversión analógico-digital (ADC) uniforme Midrise.
%    · Código corrector de errores Hamming(7,4).
%    · Comparación de BER con y sin codificación.
%    · Recuperación del audio al finalizar la cadena completa.
%
%  Restricciones mantenidas: NO se usa qammod, qamdemod, rcosdesign,
%  eyediagram, awgn (toolbox), pwelch, scatterplot, encode, decode,
%  hammgen ni ninguna función de Communications Toolbox.
%
%  Uso:
%    >> cd FASE_2
%    >> main_fase2
%
%  =========================================================================

clc;
close all;

% -------------------------------------------------------------------------
%  0. Configurar rutas (acceso a módulos de Fase I y Fase II).
% -------------------------------------------------------------------------
raiz_proyecto = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(raiz_proyecto));

fprintf('=========================================================\n');
fprintf('       SIMULACIÓN FASE II — 16-QAM + Hamming(7,4)\n');
fprintf('       Universidad del Cauca, Comunicaciones Digitales\n');
fprintf('=========================================================\n\n');

% -------------------------------------------------------------------------
%  1. Cargar configuraciones.
% -------------------------------------------------------------------------
params_f1 = config_sistema();     % Parámetros Fase I  (16-QAM, RRC, AWGN…)
params_f2 = config_fase2();       % Parámetros Fase II (audio, Hamming…)

% Alias de variables frecuentes (legibilidad).
M    = params_f1.orden_modulacion_M;       % 16
k    = params_f1.bits_por_simbolo;         % 4
sps  = params_f1.muestras_por_simbolo_sps; % 8
span = params_f1.span_filtro_simbolos;     % 6
fc   = params_f1.frecuencia_portadora_fc;  % 2 Hz (normalizado)
fs   = params_f1.frecuencia_muestreo_fs;   % 8 Hz
B    = params_f2.bits_por_muestra;         % 16
r    = params_f2.tasa_codigo;              % 4/7
pen  = params_f2.penalizacion_codigo_dB;   % 10·log10(4/7) ≈ −2.43 dB

rng(params_f1.semilla_aleatoria);

fprintf('[Config] M=%d-QAM | sps=%d | β=%.2f | span=%d | fc=%d | fs=%d Hz\n', ...
    M, sps, params_f1.factor_roll_off_beta, span, fc, fs);
fprintf('[Config] ADC: B=%d bits | fs_audio=%.0f Hz\n', B, params_f2.fs_audio);
fprintf('[Config] Hamming(%d,%d) | r=%.4f | penalización=%.2f dB\n\n', ...
    params_f2.hamming_n, params_f2.hamming_k, r, pen);

% -------------------------------------------------------------------------
%  2. Generar o cargar señal de audio de prueba.
% -------------------------------------------------------------------------
if ~exist(params_f2.ruta_audio_prueba, 'file')
    fprintf('[Audio] Generando audio de prueba (primera ejecución)...\n');
    generar_audio_prueba(params_f2.ruta_audio_prueba);
end

[audio_completo, fs_lectura] = audioread(params_f2.ruta_audio_prueba);

% Mezclar a mono si es estéreo.
if size(audio_completo, 2) > 1
    audio_completo = mean(audio_completo, 2);
    fprintf('[Audio] Señal estéreo mezclada a mono.\n');
end

% Verificar frecuencia de muestreo.
if fs_lectura ~= params_f2.fs_audio
    error('main_fase2: fs del archivo (%.0f Hz) ≠ params_f2.fs_audio (%.0f Hz).', ...
        fs_lectura, params_f2.fs_audio);
end

N_total = length(audio_completo);
fprintf('[Audio] Cargado: %d muestras (%.1f s) a %.0f Hz\n\n', ...
    N_total, N_total/params_f2.fs_audio, params_f2.fs_audio);

% -------------------------------------------------------------------------
%  3. Conversión ADC del segmento de barrido (1 segundo).
% -------------------------------------------------------------------------
fprintf('[ADC] Cuantificando segmento de barrido (%d s)...\n', params_f2.duracion_sweep_s);
N_sweep = params_f2.N_muestras_sweep;   % 44100 muestras = 1 segundo

% Extraer el primer segundo de audio para el barrido BER.
audio_sweep = audio_completo(1:N_sweep);

[bits_pcm_sweep, ~, ~, ~] = conversor_adc(audio_sweep, B, params_f2.fs_audio);
% bits_pcm_sweep: 705 600 bits (44100 × 16)

% Garantizar múltiplo de 4 (debería serlo siempre con B=16).
N_bits_sweep = length(bits_pcm_sweep);
N_bits_sweep = N_bits_sweep - mod(N_bits_sweep, 4);
bits_pcm_sweep = bits_pcm_sweep(1:N_bits_sweep);

fprintf('[ADC] bits_pcm_sweep = %d bits (%.1f Kbps efectivos)\n\n', ...
    N_bits_sweep, N_bits_sweep / params_f2.duracion_sweep_s / 1e3);

% -------------------------------------------------------------------------
%  4. Codificación Hamming(7,4) del segmento de barrido.
% -------------------------------------------------------------------------
fprintf('[Hamming] Codificando segmento de barrido...\n');
bits_hamming_sweep = codificador_hamming(bits_pcm_sweep);
% bits_hamming_sweep: N_bits_sweep × 7/4 = 1 234 800 bits
N_bits_cod = length(bits_hamming_sweep);
fprintf('[Hamming] bits_codificados = %d bits (expansión ×%.2f)\n\n', ...
    N_bits_cod, N_bits_cod / N_bits_sweep);

% -------------------------------------------------------------------------
%  5. Pre-calcular filtro RRC y señales pasabanda (FUERA del bucle de BER).
%     Optimización: la modulación es igual para todos los Eb/N0.
%     Solo canal_awgn + demodulacion varían en cada iteración.
% -------------------------------------------------------------------------
fprintf('[Filtro] Calculando filtro RRC (β=%.2f, span=%d, sps=%d)...\n', ...
    params_f1.factor_roll_off_beta, span, sps);
h_rrc = filtro_coseno_alzado_raiz(params_f1.factor_roll_off_beta, span, sps);

% --- Sistema SIN codificación ---
fprintf('[Mod] Modulando señal SIN codificación (%d bits)...\n', N_bits_sweep);
[~, simbolos_sc] = modulador_binario_16qam(N_bits_sweep, bits_pcm_sweep);
senal_bb_sc = conformacion_pulso(simbolos_sc, h_rrc, sps);
senal_pb_sc = modulacion_pasabanda(senal_bb_sc, fc, fs);
fprintf('[Mod] Señal pasabanda SC: %d muestras\n', length(senal_pb_sc));

% --- Sistema CON codificación Hamming ---
fprintf('[Mod] Modulando señal CON Hamming (%d bits)...\n', N_bits_cod);
[~, simbolos_cc] = modulador_binario_16qam(N_bits_cod, bits_hamming_sweep);
senal_bb_cc = conformacion_pulso(simbolos_cc, h_rrc, sps);
senal_pb_cc = modulacion_pasabanda(senal_bb_cc, fc, fs);
fprintf('[Mod] Señal pasabanda CC: %d muestras\n\n', length(senal_pb_cc));

% -------------------------------------------------------------------------
%  6. Barrido de BER — Eb/N0 de 0 a 14 dB.
% -------------------------------------------------------------------------
vector_EbNo = params_f2.vector_EbNo_dB;
N_puntos    = length(vector_EbNo);

BER_sim_sc = zeros(1, N_puntos);   % BER simulada, sin codificación
BER_sim_cc = zeros(1, N_puntos);   % BER simulada, con Hamming(7,4)

fprintf('=========================================================\n');
fprintf('  BARRIDO BER  (Eb/No = %d a %d dB, %d puntos)\n', ...
    vector_EbNo(1), vector_EbNo(end), N_puntos);
fprintf('  Eb/No [dB]  |  BER SC (sim)  |  BER CC (sim)  |  Progreso\n');
fprintf('---------------------------------------------------------\n');

for idx = 1:N_puntos
    EbNo_dB_actual = vector_EbNo(idx);

    % ---- A) Sistema SIN codificación ----------------------------------------
    senal_rx_sc = canal_awgn(senal_pb_sc, EbNo_dB_actual, k, sps);
    [bits_rx_sc, ~, ~] = demodulador_16qam(senal_rx_sc, h_rrc, sps, span, fc, fs);
    [BER_sim_sc(idx), ~] = calculo_ber(bits_pcm_sweep, bits_rx_sc, ...
                                        EbNo_dB_actual, M);

    % ---- B) Sistema CON Hamming(7,4) ----------------------------------------
    % Ec/N0 = r · Eb/N0 → se pasa al canal la energía por bit CODIFICADO.
    EcNo_dB_actual = EbNo_dB_actual + pen;   % Ec/N0 [dB]

    senal_rx_cc = canal_awgn(senal_pb_cc, EcNo_dB_actual, k, sps);
    [bits_rx_cc, ~, ~] = demodulador_16qam(senal_rx_cc, h_rrc, sps, span, fc, fs);

    % Truncar a múltiplo de 7 antes de decodificar.
    N_val_cc  = floor(min(length(bits_hamming_sweep), length(bits_rx_cc)) / 7) * 7;
    [bits_decod_cc, ~] = decodificador_hamming(bits_rx_cc(1:N_val_cc));

    % Comparar bits decodificados con bits de datos originales.
    N_datos_cc   = length(bits_decod_cc);   % = N_val_cc * 4/7
    errores_cc   = sum(bits_decod_cc ~= bits_pcm_sweep(1:N_datos_cc));
    BER_sim_cc(idx) = errores_cc / N_datos_cc;

    % ---- Progreso en consola ------------------------------------------------
    fprintf('  %6.1f dB    |   %.3e    |   %.3e    |  %d/%d\n', ...
        EbNo_dB_actual, BER_sim_sc(idx), BER_sim_cc(idx), idx, N_puntos);
end

fprintf('=========================================================\n\n');

% -------------------------------------------------------------------------
%  7. BER teórica (primeros principios).
% -------------------------------------------------------------------------
fprintf('[Teoría] Calculando curvas BER analíticas...\n');
[BER_teo_sc, BER_teo_cc] = calculo_ber_codificado( ...
    vector_EbNo, M, r, params_f2.hamming_n, params_f2.hamming_k, params_f2.hamming_t);

% -------------------------------------------------------------------------
%  8. Recuperación del audio completo a Eb/No = params_f2.EbNo_dB_audio.
% -------------------------------------------------------------------------
fprintf('[Audio-Rec] Recuperando audio completo a Eb/N0 = %d dB...\n', ...
    params_f2.EbNo_dB_audio);

% ADC del audio completo (10 segundos).
[bits_pcm_full, ~, ~, ~] = conversor_adc(audio_completo, B, params_f2.fs_audio);
N_bits_full = length(bits_pcm_full);
N_bits_full = N_bits_full - mod(N_bits_full, 4);
bits_pcm_full = bits_pcm_full(1:N_bits_full);

% Codificación Hamming del audio completo.
bits_hamming_full = codificador_hamming(bits_pcm_full);
N_bits_cod_full   = length(bits_hamming_full);

fprintf('[Audio-Rec] Bits PCM = %d | Bits Hamming = %d\n', ...
    N_bits_full, N_bits_cod_full);

% Modulación + transmisión + demodulación.
[~, simbolos_full] = modulador_binario_16qam(N_bits_cod_full, bits_hamming_full);
senal_bb_full = conformacion_pulso(simbolos_full, h_rrc, sps);
senal_pb_full = modulacion_pasabanda(senal_bb_full, fc, fs);

EcNo_dB_audio = params_f2.EbNo_dB_audio + pen;
senal_rx_full = canal_awgn(senal_pb_full, EcNo_dB_audio, k, sps);
[bits_rx_full, ~, ~] = demodulador_16qam(senal_rx_full, h_rrc, sps, span, fc, fs);

% Decodificación Hamming del audio completo.
N_val_full    = floor(min(N_bits_cod_full, length(bits_rx_full)) / 7) * 7;
[bits_decod_full, n_corr_full] = decodificador_hamming(bits_rx_full(1:N_val_full));

fprintf('[Audio-Rec] Codewords con corrección aplicada: %d\n', n_corr_full);

% DAC: reconstruir señal de audio.
audio_recuperado = conversor_dac(bits_decod_full, B);

% Alinear longitudes para comparación.
N_audio_recuperado = length(audio_recuperado);
N_audio_referencia = min(length(audio_completo), N_audio_recuperado);

% Calcular BER de recuperación y SNR del audio.
N_datos_full = length(bits_decod_full);
N_ref        = min(N_bits_full, N_datos_full);
BER_audio    = sum(bits_decod_full(1:N_ref) ~= bits_pcm_full(1:N_ref)) / N_ref;

fprintf('[Audio-Rec] BER recuperación (%d dB): %.3e\n', params_f2.EbNo_dB_audio, BER_audio);

% Guardar audio recuperado.
audiowrite(params_f2.ruta_audio_recuperado, ...
    audio_recuperado(1:N_audio_recuperado), params_f2.fs_audio, ...
    'BitsPerSample', B);
fprintf('[Audio-Rec] Audio guardado en: %s\n\n', params_f2.ruta_audio_recuperado);

% -------------------------------------------------------------------------
%  9. Resumen de resultados.
% -------------------------------------------------------------------------
fprintf('=========================================================\n');
fprintf('  RESUMEN DE RESULTADOS\n');
fprintf('=========================================================\n');
fprintf('  Eb/N0 [dB] | BER SC teór  | BER SC sim   | BER CC teór  | BER CC sim\n');
fprintf('  -----------------------------------------------------------------\n');
for idx = 1:N_puntos
    fprintf('    %5.1f dB  | %9.2e    | %9.2e    | %9.2e    | %9.2e\n', ...
        vector_EbNo(idx), BER_teo_sc(idx), BER_sim_sc(idx), ...
        BER_teo_cc(idx), BER_sim_cc(idx));
end
fprintf('=========================================================\n\n');

% Ganancia de codificación a un punto de referencia (12 dB).
idx_ref = find(abs(vector_EbNo - 12) < 1e-9, 1);
if ~isempty(idx_ref)
    if BER_sim_cc(idx_ref) > 0 && BER_sim_sc(idx_ref) > 0
        ganancia_sim_dB = 10 * log10(BER_sim_sc(idx_ref) / BER_sim_cc(idx_ref));
    else
        ganancia_sim_dB = Inf;
    end
    fprintf('[Resultado] A 12 dB: BER SC=%.2e | BER CC=%.2e | Ganancia≈%.1f dB (en BER)\n', ...
        BER_sim_sc(idx_ref), BER_sim_cc(idx_ref), ganancia_sim_dB);
end

% -------------------------------------------------------------------------
%  10. Gráficas.
% -------------------------------------------------------------------------
fprintf('\n[Gráficas] Generando figuras...\n');
graficas_fase2(vector_EbNo, BER_sim_sc, BER_teo_sc, BER_sim_cc, BER_teo_cc, ...
               audio_completo(1:N_audio_referencia), ...
               audio_recuperado(1:N_audio_referencia), ...
               params_f2.fs_audio, params_f2.EbNo_dB_audio, B);

% -------------------------------------------------------------------------
%  11. Pruebas de validación automáticas.
% -------------------------------------------------------------------------
fprintf('[Pruebas] Ejecutando pruebas de validación Fase II...\n');
resultados_f2 = pruebas_fase2(params_f1, params_f2);

% -------------------------------------------------------------------------
%  12. Verificar que no se usen funciones prohibidas.
% -------------------------------------------------------------------------
verificar_funciones_prohibidas();

fprintf('=========================================================\n');
fprintf('       SIMULACIÓN FASE II COMPLETADA\n');
fprintf('=========================================================\n');
