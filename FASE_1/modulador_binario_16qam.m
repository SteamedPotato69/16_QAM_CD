function [secuencia_bits, simbolos_complejos_normalizados] = ...
            modulador_binario_16qam(numero_bits_a_generar)
% =========================================================================
%  MODULADOR_BINARIO_16QAM
%  ------------------------------------------------------------------------
%  Genera una secuencia binaria aleatoria y la mapea a símbolos complejos
%  16-QAM utilizando código Gray (Cumple RF1, RFN2).
%
%  Entradas:
%    numero_bits_a_generar : Cantidad de bits a transmitir
%                            (debe ser múltiplo de 4).
%
%  Salidas:
%    secuencia_bits                  : Vector fila con los bits {0,1}.
%    simbolos_complejos_normalizados : Vector fila de símbolos QAM con
%                                      energía promedio Es = 1.
%
%  Constelación 16-QAM (Gray) — los 4 bits del símbolo son [b3 b2 b1 b0]:
%        - (b3 b2) controlan la amplitud en el eje Q (cuadratura).
%        - (b1 b0) controlan la amplitud en el eje I (fase).
%
%  Mapeo Gray para 2 bits  ->  nivel de amplitud {-3,-1,+1,+3}:
%        "00" -> -3 ;   "01" -> -1 ;   "11" -> +1 ;   "10" -> +3
%
%  Visualmente (eje I con b1 b0 en horizontal, eje Q con b3 b2 en vertical):
%
%                       Q
%                       ^
%       b3b2 = 10  ->  +3 |  0010   0110   1110   1010
%       b3b2 = 11  ->  +1 |  0011   0111   1111   1011
%       b3b2 = 01  ->  -1 |  0001   0101   1101   1001
%       b3b2 = 00  ->  -3 |  0000   0100   1100   1000  --> I
%                            -3     -1     +1     +3
%                            00     01     11     10  (b1 b0)
% =========================================================================

% ------------------------------------------------------------------
% 1) Generación de la secuencia binaria aleatoria.
% ------------------------------------------------------------------
% randi([0 1], 1, N) produce N bits uniformemente distribuidos en {0,1}.
secuencia_bits = randi([0 1], 1, numero_bits_a_generar);

% ------------------------------------------------------------------
% 2) Agrupar los bits en bloques de k=4 bits, uno por símbolo.
% ------------------------------------------------------------------
bits_por_simbolo = 4;                                   % k = log2(16).
numero_simbolos  = numero_bits_a_generar / bits_por_simbolo;

% Cada COLUMNA de matriz_bits_por_simbolo representa un símbolo: [b3;b2;b1;b0].
matriz_bits_por_simbolo = reshape(secuencia_bits, bits_por_simbolo, numero_simbolos);

% ------------------------------------------------------------------
% 3) Mapeo Gray bidimensional (separable en I y Q).
% ------------------------------------------------------------------
% Estrategia: convertimos cada par de bits a un índice decimal (0..3) y
% miramos la tabla.
%
%   par_bits   "00"  "01"  "11"  "10"
%   índice      0     1     3     2
%   amplitud   -3    -1    +1    +3
%
% Por tanto la tabla, indexada 0..3, es:
%   tabla_gray = [-3, -1, +3, +1]   (índice 0..3, en MATLAB 1..4).
tabla_gray_amplitud = [-3, -1, +3, +1];                  % MATLAB indexa desde 1.

% Bits de cuadratura Q (b3 b2) -> índice -> amplitud.
indices_Q = 2*matriz_bits_por_simbolo(1,:) + matriz_bits_por_simbolo(2,:);   % 0..3
amplitudes_componente_Q = tabla_gray_amplitud(indices_Q + 1);                % +1 por MATLAB

% Bits de fase I (b1 b0) -> índice -> amplitud.
indices_I = 2*matriz_bits_por_simbolo(3,:) + matriz_bits_por_simbolo(4,:);   % 0..3
amplitudes_componente_I = tabla_gray_amplitud(indices_I + 1);

% ------------------------------------------------------------------
% 4) Construcción de los símbolos complejos y normalización.
% ------------------------------------------------------------------
% Energía promedio de la constelación 16-QAM con niveles {±1,±3}:
%   E_avg = (1/16) * sum |s_i|^2 = 10.
% Para que Es = 1 dividimos por sqrt(10).
factor_normalizacion = sqrt(10);

simbolos_complejos_normalizados = ...
    (amplitudes_componente_I + 1j*amplitudes_componente_Q) / factor_normalizacion;

end
