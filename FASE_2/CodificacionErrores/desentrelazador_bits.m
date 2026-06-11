function bits_originales = desentrelazador_bits(bits_entrelazados, permutacion)
% =========================================================================
% DESENTRELAZADOR_BITS
% -------------------------------------------------------------------------
% Invierte el entrelazado aplicado por entrelazador_bits.
%
% Si:
%   y = x(permutacion)
%
% entonces se recupera:
%   x(permutacion) = y
%
% Entradas:
%   bits_entrelazados : vector binario recibido en orden entrelazado
%   permutacion       : permutacion usada en transmision
%
% Salida:
%   bits_originales   : vector fila con el orden original restaurado
% =========================================================================

if isempty(bits_entrelazados)
    error('desentrelazador_bits: bits_entrelazados no puede estar vacío.');
end

bits_entrelazados = bits_entrelazados(:).';

if length(bits_entrelazados) ~= length(permutacion)
    error('desentrelazador_bits: la longitud de bits y permutacion no coincide.');
end

bits_originales = zeros(1, length(bits_entrelazados));
bits_originales(permutacion) = bits_entrelazados;
end