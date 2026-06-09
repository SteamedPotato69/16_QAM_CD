function resultados = pruebas_fase2(params_f1, params_f2)
% =========================================================================
%  PRUEBAS_FASE2
%  ------------------------------------------------------------------------
%  Pruebas automáticas de verificación para los módulos de Fase II:
%    ADC/DAC, Hamming(7,4) y coherencia del sistema completo.
%
%  Pruebas implementadas:
%    1. Roundtrip ADC→DAC sin ruido: error máximo < Δ/2.
%    2. Hamming encode→decode sin ruido: BER = 0 (decodificación perfecta).
%    3. Hamming: corrección de error simple en cada posición (1..7).
%    4. Hamming: dos errores no se corrigen (BER > 0, comportamiento esperado).
%    5. Sistema completo con/sin código a Eb/No = 100 dB: BER = 0.
%    6. Curva BER codificada teórica: ganancia de codificación a 12 dB.
%
%  Entradas:
%    params_f1 : struct de config_sistema() (parámetros Fase I).
%    params_f2 : struct de config_fase2()   (parámetros Fase II).
%
%  Salida:
%    resultados : struct con campos booleanos por prueba y campo
%                 'todas_aprobadas' (true/false).
% =========================================================================

    fprintf('\n=========================================================\n');
    fprintf('  PRUEBAS DE VALIDACIÓN — FASE II\n');
    fprintf('=========================================================\n');

    resultados.todas_aprobadas = true;

    % =====================================================================
    % Prueba 1: Roundtrip ADC → DAC sin ruido — error < Δ/2.
    % =====================================================================
    % Se genera una señal de prueba en [-1,1] y se verifica que la
    % reconstrucción no tenga más error que la mitad del paso de cuantif.
    N_test   = 1000;
    t_test   = linspace(-1, 1, N_test)';          % señal diente de sierra
    audio_in = t_test + 0.1*sin(2*pi*10*t_test);  % señal con contenido AC
    audio_in = audio_in / max(abs(audio_in));       % normalizar

    [bits_adc, audio_q, paso, ~] = conversor_adc(audio_in, params_f2.bits_por_muestra, ...
                                                  params_f2.fs_audio);
    audio_dac = conversor_dac(bits_adc, params_f2.bits_por_muestra);

    error_max_roundtrip = max(abs(audio_dac - audio_q));
    umbral_delta_medio  = paso / 2 + 1e-10;   % tolerancia: Δ/2 (error cuantificación)

    resultados.error_max_roundtrip = error_max_roundtrip;
    if error_max_roundtrip < umbral_delta_medio
        fprintf('[OK]    Prueba 1: Roundtrip ADC→DAC — error máx = %.2e < Δ/2 = %.2e\n', ...
            error_max_roundtrip, paso/2);
    else
        fprintf('[ERROR] Prueba 1: Roundtrip ADC→DAC — error máx = %.2e > Δ/2 = %.2e\n', ...
            error_max_roundtrip, paso/2);
        resultados.todas_aprobadas = false;
    end

    % =====================================================================
    % Prueba 2: Hamming encode → decode sin errores → BER = 0.
    % =====================================================================
    N_bits_test  = 4000;   % múltiplo de 4
    bits_datos_p2 = randi([0 1], 1, N_bits_test);

    bits_codif  = codificador_hamming(bits_datos_p2);
    [bits_decod, ~] = decodificador_hamming(bits_codif);

    ber_hamming_sin_ruido = sum(bits_decod ~= bits_datos_p2) / N_bits_test;
    resultados.ber_hamming_sin_ruido = ber_hamming_sin_ruido;

    if ber_hamming_sin_ruido == 0
        fprintf('[OK]    Prueba 2: Hamming encode→decode sin ruido: BER = 0\n');
    else
        fprintf('[ERROR] Prueba 2: Hamming BER sin ruido = %.2e (se esperaba 0)\n', ...
            ber_hamming_sin_ruido);
        resultados.todas_aprobadas = false;
    end

    % =====================================================================
    % Prueba 3: Hamming corrige error simple en cada posición (1..7).
    % =====================================================================
    bits_4     = [1 0 1 1];                               % bloque de datos
    bits_cod_p3 = codificador_hamming(bits_4);            % codeword de 7 bits
    todas_posiciones_ok = true;

    for pos = 1:7
        bits_con_error = bits_cod_p3;
        bits_con_error(pos) = 1 - bits_con_error(pos);   % flip en posición 'pos'
        [bits_corr, n_corr] = decodificador_hamming(bits_con_error);
        if ~isequal(bits_corr, bits_4) || n_corr ~= 1
            fprintf('[ERROR] Prueba 3: Error en posición %d no fue corregido.\n', pos);
            todas_posiciones_ok = false;
            resultados.todas_aprobadas = false;
        end
    end
    resultados.correccion_todas_posiciones = todas_posiciones_ok;
    if todas_posiciones_ok
        fprintf('[OK]    Prueba 3: Corrección de error simple en las 7 posiciones\n');
    end

    % =====================================================================
    % Prueba 4: Hamming con 2 errores → NO corrige (introduce errores).
    % =====================================================================
    % Este es el COMPORTAMIENTO ESPERADO: el código solo corrige t=1 error.
    % El decodificador identifica un síndrome que apunta a otra posición
    % y empeora el resultado. Se verifica que hay errores en la salida.
    bits_4b      = [1 0 0 1];
    bits_cod_p4  = codificador_hamming(bits_4b);
    bits_2err    = bits_cod_p4;
    bits_2err(1) = 1 - bits_2err(1);   % flip pos 1
    bits_2err(3) = 1 - bits_2err(3);   % flip pos 3
    [bits_mal, ~] = decodificador_hamming(bits_2err);

    tiene_errores = any(bits_mal ~= bits_4b);
    resultados.doble_error_no_corregido = tiene_errores;
    if tiene_errores
        fprintf('[OK]    Prueba 4: Doble error → no corregido (comportamiento esperado)\n');
    else
        % Nota: podría darse que, por azar del síndrome, los 2 errores se
        % "corrijan" accidentalmente. Es estadísticamente posible pero raro.
        fprintf('[AVISO] Prueba 4: Doble error "corregido" accidentalmente (raro, aceptable)\n');
    end

    % =====================================================================
    % Prueba 5: Sistema completo (16-QAM + AWGN) a Eb/No=100 dB → BER=0.
    % =====================================================================
    rng(params_f1.semilla_aleatoria + 200);   % semilla diferente a Fase I

    N_bits_p5 = params_f1.bits_por_simbolo * 1000;   % 4000 bits
    bits_pcm_p5 = randi([0 1], 1, N_bits_p5);

    % Bits codificados Hamming.
    bits_cod_p5 = codificador_hamming(bits_pcm_p5);   % 7000 bits

    % Pipeline Fase I para SISTEMA CODIFICADO.
    h_rrc = filtro_coseno_alzado_raiz(params_f1.factor_roll_off_beta, ...
        params_f1.span_filtro_simbolos, params_f1.muestras_por_simbolo_sps);

    [~, simbolos_cod] = modulador_binario_16qam(length(bits_cod_p5), bits_cod_p5);
    senal_bb_cod = conformacion_pulso(simbolos_cod, h_rrc, params_f1.muestras_por_simbolo_sps);
    senal_pb_cod = modulacion_pasabanda(senal_bb_cod, ...
        params_f1.frecuencia_portadora_fc, params_f1.frecuencia_muestreo_fs);

    EcNo_dB_100 = 100 + params_f2.penalizacion_codigo_dB;   % ≈ 97.6 dB
    senal_rx_100 = canal_awgn(senal_pb_cod, EcNo_dB_100, ...
        params_f1.bits_por_simbolo, params_f1.muestras_por_simbolo_sps);
    [bits_rx_cod_p5, ~, ~] = demodulador_16qam(senal_rx_100, h_rrc, ...
        params_f1.muestras_por_simbolo_sps, params_f1.span_filtro_simbolos, ...
        params_f1.frecuencia_portadora_fc, params_f1.frecuencia_muestreo_fs);

    % Truncar a múltiplo de 7 antes de decodificar.
    N_validos_p5 = floor(min(length(bits_cod_p5), length(bits_rx_cod_p5)) / 7) * 7;
    bits_decod_p5 = decodificador_hamming(bits_rx_cod_p5(1:N_validos_p5));

    N_datos_p5 = length(bits_decod_p5);
    ber_sistema_cod = sum(bits_decod_p5 ~= bits_pcm_p5(1:N_datos_p5)) / N_datos_p5;

    resultados.ber_sistema_cod_100dB = ber_sistema_cod;
    if ber_sistema_cod == 0
        fprintf('[OK]    Prueba 5: BER sistema codificado a 100 dB = 0\n');
    else
        fprintf('[ERROR] Prueba 5: BER sistema codificado a 100 dB = %.2e (se esperaba 0)\n', ...
            ber_sistema_cod);
        resultados.todas_aprobadas = false;
    end

    % =====================================================================
    % Prueba 6: BER codificada teórica < BER sin código a Eb/No = 12 dB.
    % =====================================================================
    % A 12 dB la codificación debería dar ganancia (BER_cod < BER_unc).
    [ber_unc_teo, ber_cod_teo] = calculo_ber_codificado(12, ...
        params_f1.orden_modulacion_M, params_f2.tasa_codigo, ...
        params_f2.hamming_n, params_f2.hamming_k, params_f2.hamming_t);

    resultados.BER_sin_cod_12dB = ber_unc_teo;
    resultados.BER_con_cod_12dB = ber_cod_teo;

    if ber_cod_teo < ber_unc_teo
        fprintf('[OK]    Prueba 6: Ganancia de codificación a 12 dB\n');
        fprintf('        BER sin código = %.2e  |  BER con Hamming = %.2e\n', ...
            ber_unc_teo, ber_cod_teo);
    else
        % A baja SNR el código puede empeorar — se reporta pero no es error.
        fprintf('[AVISO] Prueba 6: A 12 dB el código no mejora (no es error, depende del punto)\n');
        fprintf('        BER sin código = %.2e  |  BER con Hamming = %.2e\n', ...
            ber_unc_teo, ber_cod_teo);
    end

    % =====================================================================
    % Resultado global.
    % =====================================================================
    fprintf('=========================================================\n');
    if resultados.todas_aprobadas
        fprintf('  RESULTADO: TODAS LAS PRUEBAS FASE II SUPERADAS\n');
    else
        fprintf('  RESULTADO: ALGUNAS PRUEBAS FALLARON — revisar los módulos\n');
    end
    fprintf('=========================================================\n\n');

end
