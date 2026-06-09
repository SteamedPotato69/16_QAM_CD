function audio_reconstruido = conversor_dac(bits_recibidos, bits_por_muestra)
% =========================================================================
%  CONVERSOR_DAC
%  ------------------------------------------------------------------------
%  Convierte una secuencia binaria PCM de vuelta a muestras de audio
%  mediante decodificación e interpolación Midrise de B bits.
%  Cumple RF1-Fase2.  Es el proceso inverso de conversor_adc.m.
%  NO usa funciones de Communications Toolbox.
%
%  Proceso inverso al ADC:
%  ─────────────────────────────────────────────────────────────────────
%    1. Decodificar B bits → índice entero q ∈ [0, L-1]  (big-endian)
%    2. Reconstruir nivel: x_q = q · Δ - 1 + Δ/2
%       donde Δ = 2/L = 2/2^B
%
%  El resultado está en [-1 + Δ/2, +1 - Δ/2] (el cuantificador Midrise
%  nunca alcanza exactamente ±1; el error de cuantificación máximo es Δ/2).
%
%  NOTA sobre longitud:
%    Si la cadena de bits recibida tiene errores no corregibles, la señal
%    reconstruida puede diferir de la original pero siempre tendrá la
%    longitud correcta (length(bits_recibidos) / bits_por_muestra muestras).
%
%  Entradas:
%    bits_recibidos   : Vector de bits {0,1} (fila o columna).
%                       Longitud debe ser múltiplo de bits_por_muestra.
%    bits_por_muestra : Resolución B del cuantificador [bits].
%
%  Salida:
%    audio_reconstruido : Vector COLUMNA de muestras de audio en [-1, +1].
% =========================================================================

% ------------------------------------------------------------------
% 0) Validación de entradas.
% ------------------------------------------------------------------
if isempty(bits_recibidos)
    error('conversor_dac: el vector de bits no puede estar vacío.');
end
if bits_por_muestra < 1 || mod(bits_por_muestra, 1) ~= 0
    error('conversor_dac: bits_por_muestra debe ser un entero >= 1.');
end
if mod(length(bits_recibidos), bits_por_muestra) ~= 0
    error('conversor_dac: la longitud de bits debe ser múltiplo de bits_por_muestra.');
end
if ~all(bits_recibidos == 0 | bits_recibidos == 1)
    error('conversor_dac: el vector solo debe contener bits {0, 1}.');
end

% ------------------------------------------------------------------
% 1) Decodificación binaria → índice entero (big-endian, MSB primero).
%    Para N muestras × B bits → matriz (N×B) → índice (N×1).
%
%    q = bits_matrix · [2^(B-1); ...; 2^1; 2^0]
% ------------------------------------------------------------------
num_muestras = length(bits_recibidos) / bits_por_muestra;
potencias    = 2.^(bits_por_muestra-1 : -1 : 0)';  % (B×1)

% Reorganizar bits en (N×B).
bits_matrix  = reshape(bits_recibidos(:), bits_por_muestra, num_muestras)';  % (N×B)

% Producto matricial: suma ponderada de bits → índice decimal.
indices_q = bits_matrix * potencias;   % (N×1), rango [0, L-1]

% ------------------------------------------------------------------
% 2) Reconstrucción de nivel (proceso inverso al cuantificador Midrise).
% ------------------------------------------------------------------
L                   = 2^bits_por_muestra;
paso_cuantificacion = 2 / L;                      % Δ

% Centro del intervalo de cuantificación asociado a cada índice.
audio_reconstruido  = indices_q * paso_cuantificacion - 1 + paso_cuantificacion/2;
% Resultado en [-1 + Δ/2, +1 - Δ/2]

end
