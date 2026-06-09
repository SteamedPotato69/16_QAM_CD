function params = config_sistema()
% =========================================================================
%  CONFIG_SISTEMA
%  ------------------------------------------------------------------------
%  Define y valida todos los parámetros del sistema 16-QAM sobre canal AWGN.
%  Centralizar los parámetros aquí permite modificar el sistema en un único
%  punto sin alterar ninguna función de procesamiento (RNF1, RNF5).
%
%  Salida:
%    params : struct con todos los parámetros del sistema validados.
% =========================================================================

    % ---- Modulación digital (RF1, RNF4) ------------------------------------
    params.orden_modulacion_M       = 16;
    params.bits_por_simbolo         = log2(params.orden_modulacion_M);  % k = 4

    % ---- Parámetros de tiempo y tasa ----------------------------------------
    params.tasa_simbolos_Rs         = 1;                 % [baudios] (normalizado)
    params.muestras_por_simbolo_sps = 8;                 % Sobremuestreo sps
    params.frecuencia_muestreo_fs   = params.tasa_simbolos_Rs * params.muestras_por_simbolo_sps;
    params.periodo_simbolo_Ts       = 1 / params.tasa_simbolos_Rs;

    % ---- Filtro coseno alzado raíz (RNF2, RNF3) -----------------------------
    % β controla la transición espectral: 0=mínimo ancho de banda, 1=máximo.
    % span=6 garantiza atenuación suficiente de colas fuera del intervalo ±6Ts.
    params.factor_roll_off_beta     = 0.35;
    params.span_filtro_simbolos     = 6;

    % ---- Frecuencia portadora (RF1) -----------------------------------------
    % Restricción de Nyquist: fc + B/2 < fs/2,
    % donde B = (1+β)·Rs → B/2 ≈ 0.675 para β=0.35, Rs=1.
    % Con fc=2·Rs=2 y fs=8: 2 + 0.675 = 2.675 < 4 ✓
    params.frecuencia_portadora_fc  = 2 * params.tasa_simbolos_Rs;

    % ---- Simulación (RF4, RF5) ----------------------------------------------
    params.numero_bits              = 1e5;
    % Garantizar múltiplo de k para que no queden bits huérfanos.
    params.numero_bits = params.bits_por_simbolo * ...
                         floor(params.numero_bits / params.bits_por_simbolo);
    params.vector_EbNo_dB           = 0:1:14;   % Rango de barrido Eb/No [dB]
    params.semilla_aleatoria        = 2026;      % Semilla fija (RNF5)

    % ---- Punto de Eb/No para visualización (RF6, RF7) -----------------------
    % Se elige un Eb/No intermedio donde la constelación y el ojo se aprecian
    % bien (ni tan ruidoso ni tan limpio).
    params.EbNo_dB_graficas         = 10;

    % =========================================================================
    %  VALIDACIONES — error() detiene la ejecución con un mensaje claro.
    % =========================================================================

    % El proyecto exige M-QAM o M-PSK con M > 4 (esquema bidimensional).
    if params.orden_modulacion_M <= 4
        error('config_sistema: M debe ser > 4 (modulación bidimensional, RNF4).');
    end
    if mod(log2(params.orden_modulacion_M), 1) ~= 0
        error('config_sistema: M debe ser una potencia de 2.');
    end
    if sqrt(params.orden_modulacion_M) ~= floor(sqrt(params.orden_modulacion_M))
        error('config_sistema: M debe ser un cuadrado perfecto para 16-QAM cuadrado.');
    end

    if params.factor_roll_off_beta < 0 || params.factor_roll_off_beta > 1
        error('config_sistema: beta debe estar en [0, 1].');
    end
    if params.muestras_por_simbolo_sps < 2
        error('config_sistema: sps debe ser >= 2.');
    end
    if params.span_filtro_simbolos < 1
        error('config_sistema: span debe ser un entero >= 1.');
    end

    % Criterio de Nyquist para el muestreo de la señal pasabanda.
    ancho_banda_unilateral = (1 + params.factor_roll_off_beta) * params.tasa_simbolos_Rs / 2;
    if params.frecuencia_portadora_fc + ancho_banda_unilateral >= params.frecuencia_muestreo_fs / 2
        error('config_sistema: fc + B/2 supera el límite de Nyquist (fs/2). Aumentar fs o reducir fc.');
    end

    % Verificar que el Eb/No para gráficas esté dentro del rango barrido.
    if ~any(abs(params.vector_EbNo_dB - params.EbNo_dB_graficas) < 1e-9)
        warning('config_sistema: EbNo_dB_graficas (%.1f dB) no está en el vector de barrido; se usará el punto medio del rango.', ...
            params.EbNo_dB_graficas);
        params.EbNo_dB_graficas = params.vector_EbNo_dB(round(length(params.vector_EbNo_dB)/2));
    end

end
