function [bits_entrelazados, permutacion] = entrelazador_bits(bits_entrada, semilla)
% =========================================================================
% ENTRELAZADOR_BITS
% -------------------------------------------------------------------------
% Entrelaza un vector binario usando una permutacion pseudoaleatoria fija.
%
% Objetivo:
%   Dispersar errores agrupados antes de la decodificacion Hamming.
%
% Si y = x(permutacion), entonces el desentrelazador recupera:
%   x(permutacion) = y
%
% Entradas:
%   bits_entrada : vector binario fila o columna
%   semilla      : semilla para reproducibilidad
%
% Salidas:
%   bits_entrelazados : vector fila permutado
%   permutacion       : permutacion usada
% =========================================================================

if isempty(bits_entrada)
    error('entrelazador_bits: bits_entrada no puede estar vacío.');
end

if ~all(bits_entrada == 0 | bits_entrada == 1)
    error('entrelazador_bits: la entrada solo debe contener bits 0 o 1.');
end

bits_entrada = bits_entrada(:).';
N = length(bits_entrada);

estado_rng = rng;
rng(semilla);

permutacion = randperm(N);
bits_entrelazados = bits_entrada(permutacion);

rng(estado_rng);
end