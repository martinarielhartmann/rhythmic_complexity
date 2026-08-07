module Spotifeatures
using FileIO, DrWatson,XLSX,DataFrames,Heatmaps,Statistics,HypothesisTests,GLMakie
include(srcdir("src.jl"))
include(srcdir("mirtool.jl"))
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
    fn = Mirtool.filesfromfullfilenames(foldername) * "artist_genre" * "_trim_" * string(trim) * "_method_" * method * ".png"
    save(plotsdir(fn),f)
end
function artist_genres_scatter(featname,foldername;trim=false,method="spectrum")
rhycomplbl = "Rhythm Complexity"
f,ax,df = Mirtool.makescatter_mirfeature(featname,foldername;trim=false,method=method)
dfs = DataFrame(XLSX.readtable(datadir("exp_raw","Spotify_features.xlsx"),"Sheet1",infer_eltypes=true))
    dfs = dfs[:,[:trackID,:artist_genres]]
    dfs = dfs[dfs.artist_genres .!= "[]",:]
    dfr,_ = get_rhycomp(foldername,trim,method)
    j = innerjoin(dfs,dfr,on=:trackID)
    df.fname = removextension.(Mirtool.filesfromfullfilenames(df.fname))
    rename!(j,:trackID => :fname)
    df = innerjoin(j,df[:,[featname,"fname"]],on=:fname)


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
    magnify = 10
    counts = c.artist_genres_length
    sortedcounts = sort(counts)
    c = c[sortperm(counts),:]
    x = c[:,featname * "_mean"]
    y = c[:,rhycomplbl * "_mean"]
    resize!(f.scene, 2000, 2000)
    scatter!(ax,x,y,markersize=(magnify * (sortedcounts)),color=1:N,colormap=(:coolwarm,.2))
    textlabel!(ax,x,y,c.artist_genres)
    @show c
    display(f)

end
function get_rhycomp(foldername,trim,method)
    fn = datadir("exp_pro", split(foldername, "/")[end] * "_trim_" * string(trim) * "_method_" * method * ".jld2")
    d = load(fn)
    g = d["data"].val
    names = Mirtool.filesfromfullfilenames(d["data"].fname)
    names = [x[1:end-4] for x in names]
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
removextension(x) = x[1:end-4]
end
