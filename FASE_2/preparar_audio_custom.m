%% preparar_audio_custom.m
% Prepara un audio local para usarlo como entrada oficial de Fase II.
% Genera FASE_2/Audio/audio_prueba.wav en formato:
% WAV, mono, 44100 Hz, 10 segundos, 16 bits.

clear;
clc;
close all;

[archivo, carpeta] = uigetfile( ...
    {'*.wav;*.mp3;*.m4a;*.flac', 'Archivos de audio'}, ...
    'Selecciona tu audio local');

if isequal(archivo, 0)
    error('No seleccionaste ningún archivo.');
end

rutaEntrada = fullfile(carpeta, archivo);
[x, fsOriginal] = audioread(rutaEntrada);

fprintf('Audio cargado: %s\n', rutaEntrada);
fprintf('Fs original = %.0f Hz\n', fsOriginal);
fprintf('Duración original = %.2f s\n', length(x)/fsOriginal);

% Convertir a mono si es estéreo
if size(x, 2) > 1
    x = mean(x, 2);
    fprintf('Audio convertido a mono.\n');
end

% Remuestrear manualmente a 44100 Hz si hace falta
fsObjetivo = 44100;

if fsOriginal ~= fsObjetivo
    tOriginal = (0:length(x)-1)' / fsOriginal;
    tNuevo = (0:1/fsObjetivo:tOriginal(end))';
    x = interp1(tOriginal, x, tNuevo, 'linear', 0);
    fprintf('Audio remuestreado a 44100 Hz.\n');
end

% Recortar o rellenar a 10 segundos
duracionObjetivo = 10;
Nobjetivo = fsObjetivo * duracionObjetivo;

if length(x) > Nobjetivo
    x = x(1:Nobjetivo);
    fprintf('Audio recortado a 10 segundos.\n');
elseif length(x) < Nobjetivo
    x = [x; zeros(Nobjetivo - length(x), 1)];
    fprintf('Audio rellenado con silencio hasta 10 segundos.\n');
end

% Normalizar para evitar saturación
maxAbs = max(abs(x));
if maxAbs > 0
    x = 0.98 * x / maxAbs;
end

% Guardar en FASE_2/Audio/audio_prueba.wav
carpetaSalida = fullfile(pwd, 'Audio');

if ~exist(carpetaSalida, 'dir')
    mkdir(carpetaSalida);
end

rutaSalida = fullfile(carpetaSalida, 'audio_prueba.wav');
audiowrite(rutaSalida, x, fsObjetivo, 'BitsPerSample', 16);

fprintf('\nAudio preparado correctamente.\n');
fprintf('Guardado en: %s\n', rutaSalida);
fprintf('Fs final = %.0f Hz\n', fsObjetivo);
fprintf('Duración final = %.2f s\n', length(x)/fsObjetivo);
fprintf('Formato final: WAV, mono, 16 bits.\n');