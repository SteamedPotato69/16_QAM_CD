function bits_codificados = codificador_hamming(bits_datos)
% =========================================================================
%  CODIFICADOR_HAMMING
%  ------------------------------------------------------------------------
%  Implementa el codificador Hamming(7,4) sistemático desde primeros
%  principios (Cumple RF2-Fase2).  NO usa funciones de Communications
%  Toolbox (encode, hammgen, etc.).
%
%  Parámetros del código:
%    n = 7  : Longitud de la palabra código [bits]
%    k = 4  : Longitud del mensaje (datos)   [bits]
%    t = 1  : Capacidad de corrección (errores simples)
%    d_min = 3 : Distancia mínima de Hamming
%    Tasa   r = k/n = 4/7
%
%  Matriz generadora G (4×7) — forma sistemática G = [I_k | P]:
%  ─────────────────────────────────────────────────────────────
%    Codeword: c = m · G  (aritmética GF(2), mod(m*G, 2))
%    donde m = [d1 d2 d3 d4] y c = [d1 d2 d3 d4 p1 p2 p3]
%
%    G = [1 0 0 0 | 1 1 0]   ← d1 → p1=d1⊕d2⊕d4, p2=d1⊕d3⊕d4
%        [0 1 0 0 | 1 0 1]   ← d2 → p1, p3=d2⊕d3⊕d4
%        [0 0 1 0 | 0 1 1]   ← d3 → p2, p3
%        [0 0 0 1 | 1 1 1]   ← d4 → p1, p2, p3
%
%  Ecuaciones de paridad:
%    p1 = d1 ⊕ d2 ⊕ d4
%    p2 = d1 ⊕ d3 ⊕ d4
%    p3 = d2 ⊕ d3 ⊕ d4
%
%  Verificación: G · H^T = 0  (mod 2)  [ver decodificador_hamming.m]
%
%  Entrada:
%    bits_datos : Vector binario (fila o columna).
%                 Longitud debe ser múltiplo de 4.
%
%  Salida:
%    bits_codificados : Vector fila de longitud length(bits_datos)*7/4.
%                       Orden: [d1 d2 d3 d4 p1 p2 p3] por bloque.
% =========================================================================

% ------------------------------------------------------------------
% 0) Validación de entradas.
% ------------------------------------------------------------------
if isempty(bits_datos)
    error('codificador_hamming: el vector de bits no puede estar vacío.');
end
if ~all(bits_datos == 0 | bits_datos == 1)
    error('codificador_hamming: el vector solo debe contener bits {0, 1}.');
end
if mod(length(bits_datos), 4) ~= 0
    error('codificador_hamming: la longitud del vector debe ser múltiplo de 4 (k=4).');
end

% ------------------------------------------------------------------
% 1) Matriz generadora G en GF(2) — forma sistemática G = [I4 | P].
% ------------------------------------------------------------------
%   Las columnas 1-4 forman la identidad 4×4 (parte sistemática).
%   Las columnas 5-7 son la matriz de paridad P.
G = [1 0 0 0  1 1 0;   % fila d1
     0 1 0 0  1 0 1;   % fila d2
     0 0 1 0  0 1 1;   % fila d3
     0 0 0 1  1 1 1];  % fila d4

% ------------------------------------------------------------------
% 2) Codificación vectorizada: c = mod(m * G, 2).
% ------------------------------------------------------------------
% Reorganizar bits en una matriz (N_bloques × 4), donde cada FILA
% es un bloque de 4 bits de datos [d1 d2 d3 d4].
N_bloques       = length(bits_datos) / 4;
m               = reshape(bits_datos(:), 4, N_bloques)';   % (N×4)

% Multiplicación matricial en GF(2):
%   c = m · G  (mod 2)
% La función mod() hace la reducción módulo 2 elemento a elemento.
c = mod(m * G, 2);   % (N×7)

% ------------------------------------------------------------------
% 3) Serializar a vector fila [bloque1 | bloque2 | ... | bloqueN].
%    Cada bloque tiene el formato [d1 d2 d3 d4 p1 p2 p3].
% ------------------------------------------------------------------
bits_codificados = reshape(c', 1, []);   % vector fila de longitud 7*N

end
