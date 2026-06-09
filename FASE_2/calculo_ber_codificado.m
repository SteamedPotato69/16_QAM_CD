function [BER_sin_cod, BER_con_cod] = calculo_ber_codificado(vector_EbNo_dB, M, r_codigo, n_codigo, k_codigo, t_codigo)
% =========================================================================
%  CALCULO_BER_CODIFICADO
%  ------------------------------------------------------------------------
%  Calcula las curvas de BER teóricas para:
%    (a) Sistema 16-QAM sin codificación de canal.
%    (b) Sistema 16-QAM con código de bloque Hamming(n,k,t) — decodificación
%        por umbral de hard-decision.
%
%  Fórmulas derivadas desde primeros principios:
%  ─────────────────────────────────────────────────────────────────────
%  (a) BER sin codificación (16-QAM cuadrado, Gray):
%
%      BER_unc(Eb/N0) = (4/k)·(1 − 1/√M)·Q(√(3k·Eb/N0/(M−1)))
%
%      Para M=16, k=4:  BER_unc = (3/4)·Q(√(0.8·Eb/N0))
%
%  (b) BER con código Hamming(n,k,t) — tasa r = k/n:
%
%    Paso 1 — Energía por bit de canal:
%               Ec/N0 = r · Eb/N0
%    Paso 2 — BER del canal (bits codificados antes de decodificar):
%               p = BER_unc(Ec/N0)
%    Paso 3 — Probabilidad de que un codeword tenga >= t+1 errores
%             (no corregible → empeora):
%               P(error_w) = sum_{j=t+1}^{n} C(n,j)·p^j·(1-p)^(n-j)
%    Paso 4 — BER aproximada de los datos decodificados:
%               BER_cod ≈ (1/k)·sum_{j=t+1}^{n} j·C(n,j)·p^j·(1-p)^(n-j)
%             (ponderación por número de bits erróneos en el bloque)
%
%  Nota: esta fórmula es una COTA SUPERIOR aproximada.  La BER real puede
%  ser ligeramente inferior porque la distribución de errores dentro del
%  bloque puede variar.
%
%  Para Hamming(7,4): r=4/7, n=7, k=4, t=1.
%    BER_cod ≈ (1/4)·Σ_{j=2}^{7} j·C(7,j)·p^j·(1−p)^(7−j)
%
%  Ganancia de codificación:
%    Para BER < ~10^−2 el código MEJORA la BER respecto al sin código.
%    Para BER > ~10^−2 el código EMPEORA (la penalización de tasa domina).
%
%  Entradas:
%    vector_EbNo_dB : Vector de Eb/N0 en dB (por bit de datos).
%    M              : Orden de la modulación (16 para 16-QAM).
%    r_codigo       : Tasa del código = k_codigo/n_codigo.
%    n_codigo       : Longitud de la palabra código (n=7).
%    k_codigo       : Bits de datos por codeword (k=4).
%    t_codigo       : Capacidad de corrección (t=1).
%
%  Salidas:
%    BER_sin_cod : Vector BER teórica sin codificación.
%    BER_con_cod : Vector BER teórica con codificación Hamming.
% =========================================================================

% ------------------------------------------------------------------
% 0) Validaciones.
% ------------------------------------------------------------------
if mod(log2(M), 1) ~= 0
    error('calculo_ber_codificado: M debe ser potencia de 2.');
end
if sqrt(M) ~= floor(sqrt(M))
    error('calculo_ber_codificado: M debe ser cuadrado perfecto (QAM cuadrado).');
end
if r_codigo <= 0 || r_codigo >= 1
    error('calculo_ber_codificado: r_codigo debe estar en (0,1).');
end
if n_codigo <= k_codigo
    error('calculo_ber_codificado: n_codigo debe ser > k_codigo.');
end
if t_codigo < 1
    error('calculo_ber_codificado: t_codigo debe ser >= 1.');
end

% ------------------------------------------------------------------
% 1) Parámetros derivados.
% ------------------------------------------------------------------
k        = log2(M);                            % bits/símbolo 16-QAM
EbNo_lin = 10.^(vector_EbNo_dB / 10);         % Eb/N0 lineal (vector)
funcion_Q = @(x) 0.5 * erfc(x / sqrt(2));

% ------------------------------------------------------------------
% 2) BER sin codificación.
%    BER_unc = (4/k)·(1−1/√M)·Q(√(3k·Eb/N0/(M-1)))
% ------------------------------------------------------------------
argumento_Q = sqrt(3 * k * EbNo_lin / (M - 1));
BER_sin_cod = (4/k) * (1 - 1/sqrt(M)) * funcion_Q(argumento_Q);

% ------------------------------------------------------------------
% 3) BER del canal para el sistema codificado.
%    Ec/N0 = r·Eb/N0  (cada bit de canal lleva fracción r de la energía)
% ------------------------------------------------------------------
EcNo_lin = r_codigo * EbNo_lin;
argumento_Q_cod = sqrt(3 * k * EcNo_lin / (M - 1));
p_canal = (4/k) * (1 - 1/sqrt(M)) * funcion_Q(argumento_Q_cod);

% ------------------------------------------------------------------
% 4) BER después de decodificación Hamming(n,k,t).
%    BER_cod ≈ (1/k)·Σ_{j=t+1}^{n} j·C(n,j)·p^j·(1-p)^(n-j)
% ------------------------------------------------------------------
BER_con_cod = zeros(size(vector_EbNo_dB));

for idx = 1:length(vector_EbNo_dB)
    p = p_canal(idx);

    suma_ponderada = 0;
    for j = t_codigo + 1 : n_codigo
        % C(n,j)·p^j·(1-p)^(n-j) — combinatoria con doble precisión.
        % Para BER muy pequeñas, p^j puede underflow → usar log si necesario.
        term_binom = nchoosek(n_codigo, j) * (p^j) * ((1-p)^(n_codigo-j));
        suma_ponderada = suma_ponderada + j * term_binom;
    end

    BER_con_cod(idx) = suma_ponderada / k_codigo;
end

end
