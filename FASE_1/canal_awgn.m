function senal_pasabanda_con_ruido = ...
            canal_awgn(senal_pasabanda_transmitida, ...
                       valor_EbNo_dB,               ...
                       bits_por_simbolo,            ...
                       muestras_por_simbolo_sps)
% =========================================================================
%  CANAL_AWGN
%  ------------------------------------------------------------------------
%  Modela un canal Aditivo, Blanco, Gaussiano (AWGN) que suma ruido a la
%  señal pasabanda real.  Cumple RF2.
%
%  Derivación de la varianza del ruido a partir de Eb/No:
%  ------------------------------------------------------
%  Definiciones (señal pasabanda REAL):
%      Ps  = potencia promedio de la señal pasabanda  = mean(s_pb^2)
%      Tb  = periodo de bit            = 1/(Rs·k)
%      Eb  = energía de bit            = Ps · Tb        = Ps / (Rs·k)
%      No  = densidad espectral de ruido (un solo lado)
%      σ²  = varianza del ruido muestreado a fs        = No · fs / 2
%            (PSD bilateral No/2 integrada en [-fs/2, fs/2] = No·fs/2)
%
%  De Eb/No = Ps / (Rs · k · No)  se despeja No y se sustituye en σ²:
%      σ² = Ps · sps / (2 · k · (Eb/No)_lin)
%
%  donde se usó fs/Rs = sps.
%
%  Entradas:
%    senal_pasabanda_transmitida : Señal real a contaminar.
%    valor_EbNo_dB               : Relación Eb/No en dB.
%    bits_por_simbolo            : k = log2(M).
%    muestras_por_simbolo_sps    : sps = fs/Rs.
%
%  Salida:
%    senal_pasabanda_con_ruido   : Señal + ruido AWGN.
% =========================================================================

% ------------------------------------------------------------------
% 1) Potencia promedio de la señal a la entrada del canal.
% ------------------------------------------------------------------
potencia_promedio_senal = mean(senal_pasabanda_transmitida.^2);

% ------------------------------------------------------------------
% 2) Conversión de Eb/No de dB a lineal.
% ------------------------------------------------------------------
valor_EbNo_lineal = 10^(valor_EbNo_dB/10);

% ------------------------------------------------------------------
% 3) Varianza del ruido AWGN (real) que hay que sumar.
% ------------------------------------------------------------------
% σ² = Ps · sps / (2 · k · (Eb/No)_lin)
varianza_ruido_awgn = potencia_promedio_senal * muestras_por_simbolo_sps ...
                      / (2 * bits_por_simbolo * valor_EbNo_lineal);

% Desviación estándar del ruido (sqrt(varianza)).
desviacion_estandar_ruido = sqrt(varianza_ruido_awgn);

% ------------------------------------------------------------------
% 4) Generación del ruido y suma a la señal.
% ------------------------------------------------------------------
% randn produce muestras Normal(0,1).  Se escalan por σ.
% El ruido es REAL porque la señal pasabanda es REAL.
ruido_gaussiano_real = desviacion_estandar_ruido * ...
                       randn(1, length(senal_pasabanda_transmitida));

senal_pasabanda_con_ruido = senal_pasabanda_transmitida + ruido_gaussiano_real;

end
