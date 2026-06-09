function senal_banda_base_conformada = ...
            conformacion_pulso(simbolos_complejos_a_transmitir, ...
                               coeficientes_filtro_rrc,         ...
                               muestras_por_simbolo_sps)
% =========================================================================
%  CONFORMACION_PULSO
%  ------------------------------------------------------------------------
%  Realiza la conformación de pulso del transmisor sobre la secuencia de
%  símbolos complejos.  Consta de DOS etapas (Cumple RFN2):
%
%      1) UPSAMPLING (sobre-muestreo):  inserta sps-1 ceros entre símbolos.
%      2) FILTRADO con el RRC:          convolución con h_rrc.
%
%  El resultado es una señal en banda base (compleja) muestreada a fs=Rs*sps
%  con el pulso conformado en cada símbolo.  Esta señal será luego enviada
%  al modulador pasabanda.
%
%  Entradas:
%    simbolos_complejos_a_transmitir : Símbolos QAM (1 x N_sim).
%    coeficientes_filtro_rrc         : Coeficientes del filtro RRC.
%    muestras_por_simbolo_sps        : Tasa de sobre-muestreo.
%
%  Salida:
%    senal_banda_base_conformada : Señal banda base compleja, lista para
%                                  pasar al modulador pasabanda.
% =========================================================================

% ------------------------------------------------------------------
% 1) UPSAMPLING manual.
% ------------------------------------------------------------------
% Se inserta sps-1 ceros entre cada símbolo. Tras esto, la tasa de muestreo
% pasa de Rs a Rs*sps.  Por simplicidad y para no depender de la función
% upsample, lo hacemos con un reshape:
%
%   símbolo:    s1               s2               s3 ...
%   upsampled:  s1 0 0 0 ... 0   s2 0 0 0 ... 0   s3 ...
%
numero_simbolos = length(simbolos_complejos_a_transmitir);
senal_upsampled = zeros(1, numero_simbolos * muestras_por_simbolo_sps);

% Coloca cada símbolo en la primera posición de cada bloque de "sps" muestras.
senal_upsampled(1:muestras_por_simbolo_sps:end) = simbolos_complejos_a_transmitir;

% ------------------------------------------------------------------
% 2) Filtrado con el RRC mediante convolución lineal.
% ------------------------------------------------------------------
% La convolución expande la señal: salida = length(senal) + length(h) - 1.
% Eso introduce un retardo de (length(h)-1)/2 muestras (filtro simétrico).
senal_banda_base_conformada = conv(senal_upsampled, coeficientes_filtro_rrc);

end
