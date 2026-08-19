module Complexity
using LinearAlgebra, Statistics,Makie,GLMakie,DSP,FFTW,PortAudio, DrWatson,MATLAB
include(srcdir("utils.jl"))
# add https://github.com/JuliaAudio/MP3.jl
struct Data
    fname
    val
end
function main(foldername;trim=false,example=nothing,overwrite=false,method="spectrum")
    fullfnames = Utils.recursive_list_all_files_in_tree(foldername)
    if example != nothing
        fullfnames = fullfnames[last.(split.(fullfnames,"/")) .== example]
    end
    fnames = [x[end] for x in splitpath.(fullfnames)]
    outfile = datadir("exp_pro", split(foldername, "/")[end] * "_trim_" * string(trim) * "_method_" * method * ".jld2")
    if isfile(outfile) && example == nothing && overwrite == false
        d = load(outfile)
        g = d["data"].val
    elseif (!isfile(outfile) && example == nothing) || (overwrite == true && example == nothing)
        if method == "matlab"
            g = getcomplexity_matlab_flucpat.(fullfnames;trim=trim)
        elseif method == "autocor"
            g = getcomplexity_autocor.(fullfnames;trim=trim)
        else
            g = getcomplexity.(fullfnames;trim=trim)
        end
        d = Data(fullfnames,g)
        wsave(outfile, Dict(:data => d))
    else
        if method == "matlab"
            g = getcomplexity_matlab_flucpat.(fullfnames;trim=trim)
        elseif method == "autocor"
            g = getcomplexity_autocor.(fullfnames;trim=trim)
        else
            g = getcomplexity.(fullfnames;trim=trim)
        end
    end
    nonanmask = .!isnan.(g)
    g = g[nonanmask]
    fnames = fnames[nonanmask]
    fullfnames = fullfnames[nonanmask]
    if example == nothing
        fhist = Figure()
        ax = Axis(fhist[1, 1], xlabel = "Rhythmic Complexity", ylabel = "Counts")
        hist!(ax,g, bar_labels = :values,label_formatter=x-> Int(x), label_size = 12, strokewidth = 0.5, strokecolor = (:black, 0.5), color = :values)
        save(plotsdir(last(split(outfile,"/"))[1:end-5] * "_hist"* ".png"),fhist)
    end
    GLMakie.activate!()
    f = Figure()
    ax = Axis(f[1, 1], yticks=(1:length(g),chop.(fnames[sortperm(g,rev=true)];tail=4)),xlabel="Rhythmic Complexity")
    barplot!(ax,sort(g,rev=true);direction=:x)
    sortedfullnames = fullfnames[sortperm(g,rev=true)]
    Utils.click_and_play(f,ax,sortedfullnames;trim=trim)
    display(f)
    if example == nothing
        save(plotsdir(last(split(outfile,"/"))[1:end-4] * "png"),f)
    end

end
function getcomplexity(fname;trim=trim)
    x = load(fname)
    sr = x.samplerate
    m = Utils.meanchannels(x)
    if trim == true
        m = Utils.trimfirst5sec(m,sr)
    end
    s,fs=getmelstft(m,sr)
    f = []
    for k = 1:size(s,2)
        s₁ = s[:,k]
        s₁ .-= mean(s₁) # not a big impact. Important is not to divide by std; louder channels are more relevant
        pxx = periodogram(s₁;fs=fs)
        push!(f,pxx.power[pxx.freq .>= 1 .&& pxx.freq .<= 3])
    end
    c = complexity(vcat(f'...))
end
function getcomplexity_autocor(fname;trim=trim)
    x = load(fname)
    sr = x.samplerate
    m = Utils.meanchannels(x)
    if trim == true
        m = Utils.trimfirst5sec(m,sr)
    end
    s,fs=getmelstft(m,sr)
    f = []
    for k = 1:size(s,2)
        s₁ = s[:,k]
        s₁ .-= mean(s₁) # not a big impact. Important is not to divide by std; louder channels are more relevant; classical music sems to go up if we don't demean?
        au = xcorr(s₁,s₁,)
        au = au[div(length(au),2)+1:end]
        push!(f,au)
    end
    c = complexity(vcat(f'...))
end
function getcomplexity_matlab_flucpat(fname;trim=trim)
    mat"addpath(genpath('~/Documents/MATLAB/mirtoolbox'))"
    mat"mirverbose(0)"
    mat"addpath(genpath('/Users/maarhart/Downloads/miremotionPT'))"
    if trim
        mat"a = miraudio($fname,'Extract',0,5)"
    else
        mat"a = miraudio($fname)"
    end
    #mat"s=mirspectrum(a,'Frame',.023,.5,'Terhardt','Bark','Mask','dB')"
    #fp = dropdims(mat"mirgetdata(mirspectrum(s,'MinRes',.01,'AlongBands','Max',10,'Window',0,'Resonance','Fluctuation'))",dims=2)
    # fp = dropdims(mat"mirgetdata(mirfluctuation(a))",dims=2)
    fp = mat"mirgetdata(mirfluctuation(a,'summary','frame'))"
    c = complexity(fp')
end
function getmelstft(m, sr;
    n_mels=128,
    fmin=20.0,
    fmax=sr/2,
    win_ms=20,
    overlap=0.5)

    # STFT parameters
    n = round(Int, (win_ms / 1000) * sr)
    noverlap = round(Int, overlap * n)
    nfft = nextfastfft(4n)

    # STFT
    s = spectrogram(
        m,
        n,
        noverlap;
        fs=sr,
        nfft=nfft
    )

    power = s.power
    freq = s.freq
    t = s.time

    # Hz <-> Mel
    hz_to_mel(hz) = 2595.0 * log10(1.0 + hz / 700.0)
    mel_to_hz(mel) = 700.0 * (10.0^(mel / 2595.0) - 1.0)

    # Mel filterbank frequencies
    mel_min = hz_to_mel(fmin)
    mel_max = hz_to_mel(fmax)

    mel_points = mel_to_hz.(
        range(mel_min, mel_max, length=n_mels+2)
    )

    # Filterbank
    fb = zeros(n_mels, length(freq))

    for m in 1:n_mels
        f1, f2, f3 = mel_points[m:m+2]

        for (i, f) in enumerate(freq)
            if f1 <= f <= f2
                fb[m,i] = (f - f1) / (f2 - f1)
            elseif f2 < f <= f3
                fb[m,i] = (f3 - f) / (f3 - f2)
            end
        end
    end

    # Apply mel filters
    mel = fb * power

    # dB conversion
    mel_db = 10 .* log10.(mel .+ eps())

    # Normalize
    mel_db .-= maximum(mel_db)

    fs = 1 / step(t)

    return mel_db', fs
end
function complexity(x)
    ndim = size(x,2)
    x .-= mean(x,dims=1)
    λ = eigvals(x'*x)
    p = λ/sum(λ)
    p = max.(p,eps())
    H = -sum(p.*log.(p))
    c = exp(H) / ndim # relative to number of channels (which depends on duration)
end
end
