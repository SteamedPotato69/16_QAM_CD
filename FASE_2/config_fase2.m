function params = config_fase2()
% =========================================================================
%  CONFIG_FASE2
%  ------------------------------------------------------------------------
%  Define y valida todos los parámetros específicos de la Fase II:
%  fuente de audio (ADC/DAC), código de corrección de errores Hamming(7,4)
%  y configuración de la simulación comparativa (con/sin codificación).
%
%  Los parámetros del sistema 16-QAM de Fase I se obtienen por separado
%  llamando a config_sistema().
%
%  Salida:
%    params : struct con los parámetros de Fase II validados.
% =========================================================================

    % ---- Fuente de audio (RF1-Fase2) ----------------------------------------
    params.bits_por_muestra    = 16;       % Resolución ADC/DAC [bits/muestra]
    params.fs_audio            = 44100;    % Frecuencia de muestreo audio [Hz]
    params.duracion_audio_min_s = 10;      % Duración mínima aceptable [s]
    params.duracion_audio_max_s = 20;      % Duración máxima — se recorta si supera [s]

    % Tasa de bits de la fuente (PCM, mono, sin comprimir).
    params.tasa_bits_fuente    = params.fs_audio * params.bits_por_muestra;
    % = 44100 × 16 = 705 600 bps

    % ---- Segmento para el barrido BER (RF3-Fase2) ---------------------------
    % Se usa 1 segundo de audio para el barrido de Eb/No, lo que da
    % ~705 600 bits útiles — suficiente para medir BER hasta ~10^-5.
    % La recuperación completa del audio se hace con todos los 10 s.
    params.duracion_sweep_s    = 1;        % [s] segmento para barrido BER

    % Número de muestras para barrido.
    params.N_muestras_sweep    = params.fs_audio * params.duracion_sweep_s;
    % = 44 100 muestras → 705 600 bits PCM

    % ---- Código Hamming(7,4) (RF2-Fase2) ------------------------------------
    params.hamming_n           = 7;        % Longitud de la palabra código
    params.hamming_k           = 4;        % Bits de datos por codeword
    params.hamming_t           = 1;        % Capacidad de corrección (1 error)
    params.hamming_d_min       = 3;        % Distancia mínima de Hamming
    params.tasa_codigo         = 4/7;      % Tasa r = k/n

    % ---- Entrelazado para la rama codificada (experimental) ----------------
    % El entrelazado dispersa errores en canales con memoria (ráfagas).
    % En AWGN los errores ya son independientes, por lo que el entrelazado
    % no mejora la BER. Se deja desactivado por defecto; puede activarse
    % para experimentar con canales con burst errors.
    params.usar_entrelazado        = false;
    params.semilla_entrelazado     = 2027;  % semilla para el barrido BER
    params.semilla_entrelazado_full = 2028; % semilla para la recuperación de audio

    % Penalización de Eb/No por la tasa del código [dB].
    % Para el canal (bits codificados): Ec/N0 = r · Eb/N0
    % → EcNo_dB = EbNo_dB + 10·log10(r) = EbNo_dB − 2.43 dB
    params.penalizacion_codigo_dB = 10 * log10(params.tasa_codigo);
    % ≈ −2.43 dB

    % ---- Eb/No de la simulación de recuperación de audio (RF4-Fase2) --------
    % 12 dB está en la zona de alta calidad para 16-QAM (BER ~ 10^-5 a 10^-6).
    params.EbNo_dB_audio       = 12;

    % Barrido de Eb/No para las curvas BER (mismo rango que Fase I).
    params.vector_EbNo_dB      = 0:1:14;  % [dB]

    % ---- Nombre del archivo de audio ----------------------------------------
    carpeta_audio = fullfile(fileparts(mfilename('fullpath')), 'Audio');
    params.ruta_audio_prueba   = fullfile(carpeta_audio, 'audio_prueba.wav');
    params.ruta_audio_recuperado = fullfile(carpeta_audio, 'audio_recuperado.wav');

    % =========================================================================
    %  VALIDACIONES
    % =========================================================================
    if params.bits_por_muestra < 1 || mod(params.bits_por_muestra, 1) ~= 0
        error('config_fase2: bits_por_muestra debe ser un entero >= 1.');
    end
    if params.fs_audio <= 0
        error('config_fase2: fs_audio debe ser positiva.');
    end
    if params.duracion_sweep_s > params.duracion_audio_min_s
        error('config_fase2: duracion_sweep_s no puede superar duracion_audio_min_s.');
    end
    if params.duracion_audio_min_s >= params.duracion_audio_max_s
        error('config_fase2: duracion_audio_min_s debe ser menor que duracion_audio_max_s.');
    end
    if params.tasa_codigo <= 0 || params.tasa_codigo >= 1
        error('config_fase2: la tasa del código debe estar en (0, 1).');
    end
    if ~any(abs(params.vector_EbNo_dB - params.EbNo_dB_audio) < 1e-9)
    warning('config_fase2: EbNo_dB_audio no está en el vector de barrido.');
    end

    % Verificar que el bitstream PCM sea múltiplo de 4 (para Hamming k=4).
    bits_pcm_sweep = params.N_muestras_sweep * params.bits_por_muestra;
    if mod(bits_pcm_sweep, params.hamming_k) ~= 0
        error('config_fase2: N_muestras_sweep × bits_por_muestra debe ser múltiplo de k_hamming=4.');
    end

    % Verificar que los bits codificados sean múltiplo de 4 (para 16-QAM k=4).
    bits_cod_sweep = bits_pcm_sweep * params.hamming_n / params.hamming_k;
    if mod(bits_cod_sweep, 4) ~= 0
        error('config_fase2: bits_codificados debe ser múltiplo de 4 (k_16QAM=4).');
    end

    % =========================================================================
    %  RESUMEN DE PARÁMETROS
    % =========================================================================
    fprintf('\n--- Configuración Fase II ---\n');
    fprintf('  Audio         : %.0f Hz, %d bits/muestra, min=%ds max=%ds\n', ...
        params.fs_audio, params.bits_por_muestra, ...
        params.duracion_audio_min_s, params.duracion_audio_max_s);
    fprintf('  Tasa fuente   : %.1f kbps\n', params.tasa_bits_fuente/1e3);
    fprintf('  Hamming(%d,%d) : r = 4/7 ≈ %.4f, penaliz. = %.2f dB\n', ...
        params.hamming_n, params.hamming_k, params.tasa_codigo, params.penalizacion_codigo_dB);
    fprintf('  Entrelazado   : %d | semilla sweep = %d | semilla full = %d\n', ...
        params.usar_entrelazado, params.semilla_entrelazado, params.semilla_entrelazado_full);
    fprintf('  Sweep BER     : %d s → %d bits PCM → %d bits codificados\n', ...
        params.duracion_sweep_s, bits_pcm_sweep, bits_cod_sweep);
    fprintf('  Eb/No audio   : %d dB (recuperación completa)\n', params.EbNo_dB_audio);
    fprintf('----------------------------\n\n');

end
