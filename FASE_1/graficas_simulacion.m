function graficas_simulacion(vector_EbNo_dB,                       ...
                             vector_BER_simulada,                  ...
                             vector_BER_teorica,                   ...
                             simbolos_para_constelacion,           ...
                             senal_bb_rx_para_ojo,                 ...
                             senal_pasabanda_para_espectro,        ...
                             muestras_por_simbolo_sps,             ...
                             frecuencia_muestreo_fs,               ...
                             span_filtro_simbolos)
% =========================================================================
%  GRAFICAS_SIMULACION
%  ------------------------------------------------------------------------
%  Genera todas las figuras requeridas, sin usar funciones especiales
%  (eyediagram, scatterplot, pwelch...).  Cumple RF5, RF6, RF7 y RFN3.
%
%     Figura 1 : Curva BER vs Eb/No (simulada vs teórica)            (RF5)
%     Figura 2 : Constelación recibida (después del filtro acoplado) (RF6)
%     Figura 3 : Diagrama del ojo de las componentes I y Q           (RF6)
%     Figura 4 : Espectro de la señal pasabanda                      (RF7)
% =========================================================================

% =========================================================================
% FIGURA 1: Curva BER vs Eb/No.
% =========================================================================
figure('Name','BER vs Eb/No','NumberTitle','off');
semilogy(vector_EbNo_dB, vector_BER_teorica,  'b-',  'LineWidth', 1.6); hold on;
semilogy(vector_EbNo_dB, vector_BER_simulada, 'ro-', 'LineWidth', 1.2, ...
         'MarkerSize', 6, 'MarkerFaceColor','r');
grid on;
xlabel('E_b / N_0 [dB]');
ylabel('BER');
title('Probabilidad de error de bit (BER) — 16-QAM sobre canal AWGN');
legend('BER teórica','BER simulada','Location','southwest');
axis([min(vector_EbNo_dB) max(vector_EbNo_dB) 1e-6 1]);

% =========================================================================
% FIGURA 2: Constelación recibida.
% =========================================================================
% Se grafican los puntos I-Q después del filtro acoplado en el Rx.
figure('Name','Diagrama de constelación','NumberTitle','off');
plot(real(simbolos_para_constelacion), imag(simbolos_para_constelacion), ...
     '.', 'MarkerSize', 4); hold on;

% Se dibujan los 16 puntos ideales (rejilla {-3,-1,+1,+3}/sqrt(10)).
[I_ideal, Q_ideal] = meshgrid([-3 -1 1 3]/sqrt(10), [-3 -1 1 3]/sqrt(10));
plot(I_ideal(:), Q_ideal(:), 'rx', 'MarkerSize', 12, 'LineWidth', 2);

grid on; axis equal;
xlabel('Componente en fase (I)');
ylabel('Componente en cuadratura (Q)');
title('Constelación recibida tras filtro acoplado (Eb/No = 10 dB)');
legend('Símbolos recibidos','Puntos ideales','Location','northeastoutside');

% =========================================================================
% FIGURA 3: Diagrama del ojo (implementación manual).
% =========================================================================
% Se grafican N segmentos consecutivos de la señal banda base I (y Q) de
% duración 2·Tsymbol cada uno, superpuestos. Se descartan las muestras
% iniciales contaminadas por el transitorio del filtro acoplado.

retardo_transitorio_muestras    = 2 * span_filtro_simbolos * muestras_por_simbolo_sps;
muestras_en_dos_simbolos        = 2 * muestras_por_simbolo_sps;
numero_trazas_a_dibujar         = 200;       % Cantidad de trazas superpuestas.

% Se elige el inicio justo después del transitorio del filtro.
indice_inicio_ojo = retardo_transitorio_muestras + 1;
indice_fin_ojo    = indice_inicio_ojo + numero_trazas_a_dibujar*muestras_en_dos_simbolos - 1;

% Recorta dentro del rango válido (por si la señal es corta).
indice_fin_ojo = min(indice_fin_ojo, length(senal_bb_rx_para_ojo));
componente_I_ojo = real(senal_bb_rx_para_ojo(indice_inicio_ojo:indice_fin_ojo));
componente_Q_ojo = imag(senal_bb_rx_para_ojo(indice_inicio_ojo:indice_fin_ojo));

% Reorganiza en una matriz donde cada columna es una "traza" de 2·Tsymbol.
numero_trazas_real = floor(length(componente_I_ojo)/muestras_en_dos_simbolos);
matriz_ojo_I = reshape(componente_I_ojo(1:numero_trazas_real*muestras_en_dos_simbolos), ...
                       muestras_en_dos_simbolos, numero_trazas_real);
matriz_ojo_Q = reshape(componente_Q_ojo(1:numero_trazas_real*muestras_en_dos_simbolos), ...
                       muestras_en_dos_simbolos, numero_trazas_real);

% Eje horizontal de cada traza: -Tsymbol a +Tsymbol en tiempo normalizado.
eje_tiempo_ojo = ((0:muestras_en_dos_simbolos-1)/muestras_por_simbolo_sps) - 1;

figure('Name','Diagrama del ojo','NumberTitle','off');
subplot(2,1,1);
plot(eje_tiempo_ojo, matriz_ojo_I, 'b'); grid on;
xlabel('t / T_s'); ylabel('Amplitud');
title('Diagrama del ojo — Componente en fase (I)');
xlim([eje_tiempo_ojo(1) eje_tiempo_ojo(end)]);

subplot(2,1,2);
plot(eje_tiempo_ojo, matriz_ojo_Q, 'r'); grid on;
xlabel('t / T_s'); ylabel('Amplitud');
title('Diagrama del ojo — Componente en cuadratura (Q)');
xlim([eje_tiempo_ojo(1) eje_tiempo_ojo(end)]);

% =========================================================================
% FIGURA 4: Espectro de la señal pasabanda.
% =========================================================================
% Se usa la FFT directa (sin pwelch).  Se aplica una ventana Hann para
% reducir el "leaking" espectral.

numero_muestras_espectro = length(senal_pasabanda_para_espectro);
ventana_hann             = 0.5 - 0.5*cos(2*pi*(0:numero_muestras_espectro-1)/ ...
                                              (numero_muestras_espectro-1));

senal_ventaneada       = senal_pasabanda_para_espectro .* ventana_hann;
espectro_complejo      = fft(senal_ventaneada);
magnitud_espectro      = abs(espectro_complejo) / numero_muestras_espectro;

% Se muestra solo la parte positiva del espectro (señal real).
indices_positivos      = 1 : floor(numero_muestras_espectro/2);
eje_frecuencias_Hz     = (indices_positivos-1) * frecuencia_muestreo_fs ...
                          / numero_muestras_espectro;
magnitud_dB            = 20*log10(magnitud_espectro(indices_positivos) + eps);

figure('Name','Espectro de la señal pasabanda','NumberTitle','off');
plot(eje_frecuencias_Hz, magnitud_dB, 'LineWidth', 1.0); grid on;
xlabel('Frecuencia (normalizada a R_s)');
ylabel('|S(f)| (dB)');
title('Espectro de la señal pasabanda (sin ruido, ventana Hann)');
xlim([0 frecuencia_muestreo_fs/2]);

end
