function graficas_fase2(vector_EbNo_dB,    ...
                        BER_sim_sin_cod,   ...
                        BER_teo_sin_cod,   ...
                        BER_sim_con_cod,   ...
                        BER_teo_con_cod,   ...
                        audio_original,    ...
                        audio_recuperado,  ...
                        fs_audio,          ...
                        EbNo_dB_audio,     ...
                        bits_por_muestra)
% =========================================================================
%  GRAFICAS_FASE2
%  ------------------------------------------------------------------------
%  Genera las figuras de la Fase II:
%
%    Figura 1 — Curvas BER comparativas (4 curvas):
%      · BER teórica sin codificación  (línea continua azul)
%      · BER simulada sin codificación (marcadores azules)
%      · BER teórica con Hamming(7,4)  (línea continua roja)
%      · BER simulada con Hamming(7,4) (marcadores rojos)
%      Eje Y logarítmico.  Referencia Shannon (capacidad de canal).
%
%    Figura 2 — Comparación de audio original vs recuperado:
%      · Forma de onda: original (azul) y recuperado (naranja superpuesto)
%      · Espectro de potencia (FFT con ventana Hann): original vs recuperado
%
%  NO usa funciones prohibidas: no pwelch, no scatterplot, no eyediagram.
%
%  Entradas:
%    vector_EbNo_dB   : Vector Eb/No en dB (eje X de curvas BER).
%    BER_sim_sin_cod  : BER simulada sin codificación (vector).
%    BER_teo_sin_cod  : BER teórica sin codificación  (vector).
%    BER_sim_con_cod  : BER simulada con Hamming(7,4) (vector).
%    BER_teo_con_cod  : BER teórica con Hamming(7,4)  (vector).
%    audio_original   : Vector de muestras de audio original.
%    audio_recuperado : Vector de muestras de audio recuperado.
%    fs_audio         : Frecuencia de muestreo del audio [Hz].
%    EbNo_dB_audio    : Eb/No usado para la recuperación [dB].
%    bits_por_muestra : Resolución B del ADC/DAC [bits].
% =========================================================================

% =========================================================================
%  FIGURA 1: Curvas BER comparativas
% =========================================================================
figure('Name', 'Fase II — Curvas BER Comparativas', 'NumberTitle', 'off', ...
       'Position', [50 100 820 560]);

% Reemplazar BER=0 por un valor mínimo para escala logarítmica.
% Se usa 1/(2*N_bits) como piso (no se observaron errores en N_bits muestras).
piso_log = 1e-7;

BER_sim_sc_plot = max(BER_sim_sin_cod, piso_log);
BER_sim_cc_plot = max(BER_sim_con_cod, piso_log);

% ---- Curvas teóricas (líneas sólidas) -----------------------------------
semilogy(vector_EbNo_dB, BER_teo_sin_cod, 'b-',  'LineWidth', 2.0); hold on;
semilogy(vector_EbNo_dB, BER_teo_con_cod, 'r-',  'LineWidth', 2.0);

% ---- Curvas simuladas (marcadores) --------------------------------------
semilogy(vector_EbNo_dB, BER_sim_sc_plot, 'bs', ...
    'MarkerSize', 8, 'MarkerFaceColor', 'b', 'LineWidth', 1.2);
semilogy(vector_EbNo_dB, BER_sim_cc_plot, 'ro', ...
    'MarkerSize', 8, 'MarkerFaceColor', 'r', 'LineWidth', 1.2);

% ---- Línea de referencia BER = 10^-3 ------------------------------------
yline(1e-3, 'k--', 'BER = 10^{-3}', 'LabelVerticalAlignment', 'bottom', ...
    'LineWidth', 1.0, 'FontSize', 10);

% ---- Marcadores de BER=0 (triángulos hacia abajo en el piso) ------------
idx_cero_sc = find(BER_sim_sin_cod == 0);
if ~isempty(idx_cero_sc)
    semilogy(vector_EbNo_dB(idx_cero_sc), repmat(piso_log*2, size(idx_cero_sc)), ...
        'bv', 'MarkerSize', 9, 'MarkerFaceColor', 'b', 'DisplayName', 'BER = 0 (sin cod.)');
end
idx_cero_cc = find(BER_sim_con_cod == 0);
if ~isempty(idx_cero_cc)
    semilogy(vector_EbNo_dB(idx_cero_cc), repmat(piso_log*2, size(idx_cero_cc)), ...
        'rv', 'MarkerSize', 9, 'MarkerFaceColor', 'r', 'DisplayName', 'BER = 0 (con cod.)');
end

% ---- Formato del gráfico ------------------------------------------------
grid on; grid minor;
ylim([piso_log 1]);
xlim([min(vector_EbNo_dB) max(vector_EbNo_dB)]);
xlabel('E_b/N_0  [dB]',          'FontSize', 13, 'FontWeight', 'bold');
ylabel('BER (Tasa de Error de Bit)', 'FontSize', 13, 'FontWeight', 'bold');
title({'Fase II — Desempeño BER: 16-QAM con y sin Código Hamming(7,4)'; ...
       'Modulación 16-QAM, fuente de audio PCM 16 bits, β=0.35'}, ...
    'FontSize', 12);
legend({'Sin cod. — teórica', ...
        'Con Hamming(7,4) — teórica', ...
        'Sin cod. — simulada (audio PCM)', ...
        'Con Hamming(7,4) — simulada'}, ...
    'Location', 'southwest', 'FontSize', 10);

% Nota textual sobre la penalización de tasa.
texto_nota = sprintf('Hamming(7,4): r=4/7, penalización=−2.43 dB\nGanancia de codificación a E_b/N_0 alto');
text(0.02, 0.04, texto_nota, 'Units','normalized', 'FontSize', 9, ...
    'BackgroundColor', [1 1 0.8], 'EdgeColor', 'k');

hold off;

% =========================================================================
%  FIGURA 2: Comparación de audio
% =========================================================================
N_audio_orig  = length(audio_original);
N_audio_recup = length(audio_recuperado);
N_comparar    = min(N_audio_orig, N_audio_recup);

t_audio = (0:N_comparar-1)' / fs_audio;   % eje temporal [s]

% Limitar a los primeros 0.05 s para visualización clara de la forma de onda.
N_vis   = min(N_comparar, round(0.05 * fs_audio));
t_vis   = t_audio(1:N_vis);

figure('Name', 'Fase II — Comparación de Audio', 'NumberTitle', 'off', ...
       'Position', [900 100 820 560]);

% ---- Subplot 1: Formas de onda ------------------------------------------
subplot(2, 1, 1);
plot(t_vis, audio_original(1:N_vis),    'b-', 'LineWidth', 1.2); hold on;
plot(t_vis, audio_recuperado(1:N_vis),  'r--', 'LineWidth', 1.2);
hold off;
xlabel('Tiempo [s]', 'FontSize', 11);
ylabel('Amplitud normalizada', 'FontSize', 11);
title(sprintf('Forma de onda — Primeros %.0f ms  (E_b/N_0 = %d dB)', ...
    N_vis/fs_audio*1000, EbNo_dB_audio), 'FontSize', 11);
legend({'Original', 'Recuperado (PCM + Hamming)'}, 'Location', 'northeast', 'FontSize', 10);
grid on;
ylim([-1.1 1.1]);

% ---- Subplot 2: Espectro de potencia (FFT + ventana Hann) ---------------
% Se implementa manualmente para cumplir la restricción de no usar pwelch.
N_fft    = min(N_comparar, 2^nextpow2(min(N_comparar, round(fs_audio))));  % ≤ 1 s de audio
audio_fft_orig  = audio_original(1:N_fft);
audio_fft_recup = audio_recuperado(1:N_fft);

% Ventana de Hann (reduce fugas espectrales).
ventana_hann  = 0.5 * (1 - cos(2*pi*(0:N_fft-1)' / (N_fft-1)));
potencia_ventana = sum(ventana_hann.^2);   % normalización de potencia

% FFT de ambas señales con ventana.
FFT_orig  = fft(audio_fft_orig  .* ventana_hann, N_fft);
FFT_recup = fft(audio_fft_recup .* ventana_hann, N_fft);

% Densidad espectral de potencia (escala unilateral, dB).
N_unilateral = floor(N_fft/2) + 1;
frec_vec     = (0:N_unilateral-1)' * (fs_audio / N_fft);   % [Hz]

PSD_orig  = (abs(FFT_orig(1:N_unilateral)).^2)  / potencia_ventana;
PSD_recup = (abs(FFT_recup(1:N_unilateral)).^2) / potencia_ventana;

% Convertir a dB (sumar 1e-12 para evitar log(0)).
PSD_orig_dB  = 10 * log10(PSD_orig  + 1e-12);
PSD_recup_dB = 10 * log10(PSD_recup + 1e-12);

subplot(2, 1, 2);
plot(frec_vec/1e3, PSD_orig_dB,  'b-', 'LineWidth', 1.2); hold on;
plot(frec_vec/1e3, PSD_recup_dB, 'r--', 'LineWidth', 1.2);
hold off;
xlabel('Frecuencia [kHz]', 'FontSize', 11);
ylabel('PSD [dB]', 'FontSize', 11);
title(sprintf('Espectro de Potencia (FFT + ventana Hann, N=%d puntos)', N_fft), 'FontSize', 11);
legend({'Original', 'Recuperado'}, 'Location', 'northeast', 'FontSize', 10);
grid on;
xlim([0 fs_audio/2/1e3]);

% Calcular y mostrar SNR de reconstrucción.
ruido_reconstruccion = audio_original(1:N_comparar) - audio_recuperado(1:N_comparar);
P_senal = mean(audio_original(1:N_comparar).^2);
P_ruido = mean(ruido_reconstruccion.^2);
if P_ruido > 0
    SNR_reconstruccion_dB = 10 * log10(P_senal / P_ruido);
    fprintf('[Figura 2] SNR de reconstrucción de audio: %.1f dB\n', SNR_reconstruccion_dB);
    SNR_cuantificacion_teo = 6.02 * bits_por_muestra + 1.76;
    fprintf('[Figura 2] SNDR teórico cuantificación (%d bits): %.1f dB\n', ...
        bits_por_muestra, SNR_cuantificacion_teo);
else
    fprintf('[Figura 2] Reconstrucción perfecta (SNR = ∞)\n');
end

end
