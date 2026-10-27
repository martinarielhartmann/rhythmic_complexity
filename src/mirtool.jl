module Mirtool
using MATLAB,CSV,DataFrames,DrWatson,Heatmaps,Statistics,GLMakie
include(srcdir("Utils.jl"))
using .Utils:recursive_list_all_files_in_tree,cor_pvalues

function getaudiofilenames(foldername,trim)
    name = basename(foldername) * "_" * "mirfeat" * "_trim_" * string(trim)
    path = datadir("exp_pro", name)
    fullfilenames = recursive_list_all_files_in_tree(foldername)
    filenames = basename.(fullfilenames)
    return fullfilenames, filenames,path
end
function extract_MIR_features(foldername;trim=false)
    fullfilenames, filenames, path = getaudiofilenames(foldername,trim)
    mat"addpath(genpath('~/Documents/MATLAB/mirtoolbox'))"
    mat"mirverbose(0)"
    mat"addpath(genpath('/Users/maarhart/Downloads/miremotionPT'))"
    c = Dict("dataset" => last(split(foldername,"/")),"fname" => fullfilenames, "trim" => trim);
    config = dict_list(c)
    for k in eachindex(config)
        produce_or_load(extractmatlab,config[k],path,filename=filenames[k])
    end
end
function extractmatlab(config)
    t = []
    e = []
    f = config["fname"]
    trim = config["trim"]
    dataset = config["dataset"]
    #f = projectdir("data","exp_raw",dataset,fname)
    try
        t,e = matlab_extract(f,trim)
    catch # file must contain pure silence, so add some noise
        mat"[au fs] = audioread($f)"
        mat"au = au + randn(size(au))/100000"
        mat"audiowrite($f,au,fs)"
        t,e = matlab_extract(f,trim)
    end
    ks = [featlbl(); emolbl();"fname"]
    vs = [t' e f]
    res = Dict(zip(ks,vs))
end
function extract_MIR_features_old(foldername;trim=false,overwrite=false)
    fname = basename(foldername) * "_" * "mirfeat" * "_trim_" * string(trim) * ".csv"
    df_file = datadir("exp_pro", fname)
    if isfile(df_file)
        isfileflag = true
    else
        isfileflag = false
    end
    if isfileflag && overwrite==false
        appendflag = true
    else
        appendflag = false
    end
    if appendflag
        df = CSV.read(df_file, DataFrame)
    else
        cols = [featlbl(); emolbl();"fname"]
        df = DataFrame(
            [name => (name == "fname" ? String[] : Float64[])
            for name in cols])
        CSV.write(df_file,df)
    end

    fullfilenames = recursive_list_all_files_in_tree(foldername)
    filenames = basename.(fullfilenames)

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
        if !in(fullfilenames[k],df.fname)
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
            featnames = [featlbl(); emolbl()]
            df_write = [DataFrame(vcat(vals...), featnames) DataFrame(fname = vcat(names...))]
            CSV.write(df_file, df_write,append=true)
            i += 1
        end
    end
end
featlbl() = ["Pulse Clarity","Tempo", "Event Density", "RMS Energy", "Spectral Centroid", "Spectral Entropy", "Spectral Spread", "Spectral Roughness"]
emolbl()=["Valence","Energy Arousal","Tension Arousal","Anger","Fear","Happiness","Sadness","Tenderness"];

function compare_with_mirtool(foldername;trim=false,method="spectrum")
    GLMakie.activate!()
    fname = basename(foldername) * "_" * "mirfeat" * "_trim_" * string(trim) * ".csv"
    fname2 = basename(foldername) * "_trim_" * string(trim) * "_method_" * method * ".jld2"
    mirtool_file = datadir("exp_pro", fname)
    if isfile(mirtool_file)
        mirdf = CSV.read(mirtool_file,DataFrame)
    else
        fname3 = datadir("exp_pro",basename(foldername) * "_mirfeat" * "_trim_" * string(trim))
        mirdf = collect_results(fname3)
    end
    rhy_file = datadir("exp_pro", fname2)
    rhy = load(rhy_file)["data"]
    rval = rhy.val
    #@infiltrate
    in.(basename.(mirdf.fname),Ref(basename.(rhy.fname)))
    if basename.(rhy.fname) != basename.(mirdf.fname)
        error("filename mismatch")
    end
    if (eltype(mirdf.Valence) !== Union{Missing,Float64}) && (eltype(mirdf.Valence) !== Float64)
        badcases = occursin.(" + ",mirdf.Valence) # remove examples that yielded complex values (and that's why we see strings)
        rval = rval[.!badcases]
        mirdf = mirdf[.!badcases,:]
        emlb=emolbl()
        for k = 1:length(emlb)
            mirdf[!,emlb[k]] = parse.(Float64,mirdf[:,emlb[k]])
        end
    end
    rhycomp = "Rhythmic Complexity"
    df = [DataFrame(rhycomp=>rval) mirdf]
    dfval = df[:,[featlbl();rhycomp]]
    m = Matrix(dfval)
    m = m[vec(.!any(isnan.(m),dims=2)),:] # remove any examples with NaNs
    dfc = DataFrame(cor(m),names(dfval))
    #display(DataFrame(cor_pvalues(m),names(dfval)))
    #display(scatter(m[:,1],m[:,3]))
    f = Heatmaps.heatmap(dfc,cor_pvalues(m))
    fn = "mirfeat_corrs_" * basename(foldername) * "_trim_" * string(trim) * "_method_" * method * ".png"
    save(plotsdir(fn),f)
    fn = "rhycomp_and_mirfeats_" * basename(foldername) * "_trim_" * string(trim) * "_method_" * method * ".csv"
    CSV.write(datadir("exp_pro", fn), df)
end

function scatter_multidataset(featname,foldernames;trim=false,method="spectrum")
    df = getjointdf(foldernames;trim=trim,method=method)
    f, ax = scatter_mirfeature(df,featname)
    Utils.click_and_play(f,ax,df.fname;trim=trim)
    display(f)
end
function getjointdf(foldernames;trim=false,method="spectrum")
    compare_with_mirtool.(foldernames;trim=trim,method=method)
    fn = map(x -> "rhycomp_and_mirfeats_" * basename(x) * "_trim_" * string(trim) * "_method_" * method * ".csv", foldernames)
    replace!(foldernames,"friends" => "Friends and Strangers","endurance_cycling" => "Endurance Cycling", "spotify_previews" => "Personally Meaningful Music")
    m = map(x -> CSV.read(datadir("exp_pro", x),DataFrame),fn)
    groups = map((x,y) -> fill(x,size(y,1)),foldernames,m)
    for k = 1:length(groups)
        m[k].var"Group" = groups[k]
    end
    df = vcat(m...)
end

function scatter_mirfeature(featname,foldername;trim=false,method="spectrum")
    compare_with_mirtool(foldername;trim=trim,method=method)
    f,ax,df = makescatter_mirfeature(featname,foldername;trim=trim,method=method)
    Utils.click_and_play(f,ax,df.fname;trim=trim)
    display(f)
end
function makescatter_mirfeature(featname,foldername::Vector{String};trim=false,method="spectrum")
    df = getjointdf(foldername;trim=trim,method=method)
    f, ax = scatter_mirfeature(df,featname)
    return f,ax,df
end
function makescatter_mirfeature(featname,foldername::String;trim=false,method="spectrum")
    fn = "rhycomp_and_mirfeats_" * basename(foldername) * "_trim_" * string(trim) * "_method_" * method * ".csv"
    df = CSV.read(datadir("exp_pro", fn),DataFrame)
    fname = basename(foldername)
    fname = replace(fname,"friends" => "Friends and Strangers","endurance_cycling" => "Endurance Cycling", "spotify_previews" => "Personally Meaningful Music")
    df.Group = fill(fname,size(df,1))
    f, ax = scatter_mirfeature(df,featname)
    return f,ax,df
end
function scatter_mirfeature_existing_figure(f, ax, df, featname,foldername;trim=false,method="spectrum")
    df = getjointdf(foldername;trim=trim,method=method)
    x, y, g = eachcol(df[!, [featname, "Rhythmic Complexity", "Group"]])
    groups = unique(g)
    gn = indexin(g, groups)

    cortext = Utils.format_cor(cor(x, y),Utils.cor_pvalues([x y])[3],length(x))
    colors = Makie.wong_colors()[1:length(groups)]
    scatter!(ax, x, y, markersize=10, color=[colors[i] for i in gn])
    return ax
end
function scatter_mirfeature(df, featname)
    x, y, g = eachcol(df[!, [featname, "Rhythmic Complexity", "Group"]])
    groups = unique(g)
    gn = indexin(g, groups)

    cortext = Utils.format_cor(cor(x, y),Utils.cor_pvalues([x y])[3],length(x))

    f = Figure(; fontsize=20, size=(1200, 1200))
    ax = Axis(f[1, 1],xlabel=featname, ylabel="Rhythmic Complexity", title=cortext)

    colors = Makie.wong_colors()[1:length(groups)]

    scatter!(ax, x, y, markersize=10, color=[colors[i] for i in gn])

    legend_elements = [MarkerElement(marker=:circle,color=colors[i],markersize=10) for i in eachindex(groups) ]

    legend = Legend(f[1, 1],legend_elements, string.(groups), "Group", tellwidth=false, tellheight=false, halign=:right, valign=:top)
    return f, ax
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
