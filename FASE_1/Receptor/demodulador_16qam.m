function [secuencia_bits_recuperados,                ...
          simbolos_recibidos_tras_muestreo,           ...
          senal_banda_base_filtrada_para_ojo] =       ...
            demodulador_16qam(senal_pasabanda_recibida,    ...
                              coeficientes_filtro_rrc,     ...
                              muestras_por_simbolo_sps,    ...
                              span_filtro_simbolos,        ...
                              frecuencia_portadora_fc,     ...
                              frecuencia_muestreo_fs)
% =========================================================================
%  DEMODULADOR_16QAM
%  ------------------------------------------------------------------------
%  Realiza el receptor completo del sistema:  Cumple RF3 / RFN2.
%
%     1) BAJADA DE PASABANDA: multiplicación por 2cos y -2sin de la portadora
%        para recuperar las componentes I y Q.
%     2) FILTRO ACOPLADO: convolución con el mismo RRC del transmisor.
%        Esto maximiza la SNR a la salida y, junto con el RRC del Tx,
%        completa la respuesta de coseno alzado (Nyquist).
%     3) MUESTREO en los instantes óptimos t = k·Ts (extracción de símbolos).
%     4) DECISOR de mínima distancia (umbral) sobre la rejilla 4x4 del 16-QAM.
%     5) DEMAPEO Gray inverso para recuperar los bits.
%
%  Entradas:
%    senal_pasabanda_recibida : Señal real proveniente del canal AWGN.
%    coeficientes_filtro_rrc  : Coeficientes del RRC (mismo del Tx).
%    muestras_por_simbolo_sps : sps.
%    span_filtro_simbolos     : span del filtro (en símbolos).
%    frecuencia_portadora_fc  : fc de la portadora.
%    frecuencia_muestreo_fs   : fs del sistema.
%
%  Salidas:
%    secuencia_bits_recuperados         : Bits demodulados (estimados).
%    simbolos_recibidos_tras_muestreo   : Símbolos complejos en Rx (para
%                                         graficar la constelación).
%    senal_banda_base_filtrada_para_ojo : Señal banda base completa después
%                                         del filtro acoplado (para el
%                                         diagrama del ojo).
% =========================================================================

% =========================================================================
% 0) VALIDACIÓN DE ENTRADAS.
% =========================================================================
if isempty(senal_pasabanda_recibida)
    error('demodulador_16qam: la señal pasabanda recibida no puede estar vacía.');
end
if muestras_por_simbolo_sps < 2
    error('demodulador_16qam: sps debe ser >= 2.');
end
if span_filtro_simbolos < 1
    error('demodulador_16qam: span debe ser un entero >= 1.');
end
if frecuencia_portadora_fc <= 0
    error('demodulador_16qam: fc debe ser positiva.');
end
if frecuencia_muestreo_fs <= 0
    error('demodulador_16qam: fs debe ser positiva.');
end

% =========================================================================
% 1) BAJADA DE PASABANDA  (Down-conversion / demodulación I/Q).
% =========================================================================
% Multiplicamos por 2cos(2πfct) y -2sin(2πfct) para que:
%
%   I_demod(t) = s_pb(t) · 2cos(2πfct)
%              = I(t)·[1 + cos(4πfct)] - Q(t)·sin(4πfct)
%   Q_demod(t) = -s_pb(t) · 2sin(2πfct)
%              = Q(t)·[1 - cos(4πfct)] - I(t)·sin(4πfct)
%
% Los términos a 2fc serán eliminados por el filtro acoplado RRC, ya que su
% banda de paso (~Rs·(1+β)/2) está muy por debajo de 2fc.

longitud_senal = length(senal_pasabanda_recibida);
vector_tiempo  = (0:longitud_senal-1) / frecuencia_muestreo_fs;

% Componentes I y Q desplazadas a banda base (todavía con réplicas en 2fc).
componente_I_demodulada = senal_pasabanda_recibida .* ...
                          ( 2*cos(2*pi*frecuencia_portadora_fc*vector_tiempo));
componente_Q_demodulada = senal_pasabanda_recibida .* ...
                          (-2*sin(2*pi*frecuencia_portadora_fc*vector_tiempo));

% Señal banda base compleja antes del filtro acoplado.
senal_banda_base_antes_filtro = componente_I_demodulada + 1j*componente_Q_demodulada;

% =========================================================================
% 2) FILTRO ACOPLADO (matched filter) con el RRC.
% =========================================================================
% El filtro acoplado a una forma de pulso simétrica REAL es la misma forma.
% Como h_rrc es simétrica y real, h_matched = h_rrc.
senal_banda_base_filtrada_para_ojo = conv(senal_banda_base_antes_filtro, ...
                                          coeficientes_filtro_rrc);

% =========================================================================
% 3) MUESTREO en los instantes óptimos.
% =========================================================================
% Retardo total del sistema = (Tx_RRC + Rx_RRC) = 2 · (L_rrc-1)/2
%                            = 2 · span · sps  muestras.
retardo_total_muestras = 2 * span_filtro_simbolos * muestras_por_simbolo_sps;

% El primer símbolo válido está en la muestra (retardo + 1).  A partir de
% ahí muestreamos cada sps muestras.
indice_primer_simbolo = retardo_total_muestras + 1;
indices_muestreo      = indice_primer_simbolo : muestras_por_simbolo_sps : ...
                        length(senal_banda_base_filtrada_para_ojo);

% Extraemos los símbolos en los instantes de decisión.
simbolos_recibidos_tras_muestreo = senal_banda_base_filtrada_para_ojo(indices_muestreo);

% Solo nos interesan los N símbolos transmitidos originalmente (los últimos
% pueden ser "colas" producto del filtro).  Se truncan si exceden.
% El número exacto se conoce porque retardo+N*sps = longitud_total_aprox.
% Pero por robustez tomamos solo los primeros válidos.
%
% (No es estrictamente necesario porque el demapeo trabaja con todos.)

% =========================================================================
% 4) DECISOR de mínima distancia (hard decision).
% =========================================================================
% Los símbolos esperados (sin ruido) son los 16 puntos de la rejilla
% {-3,-1,+1,+3} en I y Q, normalizados por sqrt(10) (Es=1).
%
% La regla óptima en AWGN es elegir el punto de la constelación más cercano
% al símbolo recibido (mínima distancia euclidiana = ML porque los símbolos
% son equiprobables).  Como la constelación es rectangular, la decisión se
% separa en cada eje (I y Q) y se reduce a un cuantizador uniforme.

factor_normalizacion = sqrt(10);

% Des-normalizamos los símbolos recibidos para trabajar con la rejilla
% original {-3,-1,+1,+3}.
simbolos_recibidos_sin_normalizar = simbolos_recibidos_tras_muestreo * factor_normalizacion;

componente_I_recibida = real(simbolos_recibidos_sin_normalizar);
componente_Q_recibida = imag(simbolos_recibidos_sin_normalizar);

% Decisión sobre el eje I:
%   Umbral en -2 -> -3
%   Umbral entre -2 y 0  -> -1
%   Umbral entre 0 y +2  -> +1
%   Umbral en >+2        -> +3
componente_I_decidida = decidir_eje_4_niveles(componente_I_recibida);
componente_Q_decidida = decidir_eje_4_niveles(componente_Q_recibida);

% =========================================================================
% 5) DEMAPEO Gray inverso (vectorizado).
% =========================================================================
% Tabla inversa (la opuesta a la del modulador):
%
%   nivel   -3   -1   +1   +3
%   bits    00   01   11   10
%
% Para implementarla sin "containers.Map" (no portable a Octave) usamos un
% mapeo directo: dado el nivel n ∈ {-3,-1,+1,+3} calculamos un índice
% 0..3 con  idx = (n+3)/2  -> {0, 1, 2, 3}  y miramos la tabla.
%
%   idx       0    1    2    3
%   nivel    -3   -1   +1   +3
%   bit_alto  0    0    1    1
%   bit_bajo  0    1    1    0
tabla_bit_alto_segun_nivel = [0 0 1 1];                  % b_high para idx 0..3
tabla_bit_bajo_segun_nivel = [0 1 1 0];                  % b_low  para idx 0..3

indice_lookup_Q = (componente_Q_decidida + 3) / 2 + 1;   % +1 por indexación MATLAB.
indice_lookup_I = (componente_I_decidida + 3) / 2 + 1;

bit_alto_Q = tabla_bit_alto_segun_nivel(indice_lookup_Q);  % b3
bit_bajo_Q = tabla_bit_bajo_segun_nivel(indice_lookup_Q);  % b2
bit_alto_I = tabla_bit_alto_segun_nivel(indice_lookup_I);  % b1
bit_bajo_I = tabla_bit_bajo_segun_nivel(indice_lookup_I);  % b0

% Cada símbolo recupera sus 4 bits en el orden [b3 b2 b1 b0].
% Apilamos verticalmente y "linearizamos" para volver al vector original.
matriz_bits_recibidos      = [bit_alto_Q ; bit_bajo_Q ; bit_alto_I ; bit_bajo_I];
secuencia_bits_recuperados = reshape(matriz_bits_recibidos, 1, []);

end


% =========================================================================
%  FUNCIÓN LOCAL: decisor uniforme de 4 niveles (-3, -1, +1, +3).
% =========================================================================
function valor_decidido = decidir_eje_4_niveles(valor_recibido)
    valor_decidido = zeros(size(valor_recibido));

    valor_decidido(valor_recibido <  -2)                       = -3;
    valor_decidido(valor_recibido >= -2 & valor_recibido <  0) = -1;
    valor_decidido(valor_recibido >=  0 & valor_recibido <  2) =  1;
    valor_decidido(valor_recibido >=  2)                       =  3;
end
