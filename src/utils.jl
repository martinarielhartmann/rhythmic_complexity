module Utils
using Printf,FileIO,LibSndFile,MP3,PortAudio,HypothesisTests,Makie,StatsBase
function recursive_list_all_files_in_tree(foldername)
    files = [ joinpath(dir, file)
            for (dir, _, filenames) in walkdir(foldername)
            for file in filenames ]
end
removextension(x) = split(x, r"\.[^.]+$")[1]
function click_and_play(fig, ax, files; trim=false)
    """
    left click on the bar: play audio
    right click on the bar: stop audio
    for scatter plots, files should be indexed based on the sorting, in decreasing order, of the values in the y axis
    """
    stream = nothing

    if any(p isa Makie.Scatter for p in ax.scene.plots)
        type = "Scatter"
    elseif any(p isa Makie.BarPlot for p in ax.scene.plots)
        type = "BarPlot"
    else
        error("No Scatter or BarPlot found in ax")
    end

    on(events(fig.scene).mousebutton) do event
        # Right click: stop playback
        if event.button == Mouse.right && event.action == Mouse.press
            println("stop playback")
            stream !== nothing && close(stream)
            stream = nothing
            return
        end

        # Only handle left-button presses
        event.action == Mouse.press || return
        event.button == Mouse.left || return

        pos = mouseposition(fig.scene)
        hit = Makie.pick(fig.scene, pos)

        # Nothing was picked
        hit === nothing && return

        plot, idx = hit

        # Ignore clicks on the background or any other plot.
        if type == "Scatter"
            plot isa Makie.Scatter || return
            baridx = idx
        elseif type == "BarPlot"
            plot isa Makie.BarPlot || return
            baridx = div(idx - 1, 4) + 1
        end

        # Only play if the index corresponds to a file
        if baridx in eachindex(files)
            println("playing ", files[baridx])
            stream = Utils.play_audio(files[baridx]; trim=trim)
        end

        return
    end
end
function play_audio(fname; trim=false)
    f = FileIO.load(fname)
    data = f.data
    fs = f.samplerate

    if trim
        data = trimfirst5sec(data, fs)
    else
        data = trimfirstsec(data, fs, 30)
    end

    stream = PortAudioStream(0, 2; samplerate=fs)

    @async begin
        try
            write(stream, data)
        finally
            close(stream)
        end
    end

    return stream
end
function play_audio_(fname;trim=false)
    f = FileIO.load(fname)
    data = f.data
    fs = f.samplerate
    if trim
        data = trimfirst5sec(data,fs)
    else
        data = trimfirstsec(data,fs,30)
    end
    stream = PortAudioStream(0, 2; samplerate=fs)

    @async begin
        write(stream, data)
    end

    return stream
end
function format_cor(r,pval,N)
    c = replace(string(round(r,digits=2)),"0."=>".")
    df = "($(string(N-2)))"
    p = "p = " * @sprintf("%.3f", pval)[2:end]
    cortext = "r" * df * " = " * c * ", " * p
end
function cor_pvalues(X)
    n = size(X, 1)
    p = size(X, 2)
    P = ones(p, p)
    for i in 1:p
        for j in i+1:p
            test = CorrelationTest(X[:, i], X[:, j])
            P[i, j] = pvalue(test)
            P[j, i] = P[i, j]
        end
    end
    return P
end
trimfirstsec(x, sr,sec) = x[1:min(length(x), sec*Int(sr))]
trimfirst5sec(x, sr) = x[1:min(length(x), 5Int(sr))]
meanchannels(x) = collect(vec(mean(Float64.(x),dims=2)))
end
