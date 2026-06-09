function senal_pasabanda_real = ...
            modulacion_pasabanda(senal_banda_base_compleja, ...
                                 frecuencia_portadora_fc,   ...
                                 frecuencia_muestreo_fs)
% =========================================================================
%  MODULACION_PASABANDA
%  ------------------------------------------------------------------------
%  Sube la señal banda base compleja a una frecuencia portadora fc, dando
%  como resultado una señal pasabanda REAL (la que físicamente se enviaría
%  por el canal).  Cumple RF1 / RFN2.
%
%  Modelo matemático:
%      s_bb(t)   = I(t) + j·Q(t)
%      s_pb(t)   = Re{ s_bb(t) · exp(j·2π·fc·t) }
%                = I(t)·cos(2π·fc·t)  -  Q(t)·sin(2π·fc·t)
%
%  Restricción de Nyquist: fc + B/2 < fs/2, donde B ≈ (1+β)·Rs es el ancho
%  de banda de la señal banda base (un solo lado).  El main verifica que
%  esto se cumpla.
%
%  Entradas:
%    senal_banda_base_compleja : Señal banda base I + jQ (de conformación).
%    frecuencia_portadora_fc   : Frecuencia portadora (Hz, o normalizada).
%    frecuencia_muestreo_fs    : Frecuencia de muestreo (debe coincidir con
%                                la usada al generar la banda base).
%
%  Salida:
%    senal_pasabanda_real : Señal real, lista para entrar al canal AWGN.
% =========================================================================

% ------------------------------------------------------------------
% 1) Vector temporal acorde con la longitud de la señal banda base.
% ------------------------------------------------------------------
longitud_senal      = length(senal_banda_base_compleja);
vector_tiempo       = (0:longitud_senal-1) / frecuencia_muestreo_fs;   % t = n*T.

% ------------------------------------------------------------------
% 2) Componentes en fase (I) y cuadratura (Q) de la banda base.
% ------------------------------------------------------------------
componente_I = real(senal_banda_base_compleja);    % I(t).
componente_Q = imag(senal_banda_base_compleja);    % Q(t).

% ------------------------------------------------------------------
% 3) Modulación: producto con cos / -sin de la portadora.
% ------------------------------------------------------------------
% La señal resultante es REAL y ocupa la banda [fc - B/2 , fc + B/2].
senal_pasabanda_real = componente_I .* cos(2*pi*frecuencia_portadora_fc*vector_tiempo) ...
                     - componente_Q .* sin(2*pi*frecuencia_portadora_fc*vector_tiempo);

end
