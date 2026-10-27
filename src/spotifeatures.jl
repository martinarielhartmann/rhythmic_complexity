module Spotifeatures
using FileIO, DrWatson,XLSX,DataFrames,Heatmaps,Statistics,HypothesisTests,GLMakie,CSV,Printf,StatsBase
include(srcdir("mirtool.jl"))
include(srcdir("Utils.jl"))
include(srcdir("applefeatures.jl"))
function artist_genres_boxplots(foldername;trim=false,method="spectrum")
    dfs = DataFrame(XLSX.readtable(datadir("exp_raw","Spotify_features.xlsx"),"Sheet1",infer_eltypes=true))
    dfs = dfs[:,[:trackID,:artist_genres]]
    dfs = dfs[dfs.artist_genres .!= "[]",:]
    dfr,_ = get_rhycomp(foldername,trim,method)
    j = innerjoin(dfs,dfr,on=:trackID)
    dfc = combine(groupby(j, :artist_genres), nrow => :count)
    selected_genres = dfc.artist_genres[dfc.count .>= 8]
    selected_examples = vec(any(hcat([j.artist_genres .== x for x in selected_genres]...),dims=2))
    s = j[selected_examples,:]
    so = sort(combine(groupby(s,:artist_genres),:rhycomplexity => mean),:rhycomplexity_mean;rev=true)
    topgenres = so.artist_genres
    l = Vector{Int}(undef,size(s,1))
    for (ind,val) in enumerate(topgenres)
        l[s.artist_genres .== val] .= ind
    end
    GLMakie.activate!()
    f = Figure(fontsize=28,size=(1200,600))
    ax = Axis(f[1, 1], yticks=(1:length(topgenres),topgenres))
    boxplot!(ax,l,s.rhycomplexity;orientation = :horizontal)
    display(f)
    fn = basename(foldername) * "artist_genre" * "_trim_" * string(trim) * "_method_" * method * ".png"
    save(plotsdir(fn),f)
end
function artist_genres_scatter(featname,foldername::String;trim=false,method="spectrum")
    friendsflag = last(splitpath(foldername)) == "friends"
    GLMakie.activate!()
    rhycomplbl = "Rhythm Complexity"
    f,ax,df = Mirtool.makescatter_mirfeature(featname,foldername;trim=trim,method=method)
    if friendsflag
        dfs = Applefeatures.get_df_apple(foldername)
    else
        dfs = get_df_spotify(foldername)
    end
    dfr,_ = get_rhycomp(foldername,trim,method)
    if friendsflag
        dfr.trackID = map(x->x[4:end],dfr.trackID)
    end
    j = innerjoin(dfs,dfr,on=:trackID)
    df.fname = Utils.removextension.(basename.(df.fname))
    if friendsflag
     df.fname = map(x->x[4:end],df.fname)
    end
    rename!(j,:trackID => :fname)
    df = innerjoin(j,df[:,[featname,"fname"]],on=:fname)
    if friendsflag == false
        df.artist_genres = map(df.artist_genres) do x
            x = strip(x,['[',']'])
            x = replace.(x,"'"=>"")
            x = split.(x,", ")
        end
    end
    rename!(df,"rhycomplexity" => rhycomplbl)
    if friendsflag == false
        df = flatten(df,:artist_genres)
    end
    df = unique(df)
    g = groupby(df,:artist_genres)
    c = combine(g, rhycomplbl => mean, rhycomplbl => std, featname => mean, featname => std, :artist_genres => length)
    if friendsflag == false
        c.artist_genres = String.(c.artist_genres)
    end
    c = c[vec(any(Matrix(.!isnan.(c[:,contains.(names(c),"_std")])),dims=2)),:]
    N= size(c,1)
    magnify = 10
    counts = c.artist_genres_length
    sortedcounts = sort(counts)
    c = c[sortperm(counts),:]
    x = c[:,featname * "_mean"]
    y = c[:,rhycomplbl * "_mean"]
    resize!(f.scene, 2000, 2000)
    scatter!(ax,x,y,markersize=(magnify * (sortedcounts)),color=1:N,colormap=(:coolwarm,.2))
    textlabel!(ax,x,y,string.(c.artist_genres))
    @show c
end
function get_df_spotify(foldername)
    dfs = CSV.read(datadir("exp_raw",foldername * "_spotify_features.csv"),DataFrame)
    dfs = dfs[:,[:trackID,:artist_genres]]
    dfs = dfs[dfs.artist_genres .!= "[]",:]
    if contains(dfs.trackID[1],".flac")
        dfs.trackID = Utils.removextension.(dfs.trackID)
    end
    return dfs
end
function sample_across_folders(featname,foldername::Vector{String};trim=false,method="spectrum")
    friendsflag = any(last.(splitpath.(foldername)) .== "friends")
    if friendsflag
        friendsind = findfirst(last.(splitpath.(foldername)) .== "friends")
    end
    GLMakie.activate!()
    rhycomplbl = "Rhythmic Complexity"
    f,ax,df = Mirtool.makescatter_mirfeature(featname,basename.(foldername);trim=trim,method=method)
    folnames = basename.(foldername)
    #dfs = DataFrame(XLSX.readtable(datadir("exp_raw","spotify_previews_spotify_features.xlsx"),"Sheet1",infer_eltypes=true))
    dfs = Vector{DataFrame}(undef,length(folnames))
for k in eachindex(folnames)
        if folnames[k] == "friends"
            dfs[k] = Applefeatures.get_df_apple(folnames[k])
            dfs[k].artist_genres = lowercase.(coalesce.(dfs[k].artist_genres, ""))
            dfs[k].artist_genres = ["['$(x)']" for x in dfs[k].artist_genres]
        else
            dfs[k] = get_df_spotify(folnames[k])
        end
    end
    dfr = Vector{DataFrames.DataFrame}(undef,length(foldername))
    for k = 1:length(foldername)
        dfr[k],_ = get_rhycomp(foldername[k],trim,method)
    end
    if friendsflag
        dfr[friendsind].trackID = map(x->x[4:end],dfr[friendsind].trackID)
    end
    j = innerjoin(vcat(dfs...),vcat(dfr...),on=:trackID)
    df.fname = Utils.removextension.(basename.(df.fname))
    if friendsflag
        for k in eachindex(df.fname)
            sv = df.fname[k][nextind(df.fname[k], 0, 4):end]
            if in(sv, dfr[friendsind].trackID)
                df.fname[k] = sv
            end
        end
    end
    rename!(j,:trackID => :fname)
    df = innerjoin(j,df[:,[featname,"fname"]],on=:fname)
    function bin_by_percentiles(x,qs)
        q = quantile(x, qs)
        [1 + count(c -> xi > c, q) for xi in x]
    end
    qs = [0.05, 0.25, 0.75, 0.95]
    df.binc = bin_by_percentiles(df.rhycomplexity,qs)
    df.binpc = bin_by_percentiles(df[:,"Pulse Clarity"],qs)
    name = String[]
    complexity_pctl, pclarity_pctl = Float64[],Float64[]
    qsall = [0.05, 0.25, 0.75, 0.95,1]
    for k = 1:5, j =1:5
        n = findfirst(df.binc .== k .&& df.binpc .== j)
        if !isnothing(n)
            push!(name,df.fname[n])
            push!(complexity_pctl,qsall[k])
            push!(pclarity_pctl,qsall[j])
        else
            #push!(name,sample(df.fname,1)[1])
        end
    end
    @show DataFrame(;name,complexity_pctl,pclarity_pctl)
end
function artist_genres_scatter(featname,foldername::Vector{String};trim=false,method="spectrum")
    friendsflag = any(last.(splitpath.(foldername)) .== "friends")
    if friendsflag
        friendsind = findfirst(last.(splitpath.(foldername)) .== "friends")
    end
    GLMakie.activate!()
    rhycomplbl = "Rhythmic Complexity"
    f,ax,df = Mirtool.makescatter_mirfeature(featname,basename.(foldername);trim=trim,method=method)
    folnames = basename.(foldername)
    #dfs = DataFrame(XLSX.readtable(datadir("exp_raw","spotify_previews_spotify_features.xlsx"),"Sheet1",infer_eltypes=true))
    dfs = Vector{DataFrame}(undef,length(folnames))
    for k in eachindex(folnames)
        if folnames[k] == "friends"
            dfs[k] = Applefeatures.get_df_apple(folnames[k])
            dfs[k].artist_genres = lowercase.(coalesce.(dfs[k].artist_genres, ""))
            dfs[k].artist_genres = ["['$(x)']" for x in dfs[k].artist_genres]
        else
            dfs[k] = get_df_spotify(folnames[k])
        end
    end
    dfr = Vector{DataFrames.DataFrame}(undef,length(foldername))
    for k = 1:length(foldername)
        dfr[k],_ = get_rhycomp(foldername[k],trim,method)
    end
    if friendsflag
        dfr[friendsind].trackID = map(x->x[4:end],dfr[friendsind].trackID)
    end
    j = innerjoin(vcat(dfs...),vcat(dfr...),on=:trackID)
    df.fname = Utils.removextension.(basename.(df.fname))
    if friendsflag
        for k in eachindex(df.fname)
            sv = df.fname[k][nextind(df.fname[k], 0, 4):end]
            if in(sv, dfr[friendsind].trackID)
                df.fname[k] = sv
            end
        end
    end
    rename!(j,:trackID => :fname)

    df = innerjoin(j,df[:,[featname,"fname"]],on=:fname)
    fmeans = vec(mean(Matrix(df[:,[featname,"rhycomplexity"]]),dims=1))
    f3stdup = fmeans .+ 3 .* vec(std(Matrix(df[:,[featname,"rhycomplexity"]]),dims=1)) # 3 stds above mean
    f3stddown = fmeans .- 3 .* vec(std(Matrix(df[:,[featname,"rhycomplexity"]]),dims=1))# 3 stds below mean
    df.artist_genres = map(df.artist_genres) do x
        x = strip(x,['[',']'])
        x = replace.(x,"'"=>"")
        x = split.(x,", ")
    end
    rename!(df,"rhycomplexity" => rhycomplbl)
    dff = flatten(df,:artist_genres)
    g = groupby(dff,:artist_genres)
    c = combine(g, rhycomplbl => mean, rhycomplbl => std, featname => mean, featname => std, :artist_genres => length)
    c.artist_genres = String.(c.artist_genres)
    c = c[vec(any(Matrix(.!isnan.(c[:,contains.(names(c),"_std")])),dims=2)),:]
    N= size(c,1)
    magnify = .001
    counts = c.artist_genres_length
    sortedcounts = sort(counts)
    c = c[sortperm(counts),:]
    x = c[:,featname * "_mean"]
    y = c[:,rhycomplbl * "_mean"]
    resize!(f.scene, .8*2000, .8*1000)
    textlabel!(ax,x,y,c.artist_genres)
    vlines!(ax,fmeans[1];linestyle=:dash)
    vlines!(ax,[f3stdup[1], f3stddown[1]];linestyle=:dash, color=:red)
    #textlabel!(ax,fmeans[1],0,["x̄ = " * @sprintf("%.2f",fmeans[1])])
    hlines!(ax,fmeans[2];linestyle=:dash)
    hlines!(ax,[f3stdup[2], f3stddown[2]];linestyle=:dash, color=:red)
    #textlabel!(ax,0,fmeans[2],["x̄ = " * @sprintf("%.2f", fmeans[2])])
    scatter!(ax,x,y,markersize=(magnify * (sortedcounts)),color=1:N,colormap=(:coolwarm,.2),markerspace=:data)
    Mirtool.scatter_mirfeature_existing_figure(f, ax, df, featname,foldername;trim=trim,method=method)
    df = Mirtool.getjointdf(foldername;trim=trim,method=method)
    fnames = datadir() .* "/" .* map(x->join(split(x,"/")[end-2:end],"/"),df.fname)

    Utils.click_and_play(f,ax,fnames;trim=trim)
    xlims!(ax, 0, 1)
    ylims!(ax, 0, .5)
    #@show c
    display(f)
end
function get_rhycomp(foldername,trim,method)
    # works for spotify_previews; with endurance_cycling one needs to tweak because the filenames are not the spotify trackID
    fn = datadir("exp_pro", split(foldername, "/")[end] * "_trim_" * string(trim) * "_method_" * method * ".jld2")
    d = load(fn)
    g = d["data"].val
    names = basename.(d["data"].fname)
    names = Utils.removextension.(names)
    dfr = DataFrame(trackID = names, rhycomplexity = d["data"].val)
    return dfr,names
end
function compare_with_spotify(foldername;trim=false)
    dfs = DataFrame(XLSX.readtable(datadir("exp_raw","Spotify_features.xlsx"),"Sheet1",infer_eltypes=true))
    dfr,names = get_rhycomp(foldername,trim,method)
    j = innerjoin(dfs,dfr,on=:trackID)
    feats = ["rhycomplexity", "acousticness", "album_popularity", "artist_popularity", "danceability", "energy", "instrumentalness", "liveness", "loudness", "mode", "speechiness", "tempo", "trackPopularity", "valence", "trackID"]
    df = j[:,feats]
    m = Matrix(df[:,1:end-1])
    dfc = DataFrame(cor(m),feats[1:end-1])
    f = Heatmaps.heatmap(dfc,Mirtool.cor_pvalues(m))
    fn = foldername * "__corr_spotfeats" * "_trim_" * string(trim) * "_method_" * method * ".png"
    save(plotsdir(fn),f)

    # very low correlations with all these features
    # dfp = DataFrame(XLSX.readtable(datadir("exp_raw","ccsDataCorrected.xlsx"),"Sheet1",infer_eltypes=true))
    # feats = [:Music_Background, :Music_Memories, :Music_HaveFun, :Music_MusicsEmotion, :Music_ChangeMood, :Music_ExpressYourself, :Music_Connected, :Relaxation, :Spirituality, :Consolation, :Security, :Strength, :Enthusiasm, :Pride, :Freedom, :Happiness, :Pleasure, :Love, :Sadness, :Longing, :Vulnerability, :BeingMoved, :Nostalgia, :Tenderness, :Empathy, :Curiousity, :Amusement, :Anger, :Tension, :Belonging, :Loneliness, :Pain, :Beauty, :Eroticism, :Energy, :Aggresion, :Fear, :Dreaminess, :Triumph, :Rebelliousness, :LyricsImportance, :Track_Background, :Track_Memories, :Track_HaveFun, :Track_MusicsEmotion, :Track_ChangeMood, :Track_ExpressYourself, :Track_Connected, :Age, :Education, :Musicianship, :Employment, :EconomicSituation, :MusicWellBeing, :Extraverted_Enthusiastic, :Critical_Quarrelsome, :Dependable_Self_disciplined, :Anxious_EasilyUpset, :OpenToNewExperiences_Complex, :Reserved_Quiet, :Sympathetic_Warm, :Disorganized_Careless, :Calm_EmotionallyStable, :Conventional_Uncreative, :Extraversion, :Agreeableness, :Conscientiousness, :Emotional_Stability, :Openness_Experiences, :Horizontal_individualism, :Vertical_individualism, :Horizontal_collectivism, :Vertical_collectivism,:spotify_index]
    # dfp = dfp[:,feats]
    # dfp = dfp[.!ismissing.(dfp.spotify_index),:]
    # rename!(dfs,:index => :spotify_index)
    # dfp = innerjoin(dfp,dfs[:,["spotify_index","trackID"]],on=:spotify_index)
    # j = innerjoin(dfr,dfp,on=:trackID)
    # df = j[:,2:end-1]
    # df = df[completecases(df), :]
    # m = Matrix(df)
    # dfc = DataFrame(cor(m),propertynames(j)[2:end-1])
    # f = Heatmaps.heatmap(dfc,Mirtool.cor_pvalues(m))
    # fn = "ccsdata__corr_spotfeats" * "_trim_true" * ".png"
    # save(plotsdir(fn),f)


end
end
