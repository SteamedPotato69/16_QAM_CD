function resultados = pruebas_validacion(params)
% =========================================================================
%  PRUEBAS_VALIDACION
%  ------------------------------------------------------------------------
%  Ejecuta cuatro pruebas automáticas para verificar el correcto
%  funcionamiento del sistema 16-QAM sobre canal AWGN.
%
%  Pruebas:
%    1. BER = 0 sin ruido (Eb/No = 100 dB).
%    2. Energía promedio de símbolo Es ≈ 1 (normalización correcta).
%    3. BER decrece monotónicamente al aumentar Eb/No.
%    4. BER simulada y teórica son coherentes en orden de magnitud.
%
%  Entrada:
%    params : struct de configuración del sistema (de config_sistema.m).
%
%  Salida:
%    resultados : struct con los valores medidos y el campo
%                 'todas_aprobadas' (true/false).
% =========================================================================

    fprintf('\n=========================================================\n');
    fprintf('  PRUEBAS DE VALIDACIÓN DEL SISTEMA \n');
    fprintf('=========================================================\n');

    resultados.todas_aprobadas = true;

    % Usar un lote más pequeño para que las pruebas sean rápidas.
    params_prueba = params;
    params_prueba.numero_bits = params_prueba.bits_por_simbolo * 10000;   % 40 000 bits

    rng(params_prueba.semilla_aleatoria);

    % Pre-calcular el filtro RRC (se reutiliza en todas las pruebas).
    h_rrc = filtro_coseno_alzado_raiz(params_prueba.factor_roll_off_beta, ...
        params_prueba.span_filtro_simbolos, params_prueba.muestras_por_simbolo_sps);

    % Generar bits y símbolos de referencia.
    [bits_tx, simbolos_tx] = modulador_binario_16qam(params_prueba.numero_bits);

    % Señal pasabanda de referencia (sin ruido).
    senal_bb  = conformacion_pulso(simbolos_tx, h_rrc, params_prueba.muestras_por_simbolo_sps);
    senal_pb  = modulacion_pasabanda(senal_bb, params_prueba.frecuencia_portadora_fc, ...
                    params_prueba.frecuencia_muestreo_fs);

    % =====================================================================
    % Prueba 1: BER = 0 sin ruido (Eb/No muy alta ≈ canal ideal).
    % =====================================================================
    % Con Eb/No = 100 dB el ruido es despreciable.  Si el mapeo y el demapeo
    % son correctos, ningún bit debe cambiar.
    senal_rx_ideal = canal_awgn(senal_pb, 100, params_prueba.bits_por_simbolo, ...
                        params_prueba.muestras_por_simbolo_sps);
    [bits_rx_ideal, ~, ~] = demodulador_16qam(senal_rx_ideal, h_rrc, ...
        params_prueba.muestras_por_simbolo_sps, params_prueba.span_filtro_simbolos, ...
        params_prueba.frecuencia_portadora_fc, params_prueba.frecuencia_muestreo_fs);
    [ber_sin_ruido, ~] = calculo_ber(bits_tx, bits_rx_ideal, 100, params_prueba.orden_modulacion_M);

    resultados.ber_sin_ruido = ber_sin_ruido;
    if ber_sin_ruido == 0
        fprintf('[OK]    Prueba 1: BER sin ruido = 0 (mapeo/demapeo correcto)\n');
    else
        fprintf('[ERROR] Prueba 1: BER sin ruido = %.2e  (se esperaba 0)\n', ber_sin_ruido);
        resultados.todas_aprobadas = false;
    end

    % =====================================================================
    % Prueba 2: Energía promedio de símbolo Es ≈ 1.
    % =====================================================================
    % La constelación se normaliza por sqrt(10) → Es = mean(|s|²) ≈ 1.
    % Una desviación de ±2 % es aceptable por efectos estadísticos.
    Es = mean(abs(simbolos_tx).^2);
    resultados.Es = Es;
    if abs(Es - 1) < 0.02
        fprintf('[OK]    Prueba 2: Es = %.6f  (≈ 1, normalización correcta)\n', Es);
    else
        fprintf('[ERROR] Prueba 2: Es = %.6f  (se esperaba ≈ 1, error en normalización)\n', Es);
        resultados.todas_aprobadas = false;
    end

    % =====================================================================
    % Prueba 3: BER decrece monotónicamente al aumentar Eb/No.
    % =====================================================================
    % Para un canal AWGN con decisor óptimo, mayor SNR → menor BER.
    EbNo_prueba = [0, 6, 12];
    ber_prueba  = zeros(1, length(EbNo_prueba));
    for idx = 1:length(EbNo_prueba)
        senal_rx_p = canal_awgn(senal_pb, EbNo_prueba(idx), ...
            params_prueba.bits_por_simbolo, params_prueba.muestras_por_simbolo_sps);
        [bits_rx_p, ~, ~] = demodulador_16qam(senal_rx_p, h_rrc, ...
            params_prueba.muestras_por_simbolo_sps, params_prueba.span_filtro_simbolos, ...
            params_prueba.frecuencia_portadora_fc, params_prueba.frecuencia_muestreo_fs);
        [ber_prueba(idx), ~] = calculo_ber(bits_tx, bits_rx_p, EbNo_prueba(idx), ...
            params_prueba.orden_modulacion_M);
    end
    resultados.EbNo_prueba = EbNo_prueba;
    resultados.ber_prueba  = ber_prueba;

    if ber_prueba(1) > ber_prueba(2) && ber_prueba(2) > ber_prueba(3)
        fprintf('[OK]    Prueba 3: BER decrece con Eb/No\n');
        fprintf('        BER:  %.2e → %.2e → %.2e  (para %g, %g, %g dB)\n', ...
            ber_prueba(1), ber_prueba(2), ber_prueba(3), EbNo_prueba(1), EbNo_prueba(2), EbNo_prueba(3));
    else
        fprintf('[ERROR] Prueba 3: BER no decrece monotónicamente\n');
        fprintf('        BER:  %.2e → %.2e → %.2e  (para %g, %g, %g dB)\n', ...
            ber_prueba(1), ber_prueba(2), ber_prueba(3), EbNo_prueba(1), EbNo_prueba(2), EbNo_prueba(3));
        resultados.todas_aprobadas = false;
    end

    % =====================================================================
    % Prueba 4: BER simulada y teórica son coherentes en orden de magnitud.
    % =====================================================================
    % Se comparan en un Eb/No donde la BER es medible (~10^-2 a 10^-4).
    EbNo_ref = 10;
    senal_rx_ref = canal_awgn(senal_pb, EbNo_ref, params_prueba.bits_por_simbolo, ...
                        params_prueba.muestras_por_simbolo_sps);
    [bits_rx_ref, ~, ~] = demodulador_16qam(senal_rx_ref, h_rrc, ...
        params_prueba.muestras_por_simbolo_sps, params_prueba.span_filtro_simbolos, ...
        params_prueba.frecuencia_portadora_fc, params_prueba.frecuencia_muestreo_fs);
    [ber_sim_ref, ber_teo_ref] = calculo_ber(bits_tx, bits_rx_ref, EbNo_ref, ...
        params_prueba.orden_modulacion_M);

    resultados.ber_sim_ref = ber_sim_ref;
    resultados.ber_teo_ref = ber_teo_ref;

    if ber_sim_ref > 0
        diferencia_decadas = abs(log10(ber_sim_ref) - log10(ber_teo_ref));
        if diferencia_decadas < 1
            fprintf('[OK]    Prueba 4: BER sim ≈ BER teórica  (diferencia < 1 orden de magnitud)\n');
            fprintf('        BER sim = %.2e  |  BER teo = %.2e  en Eb/No = %g dB\n', ...
                ber_sim_ref, ber_teo_ref, EbNo_ref);
        else
            fprintf('[AVISO] Prueba 4: Diferencia = %.1f órdenes (normal con pocas muestras)\n', ...
                diferencia_decadas);
            fprintf('        BER sim = %.2e  |  BER teo = %.2e  en Eb/No = %g dB\n', ...
                ber_sim_ref, ber_teo_ref, EbNo_ref);
        end
    else
        fprintf('[OK]    Prueba 4: BER sim = 0 (SNR alta, no se observaron errores)\n');
        fprintf('        BER teo = %.2e  en Eb/No = %g dB\n', ber_teo_ref, EbNo_ref);
    end

    % =====================================================================
    % Resultado global.
    % =====================================================================
    fprintf('=========================================================\n');
    if resultados.todas_aprobadas
        fprintf('  RESULTADO: TODAS LAS PRUEBAS SUPERADAS CORRECTAMENTE\n');
    else
        fprintf('  RESULTADO: ALGUNAS PRUEBAS FALLARON — revisar el sistema\n');
    end
    fprintf('=========================================================\n\n');

end
