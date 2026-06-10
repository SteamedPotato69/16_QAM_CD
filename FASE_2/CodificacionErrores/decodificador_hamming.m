function [bits_decodificados, num_errores_corregidos] = decodificador_hamming(bits_recibidos)
% =========================================================================
%  DECODIFICADOR_HAMMING
%  ------------------------------------------------------------------------
%  Implementa el decodificador Hamming(7,4) con corrección de errores
%  simples (t=1) mediante decodificación por síndrome.
%  NO usa funciones de Communications Toolbox (decode, etc.).
%
%  Algoritmo (cálculo síndrome):
%  ─────────────────────────────────────────────────────────────────────
%    1. Calcular síndrome:  s = r · H^T  (mod 2)
%       donde r = [r1..r7] es la palabra recibida (fila).
%
%    2. Convertir síndrome a posición de error:
%       pos_error = s(1) + 2·s(2) + 4·s(3)
%       Si pos_error > 0 : bit en esa posición está en error → flip.
%       Si pos_error = 0 : no hay error (o error no corregible).
%
%    3. Extraer bits de datos: posiciones 1,2,3,4 de la palabra corregida
%       (la parte sistemática del codeword [d1 d2 d3 d4 p1 p2 p3]).
%
%  Matriz de control de paridad H (3×7) — consistente con G de codificador:
%  ─────────────────────────────────────────────────────────────────────
%    H = [1 1 0 1 1 0 0]  ← verifica p1: pos 1,2,4,5
%        [1 0 1 1 0 1 0]  ← verifica p2: pos 1,3,4,6
%        [0 1 1 1 0 0 1]  ← verifica p3: pos 2,3,4,7
%
%    Propiedad: G · H^T = 0 (mod 2).
%
%  Columnas de H^T = [H[:,j]] representan síndrome para error en pos j:
%    pos 1→[1;1;0]=6  pos 2→[1;0;1]=5  pos 3→[0;1;1]=3  pos 4→[1;1;1]=7
%    pos 5→[1;0;0]=4  pos 6→[0;1;0]=2  pos 7→[0;0;1]=1
%  (El decimal se calcula como s(1)*4 + s(2)*2 + s(3)*1, MSB primero.)
%
%  Nota sobre errores dobles (t>1):
%    Hamming(7,4) con d_min=3 solo corrige t=1 error por codeword.
%    Con 2 o más errores, el síndrome señala una posición incorrecta
%    y el decodificador empeorará el resultado (comportamiento esperado).
%
%  Entradas:
%    bits_recibidos : Vector binario, longitud múltiplo de 7.
%
%  Salidas:
%    bits_decodificados    : Vector fila, longitud = length(bits_recibidos)*4/7.
%    num_errores_corregidos: Número total de codewords con corrección aplicada.
% =========================================================================

% ------------------------------------------------------------------
% 0) Validación de entradas.
% ------------------------------------------------------------------
if isempty(bits_recibidos)
    error('decodificador_hamming: el vector de bits no puede estar vacío.');
end
if mod(length(bits_recibidos), 7) ~= 0
    error('decodificador_hamming: la longitud debe ser múltiplo de 7 (n=7).');
end

% ------------------------------------------------------------------
% 1) Matriz de control de paridad H (3×7).
%    Verificación: G · H^T = 0 (mod 2)
%      Fila 1 de H: cubre posiciones {1,2,4,5} → p1 = d1⊕d2⊕d4
%      Fila 2 de H: cubre posiciones {1,3,4,6} → p2 = d1⊕d3⊕d4
%      Fila 3 de H: cubre posiciones {2,3,4,7} → p3 = d2⊕d3⊕d4
% ------------------------------------------------------------------
H = [1 1 0 1 1 0 0;   % fila s1
     1 0 1 1 0 1 0;   % fila s2
     0 1 1 1 0 0 1];  % fila s3

% Tabla de síndrome → posición de error.
% Sindrome s = [s1 s2 s3], decimal (MSB=s1): s1*4 + s2*2 + s3.
% tablon_sindrome(decimal+1) = posición del error (0 = sin error).
%   Dec 0→sin error, 1→pos7, 2→pos6, 3→pos3, 4→pos5, 5→pos2, 6→pos1, 7→pos4
tablon_sindrome = [0, 7, 6, 3, 5, 2, 1, 4];

% ------------------------------------------------------------------
% 2) Reorganizar en matriz (N_codewords × 7).
% ------------------------------------------------------------------
N_codewords = length(bits_recibidos) / 7;
r = reshape(bits_recibidos(:), 7, N_codewords)';   % (N×7)

% ------------------------------------------------------------------
% 3) Calcular síndrome: s = mod(r · H^T, 2)  → (N×3)
% ------------------------------------------------------------------
s = mod(r * H', 2);   % (N × 3)

% Convertir síndrome a decimal (MSB=s(:,1)):
% decimal = s1*4 + s2*2 + s3*1
sindrome_decimal = s(:,1)*4 + s(:,2)*2 + s(:,3)*1;   % (N×1), rango [0..7]

% Convertir decimal a posición de error usando tabla de búsqueda.
posicion_error = tablon_sindrome(sindrome_decimal + 1)';  % (N×1)

% ------------------------------------------------------------------
% 4) Corregir errores (vectorizado).
% ------------------------------------------------------------------
% Encontrar codewords con error corregible (posicion_error ∈ [1..7]).
idx_con_error = find(posicion_error > 0);
num_errores_corregidos = length(idx_con_error);

if ~isempty(idx_con_error)
    % Calcular índices lineales en la matriz r para flip de bits.
    % r es (N×7): índice lineal = (fila-1)*7 + columna
    filas_error  = idx_con_error;
    cols_error   = posicion_error(idx_con_error);
    idx_lineal   = (filas_error - 1) * 7 + cols_error;
    r(idx_lineal) = 1 - r(idx_lineal);   % flip: 0↔1
end

% ------------------------------------------------------------------
% 5) Extraer bits de datos: posiciones 1..4 (parte sistemática).
%    Codeword = [d1 d2 d3 d4 p1 p2 p3] → datos en cols 1:4.
% ------------------------------------------------------------------
datos = r(:, 1:4);                         % (N×4)
bits_decodificados = reshape(datos', 1, []);   % vector fila

end
