function [BER_simulada, BER_teorica] = ...
            calculo_ber(secuencia_bits_transmitidos, ...
                        secuencia_bits_recibidos,    ...
                        valor_EbNo_dB,               ...
                        orden_modulacion_M)
% =========================================================================
%  CALCULO_BER
%  ------------------------------------------------------------------------
%  Calcula:
%    1) BER simulada: contando errores bit a bit.
%    2) BER teórica para M-QAM cuadrado con codificación Gray.
%  Cumple RF4.
%
%  Fórmula teórica (M-QAM cuadrado con Gray):
%
%     BER ≈ (4/k) · (1 - 1/√M) · Q( sqrt( 3·k·Eb/No / (M-1) ) )
%
%  donde:
%     k = log2(M), Q(x) = 0.5·erfc(x/√2).
%
%  Para M=16, k=4 :
%     BER ≈ (3/4) · Q( sqrt(0.8 · Eb/No) )
%         = (3/8) · erfc( sqrt(0.4 · Eb/No) )
%
%  Entradas:
%    secuencia_bits_transmitidos : Bits originales.
%    secuencia_bits_recibidos    : Bits estimados por el receptor.
%    valor_EbNo_dB               : Eb/No en dB.
%    orden_modulacion_M          : M de la M-QAM.
%
%  Salidas:
%    BER_simulada : BER medida por conteo.
%    BER_teorica  : BER analítica para M-QAM cuadrado con Gray.
% =========================================================================

% ------------------------------------------------------------------
% 1) Alinear longitudes (por si la convolución dejó símbolos de cola).
% ------------------------------------------------------------------
numero_bits_validos = min(length(secuencia_bits_transmitidos), ...
                          length(secuencia_bits_recibidos));

bits_tx = secuencia_bits_transmitidos(1:numero_bits_validos);
bits_rx = secuencia_bits_recibidos(1:numero_bits_validos);

% ------------------------------------------------------------------
% 2) BER simulada por conteo.
% ------------------------------------------------------------------
numero_errores_bit = sum(bits_tx ~= bits_rx);
BER_simulada       = numero_errores_bit / numero_bits_validos;

% ------------------------------------------------------------------
% 3) BER teórica analítica.
% ------------------------------------------------------------------
bits_por_simbolo_k = log2(orden_modulacion_M);
EbNo_lineal        = 10^(valor_EbNo_dB/10);

% Q(x) = 0.5 · erfc(x / sqrt(2)).
funcion_Q = @(x) 0.5 * erfc(x / sqrt(2));

BER_teorica = (4/bits_por_simbolo_k) * (1 - 1/sqrt(orden_modulacion_M)) * ...
              funcion_Q( sqrt(3 * bits_por_simbolo_k * EbNo_lineal /        ...
                              (orden_modulacion_M - 1)) );

end
