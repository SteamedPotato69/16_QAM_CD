function [bits, audio_cuantificado, paso_cuantificacion, tasa_bits] = ...
            conversor_adc(audio_muestras, bits_por_muestra, fs_audio)
% =========================================================================
%  CONVERSOR_ADC
%  ------------------------------------------------------------------------
%  Convierte una señal de audio analógica (muestreada) a una secuencia
%  binaria PCM mediante cuantificación uniforme Midrise de B bits.
%  Cumple RF1-Fase2 (procesamiento de fuente de audio).
%
%  NO usa funciones de Communications Toolbox.
%
%  Modelo de cuantificador Midrise uniforme:
%  ─────────────────────────────────────────────────────────────────────
%    Rango de entrada : [-1, +1]  (normalizado)
%    Número de niveles: L = 2^B
%    Paso cuantif.    : Δ = 2 / L
%    Índice (0..L-1)  : q = floor((x + 1) / Δ),  clampeado a [0, L-1]
%    Nivel reconstr.  : x_q = q · Δ - 1 + Δ/2   (centro del intervalo)
%
%  Codificación binaria: índice q → B bits, MSB primero (big-endian).
%  Con B=16: 65536 niveles, Δ = 2/65536 ≈ 30.5 μV (para señal de 1 V).
%
%  SNDR teórico (cuantificador ideal):
%    SNDR = 6.02·B + 1.76 dB = 6.02·16 + 1.76 ≈ 98.1 dB  (para B=16)
%
%  Entradas:
%    audio_muestras   : Vector de muestras en [-1, +1] (columna o fila).
%    bits_por_muestra : Resolución B del cuantificador [bits]. Recomendado: 16.
%    fs_audio         : Frecuencia de muestreo del audio [Hz].
%
%  Salidas:
%    bits             : Vector FILA de bits {0,1}, longitud = N · B.
%                       Los primeros B bits corresponden a la 1ª muestra
%                       (MSB primero dentro de cada muestra).
%    audio_cuantificado : Vector con los niveles reconstruidos del cuantificador,
%                         útil para medir la distorsión por cuantificación.
%    paso_cuantificacion: Δ = 2 / 2^B.
%    tasa_bits          : Tasa de bits de la fuente [bps] = fs_audio · B.
% =========================================================================

% ------------------------------------------------------------------
% 0) Validación de entradas.
% ------------------------------------------------------------------
if isempty(audio_muestras)
    error('conversor_adc: el vector de audio no puede estar vacío.');
end
if bits_por_muestra < 1 || mod(bits_por_muestra, 1) ~= 0
    error('conversor_adc: bits_por_muestra debe ser un entero >= 1.');
end
if fs_audio <= 0
    error('conversor_adc: fs_audio debe ser positiva.');
end
if max(abs(audio_muestras)) > 1 + 1e-6
    warning('conversor_adc: hay muestras fuera de [-1,1] (%.4f). Se aplica clipping.', ...
        max(abs(audio_muestras)));
end

% Asegurar vector columna.
audio_muestras = audio_muestras(:);
num_muestras   = length(audio_muestras);

% Clipping a [-1, 1] para evitar overflow en el cuantificador.
audio_clip = max(-1, min(1, audio_muestras));

% ------------------------------------------------------------------
% 1) Cuantificación Midrise uniforme.
% ------------------------------------------------------------------
L                  = 2^bits_por_muestra;    % Número de niveles
paso_cuantificacion = 2 / L;               % Δ = 2 / L

% Índice de cuantificación: mapeo [-1, 1] → [0, L-1].
% Se clampea para cubrir el caso x = +1 exactamente.
indices_q = floor((audio_clip + 1) / paso_cuantificacion);
indices_q = max(0, min(L - 1, indices_q));   % (N×1), enteros en [0, L-1]

% Niveles reconstruidos (centro de cada intervalo de cuantificación).
audio_cuantificado = indices_q * paso_cuantificacion - 1 + paso_cuantificacion/2;

% ------------------------------------------------------------------
% 2) Codificación binaria vectorizada (big-endian, MSB primero).
%    Para cada muestra n, bit_b = floor(q_n / 2^(B-b)) mod 2.
%
%    Implementación:
%      potencias (1×B): [2^(B-1), 2^(B-2), ..., 2^1, 2^0]
%      bits_matrix (N×B): mod(floor(indices_q ./ potencias), 2)
%        donde ./ aprovecha broadcasting de MATLAB (N×1) ./ (1×B) → (N×B)
% ------------------------------------------------------------------
potencias    = 2.^(bits_por_muestra-1 : -1 : 0);   % (1×B)
bits_matrix  = mod(floor(indices_q ./ potencias), 2);  % (N×B), lógica bit-a-bit

% Serializar: apilar filas → vector fila con MSB primero por muestra.
% reshape(...') transpone primero (columnas consecutivas = misma muestra)
% y luego aplana. Esto garantiza el orden [bit0_MSB, bit0_(B-1), ..., bitN_0].
bits = reshape(bits_matrix', 1, []);   % (1 × N·B)

% ------------------------------------------------------------------
% 3) Tasa de bits de la fuente.
% ------------------------------------------------------------------
tasa_bits = fs_audio * bits_por_muestra;   % [bps]

fprintf('[ADC] %d muestras × %d bits = %d bits  |  Δ = %.2e  |  Rb = %.1f kbps\n', ...
    num_muestras, bits_por_muestra, length(bits), paso_cuantificacion, tasa_bits/1e3);

end
