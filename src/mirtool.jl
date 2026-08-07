module Mirtool
using MATLAB,CSV,DataFrames,DrWatson,Heatmaps,StatsBase,Statistics,HypothesisTests,GLMakie
include(srcdir("src.jl"))

function extract_MIR_features(foldername;trim=false)
    fullfilenames = Complexity.recursive_list_all_files_in_tree(foldername)
    filenames = filesfromfullfilenames(fullfilenames)

    mat"addpath(genpath('~/Documents/MATLAB/mirtoolbox'))"
    mat"mirverbose(0)"
    mat"addpath(genpath('/Users/maarhart/Downloads/miremotionPT'))"
    N = length(filenames)
    vals = []
    names = []
    t = []
    e = []
    i = 1
    for k = 1:N
        display(filenames[k])
        f = fullfilenames[k]
        try
            t,e = matlab_extract(f,trim)
        catch # file must contain pure silence, so add some noise
            mat"[au fs] = audioread($f)"
            mat"au = au + randn(size(au))/100000"
            mat"audiowrite($f,au,fs)"
            t,e = matlab_extract(f,trim)
        end
        push!(vals,[t' e])
        push!(names,fullfilenames[k])
        i += 1
    end
    featnames = [featlbl(); emolbl()]
    df_write = [DataFrame(vcat(vals...), featnames) DataFrame(fname = vcat(names...))]

    fname = filesfromfullfilenames(foldername) * "_" * "mirfeat" * "_trim_" * string(trim) * ".csv"
    df_file = datadir("exp_pro", fname)
    CSV.write(df_file, df_write)
end
filesfromfullfilenames(x) = last.(split.(x,"/"))
featlbl() = ["Pulse Clarity","Tempo", "Event Density", "RMS Energy", "Spectral Centroid", "Spectral Entropy", "Spectral Spread", "Spectral Roughness"]
emolbl()=["Valence","Energy Arousal","Tension Arousal","Anger","Fear","Happiness","Sadness","Tenderness"];
function compare_with_mirtool(foldername;trim=false,method="spectrum")
    fname = filesfromfullfilenames(foldername) * "_" * "mirfeat" * "_trim_" * string(trim) * ".csv"
    fname2 = filesfromfullfilenames(foldername) * "_trim_" * string(trim) * "_method_" * method * ".jld2"
    mirtool_file = datadir("exp_pro", fname)
    mirdf = CSV.read(mirtool_file,DataFrame)
    rhy_file = datadir("exp_pro", fname2)
    rhy = load(rhy_file)["data"]
    rval = rhy.val
    if rhy.fname != mirdf.fname
        error("filename mismatch")
    end
    if eltype(mirdf.Valence) !== Float64
        badcases = occursin.(" + ",mirdf.Valence) # remove examples that yielded complex values (and that's why we see strings)
        rval = rval[.!badcases]
        mirdf = mirdf[.!badcases,:]
        emlb=emolbl()
        for k = 1:length(emlb)
            mirdf[!,emlb[k]] = parse.(Float64,mirdf[:,emlb[k]])
        end
    end
    df = [DataFrame("Rhythmic Complexity"=>rval) mirdf]
    dfval = df[:,1:end-1]
    m = Matrix(dfval)
    m = m[vec(.!any(isnan.(m),dims=2)),:] # remove any examples with NaNs
    dfc = DataFrame(cor(m),names(dfval))
    #display(DataFrame(cor_pvalues(m),names(dfval)))
    #display(scatter(m[:,1],m[:,3]))
    f = Heatmaps.heatmap(dfc,cor_pvalues(m))
    fn = "mirfeat_corrs_" * filesfromfullfilenames(foldername) * "_trim_" * string(trim) * "_method_" * method * ".png"
    save(plotsdir(fn),f)
    fn = "rhycomp_and_mirfeats_" * filesfromfullfilenames(foldername) * "_trim_" * string(trim) * "_method_" * method * ".csv"
    CSV.write(datadir("exp_pro", fn), df)
end
function scatter_mirfeature(featname,foldername;trim=false,method="spectrum")
    f,ax,_ = makescatter_mirfeature(featname,foldername;trim=trim,method=method)
    fullfnames = Complexity.recursive_list_all_files_in_tree(foldername)
    Complexity.click_and_play(f,ax,fullfnames;trim=trim)
    display(f)
end
function makescatter_mirfeature(featname,foldername;trim=false,method="spectrum")
    fn = "rhycomp_and_mirfeats_" * filesfromfullfilenames(foldername) * "_trim_" * string(trim) * "_method_" * method * ".csv"
    df = CSV.read(datadir("exp_pro", fn),DataFrame)
    GLMakie.activate!()
    f = Figure(;fontsize=20,size=(1200,1200))
    ax = Axis(f[1, 1], xlabel = featname, ylabel = "Rhythmic Complexity")
    scatter!(ax,df[!, featname], df[!,"Rhythmic Complexity"])
    return f,ax,df
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
function matlab_extract(f,trim)
    if trim
        mat"a = miraudio($f,'Extract',0,5)"
    else
        mat"a = miraudio($f)"
    end
    t = []
    e = []
    push!(t,mat"mirgetdata(mirpulseclarity(a))")
    push!(t, mat"mirgetdata(mirtempo(a))")
    push!(t, mat"mirgetdata(mireventdensity(a))")
    push!(t, mat"mirgetdata(mirrms(a))")
    push!(t, mat"mirgetdata(mircentroid(a))")
    push!(t, mat"mirgetdata(mirentropy(a))")
    push!(t, mat"mirgetdata(mirspread(a))")
    push!(t, mat"mirgetdata(mirmean(mirroughness(a)))")
    e = mat"miremotionPT(a)"
    return t, e
end
end
